#!/bin/bash

# ============================================================
# update.sh — обновление Docker образов и перезапуск сервисов
# Скачивает последние версии образов и перезапускает контейнеры
# с нулевым временем простоя (по одному контейнеру)
#
# Использование:
#   bash update.sh                  — обновить все известные стеки
#   bash update.sh monitoring       — обновить только мониторинг
#   bash update.sh nginx            — обновить только nginx + nodeapp
# ============================================================

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

log()     { echo -e "${GREEN}[$(date +%H:%M:%S)]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${RESET}  $1"; }
error()   { echo -e "${RED}[$(date +%H:%M:%S)] ✗${RESET}  $1"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${RESET}"; }

# Корневая папка проекта (абсолютный путь)
# dirname $0 — папка где лежит скрипт (bash/)
# .. — поднимаемся в корень проекта
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ─────────────────────────────────────────
# Функция: обновить один docker-compose стек
# Аргумент $1 — путь к docker-compose.yml
# ─────────────────────────────────────────
update_stack() {
    local compose_file="$1"   # local — переменная видна только внутри функции
    local stack_name="$2"     # Название стека для логов

    # Проверяем что файл существует
    if [ ! -f "$compose_file" ]; then
        warn "Файл $compose_file не найден — пропускаю"
        return 0
    fi

    section "Обновляю: $stack_name"

    # Шаг 1: Скачать обновлённые образы
    # docker compose pull — скачивает только если версия изменилась
    # Сравнивает digest образа на Hub с локальным — если совпадают, не скачивает
    log "Скачиваю новые образы..."
    docker compose -f "$compose_file" pull
    local pull_status=$?   # Сохраняем код возврата

    if [ $pull_status -ne 0 ]; then
        error "Ошибка скачивания образов для $stack_name"
        return 1
    fi

    # Шаг 2: Перезапустить сервисы с новыми образами
    # up -d --remove-orphans:
    #   -d = в фоне
    #   --remove-orphans = удалить контейнеры которых нет в compose файле
    #   Docker Compose сам решает какие контейнеры перезапустить (только изменившиеся)
    log "Перезапускаю сервисы..."
    docker compose -f "$compose_file" up -d --remove-orphans

    if [ $? -eq 0 ]; then
        log "✅ $stack_name обновлён"
    else
        error "Ошибка перезапуска $stack_name"
        return 1
    fi
}

# ─────────────────────────────────────────
# Функция: показать изменения в образах
# (какие образы обновились)
# ─────────────────────────────────────────
show_image_updates() {
    section "Последние обновления образов"
    # docker images — список образов
    # --format — форматируем вывод
    # Сортируем по дате создания (новые сверху)
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedSince}}\t{{.Size}}" \
        | head -15   # Показываем только первые 15
}

echo ""
echo -e "${CYAN}╔══════════════════════════════════╗${RESET}"
echo -e "${CYAN}║      Docker Update Script        ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════╝${RESET}"
echo ""

log "Проект: $PROJECT_DIR"
log "Начинаю обновление: $(date)"

ERRORS=0   # Счётчик ошибок

# ─────────────────────────────────────────
# Выбираем что обновлять
# ─────────────────────────────────────────
case "$1" in

    "monitoring")
        # Обновить только мониторинг
        update_stack "$PROJECT_DIR/monitoring/docker-compose.yml" "Monitoring (Prometheus + Grafana + Loki)" || ERRORS=$((ERRORS+1))
        ;;

    "nginx"|"app")
        # Обновить только приложение
        update_stack "$PROJECT_DIR/nginx/docker-compose.yml" "App (Node.js + Nginx)" || ERRORS=$((ERRORS+1))
        ;;

    "mongo")
        update_stack "$PROJECT_DIR/docker/mongodb/docker-compose.yml" "MongoDB + Mongo Express" || ERRORS=$((ERRORS+1))
        ;;

    "wordpress")
        update_stack "$PROJECT_DIR/docker/wordpress/docker-compose.yml" "WordPress + MySQL" || ERRORS=$((ERRORS+1))
        ;;

    "")
        # Без аргумента — обновить всё что запущено
        update_stack "$PROJECT_DIR/nginx/docker-compose.yml" "App (Node.js + Nginx)" || ERRORS=$((ERRORS+1))
        update_stack "$PROJECT_DIR/monitoring/docker-compose.yml" "Monitoring" || ERRORS=$((ERRORS+1))
        update_stack "$PROJECT_DIR/docker/mongodb/docker-compose.yml" "MongoDB" || ERRORS=$((ERRORS+1))
        update_stack "$PROJECT_DIR/docker/wordpress/docker-compose.yml" "WordPress" || ERRORS=$((ERRORS+1))
        ;;

    *)
        error "Неизвестный аргумент: $1"
        echo "Использование: bash update.sh [monitoring|nginx|mongo|wordpress]"
        exit 1
        ;;
esac

# ─────────────────────────────────────────
# Итог
# ─────────────────────────────────────────
show_image_updates

echo ""
if [ "$ERRORS" -eq 0 ]; then
    log "✅ Обновление завершено успешно"
else
    warn "Обновление завершено с $ERRORS ошибками — проверь логи выше"
    exit 1
fi

# После обновления — удаляем старые dangling образы
# (старые версии образов которые больше не используются)
echo ""
log "Очищаю старые образы..."
docker image prune -f > /dev/null 2>&1
log "✅ Готово"
