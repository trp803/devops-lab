#!/bin/bash

# ============================================================
# cron-setup.sh — установка всех cron задач проекта
#
# Что автоматизируем:
#   - каждые 5 мин  → healthcheck (проверка сервера)
#   - каждый час    → проверка Docker контейнеров
#   - каждую ночь   → бэкап проекта
#   - раз в неделю  → обновление Docker образов
#   - раз в неделю  → очистка Docker мусора
#   - раз в месяц   → обновление SSL сертификата
#
# Использование:
#   bash cron-setup.sh          — установить все задачи
#   bash cron-setup.sh remove   — удалить все задачи проекта
#   bash cron-setup.sh list     — показать текущие задачи
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

log()   { echo -e "${GREEN}[$(date +%H:%M:%S)]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[$(date +%H:%M:%S)]${RESET} $1"; }
error() { echo -e "${RED}[$(date +%H:%M:%S)]${RESET} $1"; }
info()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${RESET} $1"; }

# Абсолютный путь к проекту
# Не используем относительные пути — cron запускается без контекста рабочей директории
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASH_DIR="$PROJECT_DIR/bash"
LOG_DIR="$PROJECT_DIR/logs/cron"

# Маркер — по нему находим и удаляем наши задачи из crontab
# Все наши задачи имеют этот комментарий — crontab это обычный текстовый файл
MARKER="# devops-lab-cron"

# ─────────────────────────────────────────
# Создаём папку для логов
# ─────────────────────────────────────────
mkdir -p "$LOG_DIR"
log "Логи cron задач: $LOG_DIR"

# ─────────────────────────────────────────
# Функция: показать текущий crontab
# ─────────────────────────────────────────
show_crontab() {
    info "Текущие cron задачи проекта:"
    echo ""
    # crontab -l — список задач текущего пользователя
    # grep MARKER — показываем только наши задачи
    crontab -l 2>/dev/null | grep -A1 "$MARKER" || echo "  Задач нет"
    echo ""
}

# ─────────────────────────────────────────
# Функция: удалить все задачи проекта
# ─────────────────────────────────────────
remove_crontab() {
    warn "Удаляю все cron задачи devops-lab..."

    # Читаем текущий crontab, убираем строки с нашим маркером и следующие строки
    # grep -v MARKER — исключить строки с маркером
    local current=$(crontab -l 2>/dev/null | grep -v "$MARKER")

    # Устанавливаем обновлённый crontab
    echo "$current" | crontab -
    log "✅ Задачи удалены"
}

# ─────────────────────────────────────────
# Функция: добавить задачу в crontab
# $1 — расписание (5 полей cron)
# $2 — команда
# $3 — описание (для комментария)
# ─────────────────────────────────────────
add_cron_job() {
    local schedule="$1"
    local command="$2"
    local description="$3"

    # Читаем текущий crontab (2>/dev/null — не ругаться если пуст)
    local current_crontab
    current_crontab=$(crontab -l 2>/dev/null)

    # Проверяем что такой задачи ещё нет (по команде)
    if echo "$current_crontab" | grep -qF "$command"; then
        warn "Задача уже существует: $description"
        return 0
    fi

    # Добавляем задачу: комментарий + строка cron
    # printf добавляет перенос строки в конце — crontab требует завершающий newline
    {
        echo "$current_crontab"
        echo "$MARKER $description"
        echo "$schedule $command"
    } | crontab -

    log "✅ Добавлено: $description ($schedule)"
}

# ─────────────────────────────────────────
# ГЛАВНАЯ ЛОГИКА
# ─────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║      Cron Setup — DevOps Lab         ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}"
echo ""

