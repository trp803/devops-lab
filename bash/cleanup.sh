#!/bin/bash

# ============================================================
# cleanup.sh — умная очистка Docker ресурсов
# Удаляет мусор который накапливается со временем:
#   - остановленные контейнеры
#   - образы без тега (dangling images)
#   - неиспользуемые тома (volumes)
#   - кеш сборки (build cache)
#
# Использование:
#   bash cleanup.sh          — мягкая очистка (безопасно)
#   bash cleanup.sh --full   — полная очистка (удалит ВСЕ неиспользуемые ресурсы)
# ============================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

log()  { echo -e "${GREEN}[$(date +%H:%M:%S)]${RESET} $1"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${RESET}  $1"; }
info() { echo -e "${CYAN}[$(date +%H:%M:%S)]${RESET} $1"; }

# Функция: показать сколько места занято до и после очистки
show_disk_usage() {
    # df -h / — использование корневого раздела
    # awk 'NR==2 {print $4}' — вторая строка, четвёртое поле (свободно)
    df -h / | awk 'NR==2 {print "  Свободно на диске: " $4 " из " $2}'
}

# Функция: размер Docker в системе
show_docker_usage() {
    # docker system df — статистика использования Docker
    docker system df 2>/dev/null || echo "  Docker не доступен"
}

echo ""
echo -e "${CYAN}╔══════════════════════════════════╗${RESET}"
echo -e "${CYAN}║      Docker Cleanup Script       ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════╝${RESET}"
echo ""

# Показываем состояние ДО очистки
info "Состояние ДО очистки:"
show_disk_usage
echo ""
show_docker_usage
echo ""

# ─────────────────────────────────────────
# РЕЖИМ: --full — полная очистка
# ─────────────────────────────────────────
if [ "$1" = "--full" ]; then
    warn "ПОЛНАЯ ОЧИСТКА — будут удалены ВСЕ неиспользуемые ресурсы"
    warn "Данные запущенных контейнеров сохранятся"
    echo ""

    # Подтверждение — читаем ввод пользователя
    read -p "Продолжить? [y/N]: " confirm
    # -n 1 — читать один символ
    # ${confirm,,} — перевод в нижний регистр (bash 4+)
    if [ "${confirm,,}" != "y" ]; then
        echo "Отменено."
        exit 0
    fi
    echo ""

    log "Запускаю полную очистку..."

    # docker system prune — удалить ВСЁ неиспользуемое:
    # остановленные контейнеры, все неиспользуемые образы,
    # неиспользуемые сети, build cache
    # -a = all (включая образы без запущенных контейнеров)
    # -f = force (без подтверждения, мы уже спросили выше)
    # --volumes = удалить и тома (ОСТОРОЖНО: потеря данных БД!)
    docker system prune -af --volumes
    log "✅ Полная очистка завершена"

# ─────────────────────────────────────────
# РЕЖИМ: мягкая очистка (по умолчанию)
# ─────────────────────────────────────────
else
    log "Запускаю мягкую очистку (запущенные сервисы не затронуты)..."
    echo ""

    # ШАГ 1: Остановленные контейнеры
    # Контейнеры в статусе Exited, Created — занимают место, но не работают
    STOPPED=$(docker ps -a --filter "status=exited" --filter "status=created" -q | wc -l)
    if [ "$STOPPED" -gt 0 ]; then
        log "Удаляю $STOPPED остановленных контейнеров..."
        # container prune — удалить все остановленные контейнеры
        docker container prune -f
        log "✅ Контейнеры очищены"
    else
        info "Остановленных контейнеров нет — пропускаю"
    fi

    # ШАГ 2: Dangling images (образы без тега)
    # Появляются после пересборки — старый образ теряет тег и становится <none>:<none>
    DANGLING=$(docker images -f "dangling=true" -q | wc -l)
    if [ "$DANGLING" -gt 0 ]; then
        log "Удаляю $DANGLING dangling образов..."
        # image prune — удалить только dangling образы (без -a)
        docker image prune -f
        log "✅ Dangling образы удалены"
    else
        info "Dangling образов нет — пропускаю"
    fi

    # ШАГ 3: Неиспользуемые тома
    # Тома без привязанных контейнеров — обычно мусор от старых compose стеков
    # ОСТОРОЖНО: проверяем что тома не используются перед удалением
    UNUSED_VOLUMES=$(docker volume ls -f "dangling=true" -q | wc -l)
    if [ "$UNUSED_VOLUMES" -gt 0 ]; then
        warn "Найдено $UNUSED_VOLUMES неиспользуемых томов:"
        # Показываем список чтобы пользователь мог проверить
        docker volume ls -f "dangling=true"
        echo ""
        read -p "Удалить неиспользуемые тома? [y/N]: " confirm_volumes
        if [ "${confirm_volumes,,}" = "y" ]; then
            docker volume prune -f
            log "✅ Неиспользуемые тома удалены"
        else
            info "Тома пропущены"
        fi
    else
        info "Неиспользуемых томов нет — пропускаю"
    fi

    # ШАГ 4: Build cache
    # Docker кеширует слои при сборке образов — кеш может занимать гигабайты
    CACHE_SIZE=$(docker system df --format '{{.BuildCacheSize}}' 2>/dev/null || echo "0B")
    if [ "$CACHE_SIZE" != "0B" ] && [ -n "$CACHE_SIZE" ]; then
        log "Очищаю build cache ($CACHE_SIZE)..."
        # builder prune — только build cache, не трогает образы и контейнеры
        docker builder prune -f
        log "✅ Build cache очищен"
    else
        info "Build cache пуст — пропускаю"
    fi

    # ШАГ 5: Неиспользуемые сети
    # Docker создаёт сети для compose стеков — после удаления стека сети могут остаться
    docker network prune -f > /dev/null 2>&1
    log "✅ Неиспользуемые сети очищены"
fi

# ─────────────────────────────────────────
# Итог
# ─────────────────────────────────────────
echo ""
info "Состояние ПОСЛЕ очистки:"
show_disk_usage
echo ""
show_docker_usage
echo ""
log "🧹 Очистка завершена"
