# Мониторинг — Prometheus + Grafana

## Зачем нужен мониторинг

Без мониторинга вы узнаёте о проблемах от пользователей. С мониторингом — видите проблему до того как она стала критической.

Мониторинг отвечает на вопросы:
- Сколько памяти использует приложение прямо сейчас?
- Выросло ли время ответа API за последний час?
- Сколько ошибок 500 за последние 5 минут?
- Заканчивается ли место на диске?

---

## Prometheus — система сбора метрик

### Что такое метрики

Метрика — числовое значение в момент времени с набором меток:

```
http_requests_total{method="GET", status="200"} 1234  1711800000
```
- `http_requests_total` — имя метрики
- `{method="GET", status="200"}` — метки (labels) для фильтрации
- `1234` — значение
- `1711800000` — временная метка (unix timestamp)

### Pull модель

Prometheus работает по принципу **pull** — сам приходит к сервисам и забирает метрики по HTTP.

```
Prometheus (каждые 15 сек)
    │
    ├──► GET http://node-exporter:9100/metrics
    ├──► GET http://cadvisor:8080/metrics
    └──► GET http://localhost:9090/metrics (себя)
```

Альтернатива — push модель (сервисы сами отправляют метрики). Push используется в Graphite, InfluxDB.

**Преимущества pull:**
- Prometheus знает что сервис живой (если не отвечает — алерт)
- Централизованное управление: кого опрашивать настраивается в одном месте
- Легко отлаживать: можно открыть `/metrics` в браузере

### Типы метрик

| Тип | Описание | Пример |
|---|---|---|
| **Counter** | Только растёт, никогда не уменьшается | `http_requests_total` |
| **Gauge** | Может расти и уменьшаться | `memory_usage_bytes` |
| **Histogram** | Распределение значений по bucket'ам | `request_duration_seconds` |
| **Summary** | Квантили (percentile) | `request_duration_p99` |

### prometheus.yml — конфигурация

```yaml
global:
  scrape_interval: 15s   # Как часто опрашивать сервисы

scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
```

`job_name` становится меткой `job` во всех метриках — удобно для фильтрации в Grafana.

### PromQL — язык запросов

Prometheus использует собственный язык запросов PromQL:

```promql
# Текущее использование CPU (в процентах)
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Свободная память в GB
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024

# Количество запросов в секунду за последние 5 минут
rate(http_requests_total[5m])

# 95-й перцентиль времени ответа
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

---

## Node Exporter — метрики сервера

Node Exporter — агент который запускается на сервере и отдаёт системные метрики в формате Prometheus.

**Что собирает:**

| Метрика | Описание |
|---|---|
| `node_cpu_seconds_total` | Использование CPU по режимам (idle, user, system) |
| `node_memory_MemTotal_bytes` | Общий объём RAM |
| `node_memory_MemAvailable_bytes` | Доступная RAM |
| `node_filesystem_size_bytes` | Размер файловых систем |
| `node_filesystem_avail_bytes` | Свободное место |
| `node_network_receive_bytes_total` | Входящий трафик |
| `node_network_transmit_bytes_total` | Исходящий трафик |
| `node_load1` | Load average за 1 минуту |

Node Exporter монтирует `/proc` и `/sys` с хоста — именно оттуда Linux предоставляет все системные метрики.

---

## cAdvisor — метрики контейнеров

cAdvisor (Container Advisor) от Google — собирает метрики для каждого Docker контейнера.

**Что собирает:**

| Метрика | Описание |
|---|---|
| `container_cpu_usage_seconds_total` | CPU использование контейнера |
| `container_memory_usage_bytes` | RAM контейнера |
| `container_network_receive_bytes_total` | Входящий трафик контейнера |
| `container_fs_reads_bytes_total` | Чтение с диска |

Метки позволяют фильтровать по конкретному контейнеру:
```promql
container_memory_usage_bytes{name="nodeapp"}
```

---

## Grafana — визуализация

Grafana — инструмент для создания дашбордов. Сама не хранит данные — читает из источников (Prometheus, Loki, InfluxDB и др.).

### Datasources (источники данных)

В нашем проекте автоматически подключаются через provisioning:
- **Prometheus** — источник метрик (по умолчанию)
- **Loki** — источник логов

### Дашборды

Дашборд — набор панелей (графиков, таблиц, счётчиков). Каждая панель выполняет запрос к datasource.

**Популярные готовые дашборды (импортируются по ID):**

| ID | Название |
|---|---|
| 1860 | Node Exporter Full |
| 14282 | Cadvisor Exporter |
| 13639 | Logs / Loki |

### Alerting

Grafana умеет отправлять алерты в Telegram, Slack, email когда метрика выходит за порог:

```
Правило: если node_memory_MemAvailable_bytes < 500MB
→ отправить уведомление в Telegram
```

---

## Как всё работает вместе

```
1. Node Exporter читает /proc/meminfo, /proc/stat
2. cAdvisor читает Docker API
3. Prometheus каждые 15с делает GET /metrics к каждому экспортеру
4. Prometheus сохраняет метрики в свою TSDB (time series database)
5. Grafana делает PromQL запросы к Prometheus
6. Grafana рисует графики
7. Пользователь видит дашборды в браузере
```

---

## Запуск

```bash
cd monitoring
docker compose up -d

# Проверить что все запустились
docker compose ps

# Grafana
open http://localhost:3001
# Логин: admin / Пароль: admin123

# Prometheus
open http://localhost:9090

# Raw метрики Node Exporter
curl http://localhost:9100/metrics | head -50
```