case "$1" in

    "remove")
        remove_crontab
        exit 0
        ;;

    "list")
        show_crontab
        exit 0
        ;;

    "")
        # Установка всех задач
        log "Устанавливаю cron задачи..."
        log "Проект: $PROJECT_DIR"
        echo ""

        # ── Задача 1: Healthcheck каждые 5 минут ──
        # Формат cron: минута час день_месяца месяц день_недели
        # */5 = каждые 5 минут
        # >> = дописывать в файл (не перезаписывать)
        # 2>&1 = stderr тоже пишем в файл
        add_cron_job \
            "*/5 * * * *" \
            "bash $BASH_DIR/healthcheck.sh >> $LOG_DIR/healthcheck.log 2>&1" \
            "Healthcheck каждые 5 минут"

        # ── Задача 2: Проверка Docker контейнеров каждый час ──
        # 0 * * * * = в 0 минут каждого часа (00:00, 01:00, 02:00...)
        # Если контейнер упал — записываем в лог (Grafana алерт уже отправит в Telegram)
        add_cron_job \
            "0 * * * *" \
            "docker ps --format 'table {{.Names}}\t{{.Status}}' >> $LOG_DIR/containers.log 2>&1" \
            "Статус контейнеров каждый час"

        # ── Задача 3: Бэкап каждую ночь в 02:00 ──
        # 0 2 * * * = в 02:00 каждый день
        # Выбираем 02:00 — минимальная нагрузка на сервер в это время
        add_cron_job \
            "0 2 * * *" \
            "bash $BASH_DIR/backup.sh >> $LOG_DIR/backup.log 2>&1" \
            "Бэкап каждую ночь в 02:00"

        # ── Задача 4: Очистка Docker каждое воскресенье в 03:00 ──
        # 0 3 * * 0 = в 03:00 в воскресенье (0 = воскресенье, 6 = суббота)
        # Запускаем ПОСЛЕ бэкапа (02:00) — порядок важен
        add_cron_job \
            "0 3 * * 0" \
            "bash $BASH_DIR/cleanup.sh >> $LOG_DIR/cleanup.log 2>&1" \
            "Очистка Docker каждое воскресенье в 03:00"

        # ── Задача 5: Обновление Docker образов каждое воскресенье в 04:00 ──
        # 0 4 * * 0 = в 04:00 в воскресенье
        # После очистки — меньше шансов конфликта с dangling образами
        add_cron_job \
            "0 4 * * 0" \
            "bash $BASH_DIR/update.sh >> $LOG_DIR/update.log 2>&1" \
            "Обновление Docker образов каждое воскресенье в 04:00"

        # ── Задача 6: Обновление SSL сертификата 1-го числа в 03:30 ──
        # 30 3 1 * * = в 03:30 первого числа каждого месяца
        # Certbot обновляет только если до истечения < 30 дней — безопасно запускать часто
        SSL_SCRIPT="$PROJECT_DIR/ssl/certbot-renew.sh"
        if [ -f "$SSL_SCRIPT" ]; then
            add_cron_job \
                "30 3 1 * *" \
                "bash $SSL_SCRIPT >> $LOG_DIR/ssl-renew.log 2>&1" \
                "Обновление SSL сертификата 1-го числа в 03:30"
        else
            warn "ssl/certbot-renew.sh не найден — пропускаю SSL задачу"
        fi

        # ── Задача 7: Ротация логов cron раз в неделю ──
        # 0 5 * * 0 = в 05:00 в воскресенье
        # Обрезаем логи до последних 1000 строк чтобы они не разрастались
        add_cron_job \
            "0 5 * * 0" \
            "for f in $LOG_DIR/*.log; do tail -1000 \"\$f\" > \"\$f.tmp\" && mv \"\$f.tmp\" \"\$f\"; done" \
            "Ротация cron логов каждое воскресенье в 05:00"

        echo ""
        log "✅ Все задачи установлены!"
        echo ""
        show_crontab

        info "Управление:"
        info "  Просмотр задач:   bash cron-setup.sh list"
        info "  Удалить задачи:   bash cron-setup.sh remove"
        info "  Просмотр логов:   bash cron-logs.sh"
        info "  Редактировать:    crontab -e"
        ;;

    *)
        error "Неизвестный аргумент: $1"
        echo "Использование: bash cron-setup.sh [remove|list]"
        exit 1
        ;;
esac
