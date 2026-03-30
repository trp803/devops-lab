# Kubernetes — оркестрация контейнеров

## Что такое Kubernetes и зачем он нужен

Docker запускает контейнеры на одном сервере. Что если сервер упал? Что если нагрузка выросла и нужно больше копий? Кто перезапустит упавший контейнер?

**Kubernetes (K8s)** — система оркестрации контейнеров. Она управляет множеством контейнеров на множестве серверов и обеспечивает:

- **Self-healing** — если контейнер упал, Kubernetes перезапустит его автоматически
- **Scaling** — легко масштабировать: `kubectl scale deployment webapp --replicas=10`
- **Rolling updates** — обновление без downtime: новые поды поднимаются до остановки старых
- **Load balancing** — распределяет трафик между репликами
- **Service discovery** — сервисы находят друг друга по имени

---

## Архитектура Kubernetes

```
┌─────────────────────────────────────────────────────┐
│                    Кластер K8s                      │
│                                                     │
│  ┌─────────────────┐    ┌──────────────────────┐   │
│  │  Control Plane  │    │     Worker Nodes      │   │
│  │                 │    │                       │   │
│  │  API Server     │    │  ┌────┐ ┌────┐ ┌────┐│   │
│  │  Scheduler      │    │  │Pod │ │Pod │ │Pod ││   │
│  │  Controller Mgr │    │  └────┘ └────┘ └────┘│   │
│  │  etcd           │    │  Node 1    Node 2     │   │
│  └─────────────────┘    └──────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

**Control Plane** — мозг кластера:
- **API Server** — точка входа, все команды идут через него
- **Scheduler** — решает на какой Node запускать Pod
- **Controller Manager** — следит за желаемым состоянием (replicas=3? держи 3)
- **etcd** — база данных состояния кластера (key-value хранилище)

**Worker Nodes** — рабочие лошадки где запускаются контейнеры:
- **kubelet** — агент на каждой ноде, общается с API Server
- **kube-proxy** — сетевой прокси, обеспечивает доступ к сервисам
- **Container Runtime** — Docker или containerd (запускает контейнеры)

---

## Основные ресурсы Kubernetes

### Pod — минимальная единица

Pod — один или несколько контейнеров которые запускаются вместе на одной ноде, разделяют сеть и хранилище.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
    - name: app
      image: nginx:alpine
      ports:
        - containerPort: 80
```

Обычно Pod'ы не создают напрямую — используют Deployment.

### Deployment — управление репликами

Deployment описывает желаемое состояние: какой образ, сколько реплик, как обновлять.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3              # Держать 3 копии всегда
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: webapp
          image: nginx:alpine
          ports:
            - containerPort: 80
```

**Что делает Controller Manager:**
```
Желаемое: replicas=3
Реальное: работает 2 (один упал)
Действие: запустить новый Pod → реальное=3 ✓
```

**Rolling Update** (обновление образа):
```
replicas=3, обновляем image:v1 → image:v2

До:    [v1] [v1] [v1]
Шаг 1: [v1] [v1] [v2]  (один обновлён)
Шаг 2: [v1] [v2] [v2]
Шаг 3: [v2] [v2] [v2]  (все обновлены, downtime = 0)
```

### Service — стабильный сетевой доступ

Pod'ы имеют случайные IP которые меняются при перезапуске. Service даёт стабильный IP и DNS имя.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp          # Направлять трафик к Pod'ам с этой меткой
  ports:
    - port: 80           # Порт Service
      targetPort: 80     # Порт контейнера
  type: NodePort         # Тип Service
```

**Типы Service:**

| Тип | Описание | Когда использовать |
|---|---|---|
| `ClusterIP` | Только внутри кластера (по умолчанию) | Внутренние сервисы |
| `NodePort` | Открывает порт на каждой ноде (30000-32767) | Разработка, тесты |
| `LoadBalancer` | Облачный балансировщик (AWS ELB, GCP LB) | Продакшн в облаке |

**Как Service находит Pod'ы:**
```
Service: selector: {app: webapp}
  ↓
Смотрит все Pod'ы в namespace
  ↓
Выбирает только те у которых label app=webapp
  ↓
Балансирует трафик между ними (round-robin)
```

---

## Labels и Selectors

Labels — метки прикреплённые к ресурсам. Selector — фильтр по меткам.

```yaml
# Pod с метками
metadata:
  labels:
    app: webapp
    version: v2
    environment: prod

# Deployment выбирает Pod'ы по меткам
selector:
  matchLabels:
    app: webapp      # Только Pod'ы с app=webapp
```

Метки — ключевая концепция Kubernetes. Они связывают ресурсы между собой.

---

## Namespace — изоляция ресурсов

Namespace позволяет разделить кластер на виртуальные кластеры:

```bash
# Создать namespace
kubectl create namespace production
kubectl create namespace staging

# Запустить ресурс в namespace
kubectl apply -f deployment.yml -n production

# Смотреть ресурсы в namespace
kubectl get pods -n production
```

По умолчанию ресурсы создаются в namespace `default`.

---

## kubectl — команды

```bash
# Применить манифест
kubectl apply -f deployment.yml
kubectl apply -f .   # Все файлы в папке

# Статус
kubectl get pods                          # Список Pod'ов
kubectl get deployments                   # Список Deployment'ов
kubectl get services                      # Список Service'ов
kubectl get all                           # Всё сразу

# Подробная информация
kubectl describe pod webapp-abc123
kubectl describe deployment webapp

# Логи
kubectl logs webapp-abc123
kubectl logs webapp-abc123 -f             # Follow (в реальном времени)

# Войти в контейнер
kubectl exec -it webapp-abc123 -- sh

# Масштабирование
kubectl scale deployment webapp --replicas=5

# Обновление образа
kubectl set image deployment/webapp webapp=nginx:1.25

# Откат
kubectl rollout undo deployment/webapp

# Удалить ресурс
kubectl delete -f deployment.yml
kubectl delete pod webapp-abc123
```

---

## В нашем проекте

**deployment.yml** — 3 реплики nginx:

```yaml
replicas: 3   # Kubernetes будет держать 3 Pod'а всегда
              # Если один упадёт — запустит новый
```

**service.yml** — NodePort доступ:

```yaml
type: NodePort  # http://<IP-ноды>:<случайный порт 30000-32767>
```

Kubernetes сам выбирает NodePort (можно задать явно: `nodePort: 30080`).

---

## Kubernetes vs Docker Compose

| | Docker Compose | Kubernetes |
|---|---|---|
| Масштаб | 1 сервер | Много серверов |
| Сложность | Простой | Сложный |
| Self-healing | Нет | Да |
| Rolling updates | Нет | Да |
| Использование | Разработка, простые деплои | Продакшн, микросервисы |
