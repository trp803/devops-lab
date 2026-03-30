# CI/CD — непрерывная интеграция и доставка

## Что такое CI/CD

**CI (Continuous Integration)** — непрерывная интеграция. Каждый раз когда разработчик пушит код, автоматически запускаются тесты и сборка. Цель: быстро найти ошибки.

**CD (Continuous Delivery/Deployment)** — непрерывная доставка/деплой. После успешного CI — автоматически доставляем приложение на сервер.

**Без CI/CD:**
```
Разработчик пишет код → вручную тестирует → вручную деплоит → что-то сломалось
```

**С CI/CD:**
```
Push в git → автоматические тесты → сканирование безопасности → сборка → деплой → уведомление
```

---

## GitHub Actions

GitHub Actions — платформа CI/CD встроенная в GitHub. Конфигурация описывается в YAML файлах в папке `.github/workflows/`.

### Основные понятия

```
Workflow (Пайплайн)
└── Job (Джоб) — выполняется на отдельной VM
    └── Step (Шаг) — одна команда или Action
```

**Workflow** — весь пайплайн, описан в одном `.yml` файле.

**Job** — группа шагов, выполняется на отдельной виртуальной машине (`ubuntu-latest`, `windows-latest`, `macos-latest`). Джобы по умолчанию выполняются параллельно, если не указаны зависимости через `needs`.

**Step** — один шаг в джобе. Может быть:
- командой (`run: npm test`)
- готовым Action (`uses: actions/checkout@v3`)

**Action** — переиспользуемый модуль. `actions/checkout@v3` — это Action от GitHub который клонирует репозиторий. `@v3` — версия.

---

## Структура нашего пайплайна

```yaml
on:
  push:
    branches: [main]    # Триггер: push в main
```

### Джоб 1: test

```
ubuntu-latest VM
├── Checkout code      (клонируем репо)
├── Setup Node.js 18   (устанавливаем нужную версию)
├── npm install        (устанавливаем зависимости)
└── npm test           (запускаем Jest тесты)
```

Если тесты упали — пайплайн останавливается, до деплоя не доходит.

### Джоб 2: security (needs: test)

```
ubuntu-latest VM
├── Checkout code
├── docker build       (собираем образ локально)
└── Trivy scan         (сканируем на уязвимости CRITICAL/HIGH)
```

Trivy — сканер безопасности от Aqua Security. Проверяет:
- Уязвимости в OS пакетах (Alpine apk)
- Уязвимости в npm зависимостях
- Известные CVE (Common Vulnerabilities and Exposures)

Если найдены CRITICAL или HIGH уязвимости — пайплайн падает.

### Джоб 3: build-push (needs: security)

```
ubuntu-latest VM
├── Checkout code
├── Генерация версии   (SHA первые 8 символов хэша коммита)
├── Login Docker Hub   (авторизация через токен)
└── Build + Push       (собрать и опубликовать образ)
    ├── myapp:a1b2c3d4  (тег с версией)
    └── myapp:latest    (тег latest)
```

**Версионирование:** каждый деплой получает уникальный тег = первые 8 символов git SHA. Это позволяет откатиться на любую предыдущую версию.

### Джоб 4: deploy (needs: build-push)

```
ubuntu-latest VM
├── Telegram: деплой начался
├── SSH на сервер:
│   ├── git pull
│   ├── docker pull <образ с Hub>
│   ├── bash deploy.sh (остановить старый, запустить новый)
│   └── echo SHA > current_version.txt
├── Telegram: успех ✅
└── Telegram: провал ❌ (если что-то упало)
```

---

## Секреты GitHub

Пароли и ключи нельзя хранить в коде! GitHub предоставляет зашифрованное хранилище **Secrets**.

```
GitHub репо → Settings → Secrets and variables → Actions
```

В коде используются как: `${{ secrets.MY_SECRET }}`

Secrets зашифрованы и видны только в пайплайне — даже в логах они скрываются (`***`).

---

## Как работает SSH деплой

```
GitHub Actions VM
    │
    │ SSH (приватный ключ из secrets)
    ▼
Ваш сервер
    └── Выполняет команды из script:
        ├── git pull
        ├── docker pull
        └── bash deploy.sh
```

На сервере должен быть добавлен **публичный** SSH ключ в `~/.ssh/authorized_keys`.
В секрет `SERVER_SSH_KEY` кладётся **приватный** ключ.

---

## Переменные окружения в GitHub Actions

```yaml
env:
  IMAGE_NAME: myapp    # Глобальная — доступна во всех джобах

jobs:
  build:
    env:
      STAGE: prod      # Локальная — только в этом джобе

    steps:
      - run: echo $IMAGE_NAME   # Глобальная переменная
      - run: echo $STAGE        # Локальная переменная
```

**Контекстные переменные** (встроенные в GitHub):

| Переменная | Значение |
|---|---|
| `GITHUB_SHA` | Полный хэш коммита |
| `github.actor` | Кто сделал push |
| `github.repository` | owner/repo |
| `github.event.head_commit.message` | Текст коммита |

---

## Условные шаги

```yaml
- name: Notify success
  if: success()    # Только если всё прошло хорошо

- name: Notify failure
  if: failure()    # Только если что-то упало

- name: Always
  if: always()     # Всегда (даже если пайплайн упал)
```

---

## Outputs между шагами

```yaml
- name: Set version
  id: version                          # Даём шагу ID
  run: echo "SHA=${GITHUB_SHA::8}" >> $GITHUB_OUTPUT   # Записываем output

- name: Use version
  run: echo ${{ steps.version.outputs.SHA }}   # Читаем по ID шага
```

`$GITHUB_OUTPUT` — специальный файл в который пишем переменные, GitHub Actions их читает и делает доступными.

---

## dev vs prod пайплайн

В проекте два пайплайна:

| Файл | Ветка | Назначение |
|---|---|---|
| `deploy.yml` | `main` | PROD — полный пайплайн с тестами, Trivy, Docker Hub |
| `deploy-dev.yml` | `dev` | DEV — быстрый деплой для разработки |
