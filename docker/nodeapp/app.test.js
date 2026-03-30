// Встроенный модуль для создания HTTP запросов — используем для тестирования сервера
const http = require('http');

// Встроенный модуль ОС — тестируем что он возвращает корректные значения
const os = require('os');

// describe — группирует связанные тесты под одним названием
// Все тесты ниже относятся к "Node.js App"
describe('Node.js App', () => {

  // test() — один тест. Первый аргумент — описание, второй — функция с проверками
  test('os.hostname() возвращает строку', () => {
    // expect().toBe() — проверяем что значение строго равно ожидаемому
    expect(typeof os.hostname()).toBe('string');
    // toBeGreaterThan() — проверяем что hostname не пустой
    expect(os.hostname().length).toBeGreaterThan(0);
  });

  test('os.platform() возвращает строку', () => {
    expect(typeof os.platform()).toBe('string');
  });

  test('os.uptime() возвращает число больше 0', () => {
    // Сервер всегда работает какое-то время — uptime не может быть 0
    expect(os.uptime()).toBeGreaterThan(0);
  });

  // done — callback который вызываем когда асинхронный тест завершён
  // Нужен потому что HTTP запрос — асинхронная операция
  test('HTTP сервер запускается и отвечает 200', (done) => {
    const server = http.createServer((req, res) => {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end('<h1>OK</h1>');
    });

    // Порт 0 — ОС сама выберет свободный порт
    // Это важно: если написать конкретный порт, тесты могут конфликтовать
    server.listen(0, () => {
      // server.address().port — получаем реальный порт который выбрала ОС
      const port = server.address().port;

      // Делаем GET запрос к только что запущенному серверу
      http.get(`http://localhost:${port}`, (res) => {
        // Проверяем статус ответа
        expect(res.statusCode).toBe(200);
        // Проверяем Content-Type заголовок
        expect(res.headers['content-type']).toContain('text/html');
        // Закрываем сервер и сигнализируем Jest что тест завершён
        server.close(done);
      });
    });
  });

  test('HTTP ответ содержит HTML', (done) => {
    const server = http.createServer((req, res) => {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(`<h1>Node.js App</h1><p>Hostname: ${os.hostname()}</p>`);
    });

    server.listen(0, () => {
      const port = server.address().port;
      http.get(`http://localhost:${port}`, (res) => {
        let data = '';
        // Данные приходят чанками — собираем их в строку
        res.on('data', chunk => { data += chunk; });
        // end — все данные получены, можно проверять
        res.on('end', () => {
          // toContain() — проверяем что строка содержит подстроку
          expect(data).toContain('Node.js App');
          expect(data).toContain('Hostname');
          server.close(done);
        });
      });
    });
  });
});
