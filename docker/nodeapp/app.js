// Встроенный модуль Node.js для создания HTTP сервера
const http = require('http');

// Встроенный модуль Node.js для получения информации об операционной системе
const os = require('os');

// Создаём HTTP сервер
// Каждый раз когда приходит запрос — вызывается callback (req, res)
// req — объект запроса (откуда пришёл, какой метод, заголовки)
// res — объект ответа (что отправить обратно)
const server = http.createServer((req, res) => {

  // Устанавливаем HTTP статус 200 (OK) и заголовок Content-Type
  // charset=utf-8 — чтобы кириллица отображалась корректно
  res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'});

  // Отправляем HTML страницу и закрываем соединение
  // Шаблонные строки (`) позволяют вставлять переменные через ${}
  res.end(`
    <!DOCTYPE html>
    <html>
    <head><meta charset="UTF-8"></head>
    <body style="font-family:Arial;background:#1a1a2e;color:#eee;text-align:center;padding:50px">
      <h1>🚀 Node.js App</h1>
      <!-- os.hostname() — имя контейнера (в Docker это ID контейнера) -->
      <p>Hostname: ${os.hostname()}</p>
      <!-- os.platform() — операционная система: linux, darwin, win32 -->
      <p>Platform: ${os.platform()}</p>
      <!-- os.uptime() — время работы системы в секундах, Math.floor убирает дробную часть -->
      <p>Uptime: ${Math.floor(os.uptime())} sec</p>
    </body>
    </html>
  `);
});

// Запускаем сервер на порту 3000
// Callback вызывается один раз когда сервер успешно стартовал
server.listen(3000, () => {
  console.log('Server running on port 3000');
});
