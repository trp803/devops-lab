# Логирование — Loki + Promtail

## Зачем нужна система логирования

Логи — это текстовые записи о том что происходит в приложении. Без централизованного логирования:
- Нужно заходить по SSH на каждый сервер
- `docker logs myapp` показывает только последние N строк
- Логи пропадают при удалении контейнера
- Нельзя искать по логам нескольких сервисов одновременно

**Стек ELK** (Elasticsearch + Logstash + Kibana) — классическое решение, но тяжёлое (Elasticsearch требует много RAM).

**Стек PLG** (Promtail + Loki + Grafana) — наше решение, лёгкое и интегрируется с уже существующей Grafana.

---

## Loki — база данных для логов

### Принцип работы

Loki создан командой Grafana по образу Prometheus, но для логов.

**Ключевое отличие от Elasticsearch:**
- Elasticsearch индексирует **всё содержимое** логов → быстрый поиск, но много RAM и диска
- Loki индексирует только **метки** (labels) → дешевле, но поиск медленнее

Loki хранит логи как есть (не парсит содержимое), только добавляет метки для фильтрации.

### Архитектура Loki

```
Запись:
Promtail ──► Distributor ──► Ingester ──► Chunks (файлы на диске)

Чтение:
Grafana ──► Querier ──► Index (boltdb) + Chunks
```

- **Ingester** — принимает логи в память и периодически сбрасывает на диск (chunks)
- **Chunk** — сжатый блок логов за определённый период
- **Index** — индекс меток → где искать нужные chunks

### Метки в Loki

Метки — это ключ-значение прикреплённые к потоку логов:

```
{job="docker", stream="stdout", container_name="nodeapp"}
```

По меткам Grafana фильтрует какие логи показывать. Не добавляйте метки с высокой кардинальностью (много уникальных значений) — это замедляет Loki.

**Хорошие метки:** `job`, `service`, `environment`, `stream`
**Плохие метки:** `request_id`, `user_id`, `timestamp` (уникальны для каждого лога)

### loki.yml — ключевые настройки

```yaml
ingester:
  chunk_idle_period: 5m    # Записать чанк если 5 мин нет новых логов
  chunk_retain_period: 30s # Держать в памяти 30с после записи (кеш)

limits_config:
  retention_period: 720h   # Хранить 30 дней

compactor:
  retention_enabled: true  # Автоудаление старых логов
```

### LogQL — язык запросов Loki

LogQL — язык запросов, похожий на PromQL:

```logql
# Все логи контейнера nodeapp
{container_name="nodeapp"}

# Только ошибки
{job="docker"} |= "error"

# Исключить healthcheck запросы
{job="docker"} != "GET /health"

# Парсить JSON логи
{job="docker"} | json | level="error"

# Количество ошибок в минуту (метрика из логов)
rate({job="docker"} |= "error" [1m])
```

---

## Promtail — агент сбора логов

Promtail — агент который читает лог-файлы и отправляет их в Loki. Работает на каждом сервере/контейнере.

### Как Docker пишет логи

Docker по умолчанию пишет логи каждого контейнера в JSON файл:

```
/var/lib/docker/containers/<container_id>/<container_id>-json.log
```

Каждая строка — JSON объект:
```json
{"log":"Server running on port 3000\n","stream":"stdout","time":"2026-03-30T10:00:00Z"}
```

Promtail читает эти файлы и парсит JSON через `pipeline_stages`.

### positions.yaml

Промтейл запоминает до какого байта дочитал каждый файл:

```yaml
# /tmp/positions.yaml (создаётся автоматически)
positions:
  /var/lib/docker/containers/abc123.../abc123...-json.log: "15234"
```

При перезапуске Promtail продолжает с того же места — не теряет и не дублирует логи.

### pipeline_stages — обработка логов

```yaml
pipeline_stages:
  - json:                     # Парсим JSON формат Docker
      expressions:
        log: log              # Извлекаем текст лога
        stream: stream        # stdout или stderr
        time: time            # Временная метка

  - labels:
      stream:                 # Добавляем stream как метку Loki

  - timestamp:
      source: time            # Используем время из лога (не время получения)
      format: RFC3339Nano
```

**Важно:** используем время из лога (не время когда Promtail его прочитал). Это нужно для корректного отображения на временной шкале в Grafana.

---

## Grafana Provisioning

Без provisioning нужно каждый раз после перезапуска Grafana вручную добавлять datasources через UI.

С provisioning — Grafana читает YAML файлы при старте и настраивается автоматически:

```yaml
# monitoring/grafana/provisioning/datasources/datasources.yml
datasources:
  - name: Loki
    type: loki
    url: http://loki:3100
```

Файл монтируется в контейнер:
```yaml
volumes:
  - ./grafana/provisioning:/etc/grafana/provisioning
```

---

## Как всё работает вместе

```
Docker контейнеры
    │ пишут логи в
    ▼
/var/lib/docker/containers/*/*.log
    │
    │ Promtail читает файлы (следит как tail -f)
    ▼
Promtail
    │ парсит JSON, добавляет метки
    │ POST /loki/api/v1/push
    ▼
Loki
    │ сохраняет chunks на диск
    ▼
Grafana
    │ LogQL запрос
    ▼
Пользователь видит логи в браузере
```

---

## Просмотр логов в Grafana

1. Открыть http://localhost:3001
2. Перейти в **Explore** (значок компаса)
3. Выбрать datasource **Loki**
4. Написать запрос: `{job="docker"}`
5. Нажать **Run query**

Можно фильтровать по контейнеру, уровню логов, временному диапазону.
