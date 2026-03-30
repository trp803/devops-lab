# Тестирование — Jest и виды тестов

## Зачем нужны тесты

Без тестов:
- Исправил баг в одном месте → сломал другое место
- Сложно рефакторить — непонятно что сломается
- "Работает на моей машине" → не работает на проде

С тестами:
- Изменил код → запустил тесты → сразу видно что сломалось
- Безопасный рефакторинг
- Документация через тесты (понятно как должен работать код)

---

## Виды тестов

```
         /\
        /  \       E2E тесты
       /    \      (медленные, дорогие)
      /──────\
     /        \    Интеграционные тесты
    /          \
   /────────────\
  /              \  Unit тесты
 /________________\ (быстрые, дешёвые)

Пирамида тестирования
```

### Unit тесты (наш проект)
Тестируют **одну функцию/модуль** изолированно. Быстрые, дешёвые.

```javascript
test('os.uptime() возвращает число больше 0', () => {
  expect(os.uptime()).toBeGreaterThan(0);
});
```

### Интеграционные тесты
Тестируют **взаимодействие компонентов**. Медленнее, но ближе к реальности.

```javascript
// Тест: Node.js сервер + HTTP клиент
test('HTTP сервер отвечает 200', (done) => {
  const server = http.createServer(...);
  server.listen(0, () => {
    http.get(`http://localhost:${port}`, (res) => {
      expect(res.statusCode).toBe(200);
      server.close(done);
    });
  });
});
```

### E2E тесты (End-to-End)
Тестируют **всё приложение** как пользователь. Selenium, Playwright, Cypress.

```javascript
// Пример E2E (не в нашем проекте)
test('пользователь может войти', async () => {
  await page.goto('http://localhost:8080');
  await page.fill('#username', 'admin');
  await page.fill('#password', 'secret');
  await page.click('#submit');
  await expect(page).toHaveURL('/dashboard');
});
```

---

## Jest — фреймворк тестирования

Jest — самый популярный тест-фреймворк для JavaScript/Node.js. Создан Facebook.

**Возможности:**
- Запуск тестов
- Assertions (проверки expect)
- Моки (mock functions)
- Coverage (покрытие кода)
- Watch mode (перезапуск при изменении файлов)

### Установка

```json
// package.json
{
  "scripts": {
    "test": "jest"
  },
  "devDependencies": {
    "jest": "^29.0.0"
  }
}
```

```bash
npm install
npm test
```

---

## Структура тестов

### describe — группировка

```javascript
describe('Группа тестов', () => {
  test('тест 1', () => { ... });
  test('тест 2', () => { ... });

  describe('Подгруппа', () => {
    test('тест 3', () => { ... });
  });
});
```

### test / it — один тест

`test` и `it` — синонимы:

```javascript
test('описание что должно работать', () => {
  // Arrange (подготовка)
  const input = 5;

  // Act (действие)
  const result = multiply(input, 2);

  // Assert (проверка)
  expect(result).toBe(10);
});
```

---

## Assertions — проверки

```javascript
// Равенство
expect(value).toBe(42);              // ===  (строгое)
expect(object).toEqual({a: 1});      // Глубокое сравнение объектов

// Числа
expect(value).toBeGreaterThan(0);
expect(value).toBeLessThan(100);
expect(value).toBeCloseTo(3.14, 2);  // float с точностью до 2 знаков

// Строки
expect(str).toContain('hello');
expect(str).toMatch(/regex/);

// Истинность
expect(value).toBeTruthy();
expect(value).toBeFalsy();
expect(value).toBeNull();
expect(value).toBeUndefined();

// Массивы
expect(array).toHaveLength(3);
expect(array).toContain('item');

// Исключения
expect(() => { throw new Error() }).toThrow();
expect(() => divide(1, 0)).toThrow('Division by zero');

// Отрицание (not)
expect(value).not.toBe(0);
expect(str).not.toContain('error');
```

---

## Асинхронные тесты

Node.js часто работает асинхронно (HTTP запросы, файлы, БД). Jest поддерживает три способа:

### 1. done callback

```javascript
test('асинхронный тест', (done) => {
  http.get('http://localhost:3000', (res) => {
    expect(res.statusCode).toBe(200);
    done();   // Сигнал что тест завершён
  });
  // Если done не вызвать за 5 секунд — тест упадёт с timeout
});
```

### 2. Promise

```javascript
test('с Promise', () => {
  return fetch('http://localhost:3000')
    .then(res => {
      expect(res.status).toBe(200);
    });
  // Jest ждёт пока Promise разрешится
});
```

### 3. async/await (современный способ)

```javascript
test('с async/await', async () => {
  const res = await fetch('http://localhost:3000');
  expect(res.status).toBe(200);
});
```

---

## Наши тесты

```javascript
// app.test.js

describe('Node.js App', () => {

  // Unit тест — тестируем os модуль
  test('os.hostname() возвращает строку', () => {
    expect(typeof os.hostname()).toBe('string');
    expect(os.hostname().length).toBeGreaterThan(0);
  });

  // Интеграционный тест — HTTP сервер + клиент
  test('HTTP сервер отвечает 200', (done) => {
    const server = http.createServer((req, res) => {
      res.writeHead(200);
      res.end('OK');
    });

    server.listen(0, () => {          // порт 0 = ОС выбирает свободный
      const port = server.address().port;
      http.get(`http://localhost:${port}`, (res) => {
        expect(res.statusCode).toBe(200);
        server.close(done);           // Закрываем сервер после теста
      });
    });
  });
});
```

**Почему порт 0?**
Если написать конкретный порт (например 3000) — тесты могут конфликтовать если запускать параллельно или если порт занят приложением. Порт 0 просит ОС выбрать свободный порт автоматически.

---

## Запуск тестов

```bash
# Запустить все тесты
npm test

# Watch mode — перезапускать при изменении файлов
npm test -- --watch

# С покрытием кода
npm test -- --coverage

# Конкретный файл
npm test app.test.js

# Конкретный тест (по названию)
npm test -- --testNamePattern="HTTP сервер"
```

---

## Coverage — покрытие кода

Coverage показывает какой процент кода покрыт тестами:

```bash
npm test -- --coverage

# Вывод:
# File        | % Stmts | % Branch | % Funcs | % Lines
# app.js      |   85.71 |    66.67 |     100 |   85.71
```

- **Statements** — строки кода
- **Branches** — ветки if/else
- **Functions** — функции
- **Lines** — строки

100% coverage не цель — важно покрывать критическую бизнес-логику.

---

## Тесты в CI/CD

В нашем пайплайне тесты запускаются автоматически:

```yaml
- name: Run tests
  run: npm test

# Если тесты упали → exit code 1 → пайплайн останавливается
# Деплой не произойдёт пока тесты не пройдут
```

**Принцип:** сломанный код не должен попасть на продакшн.
