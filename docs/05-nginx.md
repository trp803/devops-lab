# Nginx — reverse proxy

## Что такое Nginx

Nginx (произносится "engine-x") — высокопроизводительный веб-сервер и reverse proxy. Создан в 2004 году Игорем Сысоевым для решения проблемы C10k (обработка 10 000 одновременных соединений).

**Nginx умеет:**
- Обслуживать статические файлы (HTML, CSS, JS, изображения)
- Работать как reverse proxy (перенаправлять запросы к другим сервисам)
- Балансировать нагрузку между несколькими серверами
- Терминировать SSL (обрабатывать HTTPS)
- Кешировать ответы
- Ограничивать запросы (rate limiting)

---

## Reverse Proxy — зачем это нужно

**Без reverse proxy:**
```
Пользователь → Node.js :3000
Пользователь → Grafana :3001
Пользователь → Prometheus :9090
```
Проблемы:
- У каждого сервиса свой порт — неудобно
- Нельзя использовать стандартный порт 80/443
- Каждый сервис нужно защищать отдельно

**С reverse proxy (Nginx):**
```
Пользователь → Nginx :80
    Nginx → /          → Node.js :3000
    Nginx → /grafana/  → Grafana :3000
    Nginx → /prometheus/ → Prometheus :9090
```
Преимущества:
- Один порт 80 для всего
- SSL настраивается один раз в Nginx
- Внутренние сервисы не видны снаружи
- Единое место для логирования, rate limiting, аутентификации

---

## Как работает Nginx

Nginx использует **event-driven** (событийную) архитектуру:

```
Apache (старая модель):          Nginx (новая модель):
1 запрос = 1 поток               1 воркер = много соединений
                                  через неблокирующий I/O
[запрос1] → [поток1]             [воркер] ←─ [запрос1]
[запрос2] → [поток2]                     ←─ [запрос2]
[запрос3] → [поток3]                     ←─ [запрос3]
1000 запросов = 1000 потоков     1000 запросов = 1 воркер
```

При 10000 соединениях Apache создаёт 10000 потоков (огромный расход RAM). Nginx обрабатывает их одним или несколькими воркерами асинхронно.

---

## Конфигурация Nginx

### Структура конфига

```nginx
events { }           # Настройки обработки соединений

http {               # HTTP контекст
  upstream { }       # Группы серверов для проксирования
  server {           # Виртуальный хост
    location { }     # Правила обработки URL
  }
}
```

### upstream — балансировка нагрузки

```nginx
upstream nodeapp {
    server nodeapp:3000;           # Один сервер
}

# Или несколько для балансировки:
upstream backend {
    server backend1:3000;
    server backend2:3000;          # Round-robin по умолчанию
    server backend3:3000 weight=2; # backend3 получает в 2 раза больше запросов
}
```

**Алгоритмы балансировки:**
- `round-robin` (по умолчанию) — по очереди
- `least_conn` — на сервер с наименьшим числом соединений
- `ip_hash` — один клиент всегда попадает на один сервер (sticky sessions)

### location — роутинг запросов

```nginx
# Точное совпадение (= )
location = /health {
    return 200 'OK';
}

# Префиксное совпадение (по умолчанию)
location /api/ {
    proxy_pass http://backend;
}

# Regex совпадение (~)
location ~ \.(jpg|png|gif)$ {
    root /var/www/images;
}
```

**Приоритет:** `=` > regex > длинный prefix > короткий prefix

### proxy_pass и заголовки

```nginx
location / {
    proxy_pass http://nodeapp;

    # Обязательные заголовки для корректной работы proxy:
    proxy_set_header Host $host;
    # Без этого приложение видит IP Nginx вместо реального клиента
    proxy_set_header X-Real-IP $remote_addr;
    # Цепочка прокси: "1.2.3.4, 10.0.0.1"
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

### Gzip сжатие

```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript;
# Сжатие уменьшает размер ответа на 60-80%
# Браузер отправляет заголовок: Accept-Encoding: gzip
# Nginx сжимает ответ и добавляет: Content-Encoding: gzip
```

---

## SSL/HTTPS (для продакшна)

В нашем проекте HTTP для простоты. В реальном продакшне нужен HTTPS:

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /etc/ssl/cert.pem;
    ssl_certificate_key /etc/ssl/key.pem;

    location / {
        proxy_pass http://nodeapp;
    }
}

# Редирект с HTTP на HTTPS
server {
    listen 80;
    return 301 https://$host$request_uri;
}
```

Для автоматического получения бесплатных сертификатов используют **Let's Encrypt + Certbot**.

---

## Nginx в нашем проекте

```
Запрос: GET http://localhost/grafana/dashboard
    │
    ▼
Nginx (порт 80)
    │
    │ location /grafana/ совпадает
    │ proxy_pass http://grafana/
    ▼
Grafana (порт 3000 внутри Docker сети)
    │
    │ Ответ: 200 OK
    ▼
Nginx
    │ Добавляет заголовки логирования
    ▼
Клиент получает ответ
```

**Важный нюанс со слешем:**
```nginx
location /grafana/ {
    proxy_pass http://grafana/;   # Слеш в конце
}
```
Запрос `/grafana/foo` → Grafana получает `/foo` (не `/grafana/foo`).
Без слеша → Grafana получила бы `/grafana/foo` — это обычно неверно.

---

## Health check endpoint

```nginx
location /health {
    access_log off;          # Не засорять логи
    return 200 'OK';
    add_header Content-Type text/plain;
}
```

Используется:
- Load balancer'ами для проверки что Nginx живой
- Kubernetes liveness probe
- Мониторингом (Prometheus Blackbox Exporter)

---

## Полезные команды

```bash
# Проверить конфиг без перезапуска
nginx -t

# Перезагрузить конфиг без остановки (zero-downtime)
nginx -s reload

# Посмотреть логи в реальном времени
tail -f /var/log/nginx/access.log

# Через Docker
docker exec nginx-proxy nginx -t
docker exec nginx-proxy nginx -s reload
```
