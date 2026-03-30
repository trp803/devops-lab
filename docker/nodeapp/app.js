// Встроенный модуль Node.js для создания HTTP сервера
const http = require('http');

// Встроенный модуль Node.js для получения информации об операционной системе
const os = require('os');

// prom-client — официальная библиотека Prometheus для Node.js
// Добавляет эндпоинт /metrics который Prometheus будет опрашивать каждые 15 секунд
const client = require('prom-client');

// ─────────────────────────────────────────
// НАСТРОЙКА PROMETHEUS МЕТРИК
// ─────────────────────────────────────────

// Registry — реестр всех метрик приложения
// collectDefaultMetrics() — автоматически добавляет стандартные метрики Node.js:
//   process_cpu_seconds_total    — использование CPU процессом
//   process_resident_memory_bytes — потребление RAM
//   nodejs_heap_size_total_bytes  — размер V8 heap (памяти движка)
//   nodejs_eventloop_lag_seconds  — задержка event loop (признак перегрузки)
//   nodejs_active_handles_total   — активные соединения/таймеры
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Counter — счётчик HTTP запросов
// Только растёт, никогда не уменьшается
// labels (метки) позволяют разбивать метрику по значениям:
//   method="GET", route="/", status_code="200"
// В Grafana можно фильтровать: rate(http_requests_total{status_code="500"}[5m])
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',          // Имя метрики в Prometheus
  help: 'Общее количество HTTP запросов', // Описание (видно в /metrics)
  labelNames: ['method', 'route', 'status_code'], // Возможные метки
  registers: [register],
});

// Histogram — распределение времени ответа по корзинам (buckets)
// Например: сколько запросов выполнились за <10мс, <50мс, <200мс, <500мс...
// Позволяет считать перцентили: p50, p95, p99
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Время выполнения HTTP запросов в секундах',
  labelNames: ['method', 'route', 'status_code'],
  // buckets — границы корзин в секундах
  // Запрос за 120мс попадёт в корзины 0.05, 0.1, 0.2, 0.5, 1 (все которые >= 120мс)
  buckets: [0.005, 0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5],
  registers: [register],
});

// Gauge — текущее количество активных запросов (может расти и уменьшаться)
// Полезно для обнаружения: если активных запросов накапливается — сервер не справляется
const httpRequestsActive = new client.Gauge({
  name: 'http_requests_active',
  help: 'Количество запросов обрабатываемых прямо сейчас',
  registers: [register],
});

// ─────────────────────────────────────────
// HTTP СЕРВЕР
// ─────────────────────────────────────────

const server = http.createServer(async (req, res) => {

  // ── Эндпоинт /metrics — для Prometheus ──
  // Prometheus делает GET /metrics каждые 15 секунд и забирает все метрики
  // Формат: text/plain, каждая метрика на своей строке
  if (req.url === '/metrics') {
    try {
      // register.metrics() — собирает все зарегистрированные метрики в текст
      const metrics = await register.metrics();
      res.writeHead(200, { 'Content-Type': register.contentType });
      res.end(metrics);
    } catch (err) {
      res.writeHead(500);
      res.end(err.message);
    }
    return; // Не считаем /metrics в статистике — это внутренний эндпоинт
  }

  // ── Для всех остальных запросов — измеряем метрики ──

  // Фиксируем время начала запроса для измерения длительности
  // process.hrtime.bigint() — высокоточный таймер в наносекундах
  const startTime = Date.now();

  // Увеличиваем счётчик активных запросов
  httpRequestsActive.inc();

  // Определяем маршрут для метки
  // Нормализуем URL: убираем query string (?foo=bar), берём только путь
  const route = req.url.split('?')[0] || '/';

  // ── Основная логика ──
  let statusCode = 200;

  if (route === '/health') {
    // Health check endpoint — используется Docker healthcheck и мониторингом
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK');
  } else {
    // Главная страница
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(`
      <!DOCTYPE html>
      <html>
      <head><meta charset="UTF-8"></head>
      <body style="font-family:Arial;background:#1a1a2e;color:#eee;text-align:center;padding:50px">
        <h1>🚀 Node.js App</h1>
        <p>Hostname: ${os.hostname()}</p>
        <p>Platform: ${os.platform()}</p>
        <p>Uptime: ${Math.floor(os.uptime())} sec</p>
        <p><a href="/metrics" style="color:#7ec8e3">📊 Метрики Prometheus</a></p>
      </body>
      </html>
    `);
  }

  // ── Записываем метрики после завершения запроса ──

  // Длительность в секундах (Prometheus использует секунды как стандарт)
  const duration = (Date.now() - startTime) / 1000;

  const labels = {
    method: req.method,           // GET, POST, PUT...
    route: route,                 // /, /health, /api/...
    status_code: String(statusCode), // "200", "404", "500"
  };

  // Увеличиваем счётчик запросов
  httpRequestsTotal.inc(labels);

  // Записываем длительность в histogram
  httpRequestDuration.observe(labels, duration);

  // Уменьшаем счётчик активных запросов
  httpRequestsActive.dec();
});

// Запускаем сервер на порту 3000
server.listen(3000, () => {
  console.log('Server running on port 3000');
  console.log('Metrics available at http://localhost:3000/metrics');
});
