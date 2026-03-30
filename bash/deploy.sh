#!/bin/bash

# ================================
# Универсальный скрипт деплоя
# Использование: ./deploy.sh <имя_контейнера> <порт> <имя_образа> <папка_проекта>
# Пример: ./deploy.sh myapp 8080 myimage:v1 /home/ubuntu/myapp
# ================================

# $1, $2, $3, $4 — позиционные аргументы скрипта
# Присваиваем им понятные имена
CONTAINER_NAME=$1   # Имя Docker контейнера
PORT=$2             # Внешний порт на котором будет доступно приложение
IMAGE_NAME=$3       # Имя Docker образа (например myapp:latest)
PROJECT_DIR=$4      # Папка с исходным кодом и Dockerfile

# Функция логирования: выводит сообщение с текущим временем
# $1 внутри функции — первый аргумент переданный в функцию
log() {
    echo "[$(date +%H:%M:%S)] $1"
}

# Проверка аргументов: -z проверяет что строка пустая
# Если хотя бы один аргумент не передан — показываем подсказку и выходим
if [ -z "$CONTAINER_NAME" ] || [ -z "$PORT" ] || [ -z "$IMAGE_NAME" ] || [ -z "$PROJECT_DIR" ]; then
    echo "Использование: ./deploy.sh <имя_контейнера> <порт> <имя_образа> <папка_проекта>"
    exit 1  # exit 1 — завершаем скрипт с кодом ошибки
fi

log "🚀 Начинаю деплой $CONTAINER_NAME на порту $PORT"

# Останавливаем и удаляем старый контейнер если он существует
# docker ps -a — показывает все контейнеры (включая остановленные)
# grep -q — ищет тихо (без вывода), возвращает код: 0 если нашёл, 1 если нет
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    log "Останавливаю старый контейнер $CONTAINER_NAME..."
    docker stop $CONTAINER_NAME   # Отправляет SIGTERM, ждёт 10 секунд, потом SIGKILL
    docker rm $CONTAINER_NAME     # Удаляет контейнер (но не образ)
    log "✅ Старый контейнер удалён"
fi

# Проверяем занят ли нужный порт другим контейнером
# docker ps — только запущенные контейнеры
# grep "0.0.0.0:$PORT" — ищем строку с нужным портом
if docker ps | grep -q "0.0.0.0:$PORT"; then
    log "⚠️ Порт $PORT занят! Освобождаю..."
    # awk '{print $NF}' — берём последнее поле строки (имя контейнера)
    CONTAINER=$(docker ps | grep "0.0.0.0:$PORT" | awk '{print $NF}')
    docker stop $CONTAINER
    docker rm $CONTAINER
    log "✅ Порт $PORT освобождён"
fi

# Собираем новый Docker образ из Dockerfile в PROJECT_DIR
log "Собираю образ $IMAGE_NAME..."
cd $PROJECT_DIR
docker build -t $IMAGE_NAME .  # -t задаёт имя образа, . = текущая директория

# Запускаем новый контейнер
log "Запускаю контейнер $CONTAINER_NAME..."
docker run -d \              # -d = detached mode (в фоне)
    -p $PORT:80 \            # маппинг портов: внешний PORT → внутренний 80
    --name $CONTAINER_NAME \ # задаём имя контейнера
    --restart always \       # всегда перезапускать (даже после reboot сервера)
    $IMAGE_NAME              # образ из которого запускаем

# Проверяем что контейнер действительно запустился
if docker ps | grep -q "$CONTAINER_NAME"; then
    log "✅ $CONTAINER_NAME успешно запущен на порту $PORT"
else
    log "❌ Ошибка запуска $CONTAINER_NAME"
    exit 1  # Завершаем с кодом ошибки — CI/CD увидит что деплой упал
fi
