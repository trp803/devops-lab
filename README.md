# DevOps Lab

Учебный DevOps проект — полный стек инструментов для разработки, деплоя и мониторинга приложений.

## Содержание

- [Архитектура](#архитектура)
- [Стек технологий](#стек-технологий)
- [Структура проекта](#структура-проекта)
- [Порты сервисов](#порты-сервисов)
- [Быстрый старт](#быстрый-старт)
- [CI/CD пайплайн](#cicd-пайплайн)
- [Документация](#документация)

---

## Архитектура

```
Интернет
    │
    ▼
┌─────────────────────────────────────────┐
│           Nginx (порт 80)               │
│         Reverse Proxy                   │
│  /          /grafana/    /prometheus/   │
└────┬────────────┬──────────────┬────────┘
     │            │              │
     ▼            ▼              ▼
┌─────────┐  ┌─────────┐  ┌──────────────┐
│ Node.js │  │ Grafana │  │  Prometheus  │
│  :3000  │  │  :3000  │  │    :9090     │
└─────────┘  └────┬────┘  └──────┬───────┘
                  │               │
            ┌─────┴──────┐   ┌────┴────────────┐
            │            │   │                 │
            ▼            ▼   ▼                 ▼
          Loki      Node      cAdvisor
         :3100    Exporter    :8080
                   :9100
                  ▲
                  │
               Promtail
           (читает логи)
```

---

## Стек технологий

| Категория | Технология | Назначение |
|---|---|---|
| Приложение | Node.js | Веб-приложение |
| Контейнеры | Docker + Docker Compose | Упаковка и запуск сервисов |
| Proxy | Nginx | Единая точка входа, роутинг |
| CI/CD | GitHub Actions | Автоматизация тестов и деплоя |
| Безопасность | Trivy | Сканирование образов на уязвимости |
| Тесты | Jest | Unit-тестирование Node.js |
| Метрики | Prometheus | Сбор и хранение метрик |
| Визуализация | Grafana | Дашборды для метрик и логов |
| Метрики сервера | Node Exporter | CPU, RAM, диск, сеть |
| Метрики Docker | cAdvisor | Метрики контейнеров |
| Логи | Loki + Promtail | Сбор, хранение и поиск логов |
| IaC | Ansible | Автоматизация настройки серверов |
| Оркестрация | Kubernetes | Управление контейнерами в кластере |
| БД | MongoDB + MySQL | NoSQL и реляционная БД |

---

## Структура проекта

```
devops-lab/
├── .github/
│   └── workflows/
│       ├── deploy.yml        # CI/CD для prod (main ветка)
│       └── deploy-dev.yml    # CI/CD для dev ветки
│
├── ansible/                  # Автоматизация настройки серверов
│   ├── inventory.ini         # Список серверов
│   ├── site.yml              # Главный плейбук
│   ├── docker-deploy.yml     # Установка Docker и деплой
│   └── roles/
│       └── webserver/        # Роль для настройки веб-сервера
│
├── bash/                     # Вспомогательные скрипты
│   ├── backup.sh             # Создание бэкапов
│   ├── deploy.sh             # Деплой Docker контейнеров
│   ├── healthcheck.sh        # Проверка состояния сервера
│   └── server-info.sh        # Информация о сервере
│
├── docker/                   # Docker конфигурации
│   ├── Dockerfile            # Базовый Dockerfile
│   ├── nodeapp/              # Node.js приложение
│   │   ├── app.js            # Код приложения
│   │   ├── app.test.js       # Jest тесты
│   │   ├── package.json      # Зависимости
│   │   └── Dockerfile        # Multi-stage сборка
│   ├── webapp/               # Статический сайт
│   ├── wordpress/            # WordPress + MySQL
│   └── mongodb/              # MongoDB + Mongo Express
│
├── kubernetes/               # Kubernetes манифесты
│   ├── deployment.yml        # Описание деплоя
│   └── service.yml           # Сетевой доступ к подам
│
├── monitoring/               # Полный стек мониторинга
│   ├── docker-compose.yml    # Все сервисы мониторинга
│   ├── prometheus/
│   │   └── prometheus.yml    # Настройка сбора метрик
│   ├── loki/
│   │   └── loki.yml          # Настройка хранения логов
│   ├── promtail/
│   │   └── promtail.yml      # Настройка сбора логов
│   └── grafana/
│       └── provisioning/
│           └── datasources/
│               └── datasources.yml  # Автоподключение источников
│
├── nginx/                    # Reverse proxy
│   ├── nginx.conf            # Конфигурация Nginx
│   └── docker-compose.yml    # Запуск Nginx + nodeapp
│
├── final-project/            # Финальный проект
│   ├── Dockerfile
│   └── app/index.html
│
└── docs/                     # Документация и теория
    ├── 01-docker.md
    ├── 02-cicd.md
    ├── 03-monitoring.md
    ├── 04-logging.md
    ├── 05-nginx.md
    ├── 06-ansible.md
    ├── 07-kubernetes.md
    └── 08-testing.md
```

---

## Порты сервисов

| Сервис | Порт | URL |
|---|---|---|
| Nginx (proxy) | `80` | http://localhost |
| Node.js app | `3000` | внутренний (через Nginx: http://localhost/) |
| Grafana | `3001` | http://localhost:3001 (логин: admin / admin123) |
| Prometheus | `9090` | http://localhost:9090 |
| Node Exporter | `9100` | http://localhost:9100/metrics |
| cAdvisor | `8082` | http://localhost:8082 |
| Loki | `3100` | http://localhost:3100 |
| WordPress | `8080` | http://localhost:8080 |
| MongoDB | `27017` | mongodb://localhost:27017 |
| Mongo Express | `8081` | http://localhost:8081 |

---

## Быстрый старт

### 1. Клонировать репозиторий

```bash
git clone https://github.com/trp803/devops-lab.git
cd devops-lab
```

### 2. Запустить мониторинг

```bash
cd monitoring
docker compose up -d
```

Открыть Grafana: http://localhost:3001
Логин: `admin` / Пароль: `admin123`

### 3. Запустить Node.js приложение через Nginx

```bash
cd nginx
docker compose up -d
```

Открыть: http://localhost

### 4. Запустить WordPress

```bash
cd docker/wordpress
cp .env.example .env   # заполни переменные
docker compose up -d
```

Открыть: http://localhost:8080

### 5. Запустить MongoDB

```bash
cd docker/mongodb
cp .env.example .env   # заполни переменные
docker compose up -d
```

Mongo Express: http://localhost:8081

### 6. Запустить тесты

```bash
cd docker/nodeapp
npm install
npm test
```

---

## CI/CD пайплайн

При каждом push в ветку `main` автоматически запускается пайплайн из 4 этапов:

```
Push в main
    │
    ▼
┌──────────┐     ┌──────────┐     ┌─────────────┐     ┌─────────┐
│  Tests   │────▶│ Security │────▶│ Build+Push  │────▶│ Deploy  │
│  (Jest)  │     │ (Trivy)  │     │ (Docker Hub)│     │(SSH+TG) │
└──────────┘     └──────────┘     └─────────────┘     └─────────┘
```

**Требуемые секреты в GitHub:**

| Секрет | Описание |
|---|---|
| `SERVER_HOST` | IP адрес сервера |
| `SERVER_USER` | SSH пользователь |
| `SERVER_SSH_KEY` | Приватный SSH ключ |
| `DOCKERHUB_USERNAME` | Логин Docker Hub |
| `DOCKERHUB_TOKEN` | Токен Docker Hub |
| `TELEGRAM_TOKEN` | Токен Telegram бота |
| `TELEGRAM_CHAT_ID` | ID чата для уведомлений |

---

## Документация

Подробная теория по каждой технологии в папке [`docs/`](docs/):

| Файл | Тема |
|---|---|
| [01-docker.md](docs/01-docker.md) | Docker — контейнеры, образы, Compose |
| [02-cicd.md](docs/02-cicd.md) | CI/CD — GitHub Actions, пайплайны |
| [03-monitoring.md](docs/03-monitoring.md) | Мониторинг — Prometheus, Grafana, метрики |
| [04-logging.md](docs/04-logging.md) | Логирование — Loki, Promtail |
| [05-nginx.md](docs/05-nginx.md) | Nginx — reverse proxy, роутинг |
| [06-ansible.md](docs/06-ansible.md) | Ansible — автоматизация, плейбуки, роли |
| [07-kubernetes.md](docs/07-kubernetes.md) | Kubernetes — поды, деплойменты, сервисы |
| [08-testing.md](docs/08-testing.md) | Тестирование — Jest, unit тесты |
