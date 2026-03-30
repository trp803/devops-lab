#!/bin/bash

# ============================================================
# cron-logs.sh — просмотр логов cron задач
#
# Использование:
#   bash cron-logs.sh              — показать все логи (последние строки)
#   bash cron-logs.sh backup       — логи только бэкапа
#   bash cron-logs.sh healthcheck  — логи healthcheck
#   bash cron-logs.sh -f           — следить за всеми логами в реальном времени
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs/cron"

# Список всех лог файлов с описаниями
declare -A LOG_FILES
LOG_FILES=(
    ["healthcheck"]="$LOG_DIR/healthcheck.log"
    ["containers"]="$LOG_DIR/containers.log"
    ["backup"]="$LOG_DIR/backup.log"
    ["cleanup"]="$LOG_DIR/cleanup.log"
    ["update"]="$LOG_DIR/update.log"
    ["ssl-renew"]="$LOG_DIR/ssl-renew.log"
)

# ─────────────────────────────────────────
# Функция: показать статус одного лога
# $1 — имя задачи
# $2 — путь к файлу
# ─────────────────────────────────────────
show_log_summary() {
    local name="$1"
    local file="$2"

    echo -e "\n${CYAN}${BOLD}━━━ $name ━━━${RESET}"

    # Проверяем что файл существует и не пуст
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}  Лог не найден — задача ещё не запускалась${RESET}"
        return
    fi

    if [ ! -s "$file" ]; then
        echo -e "${YELLOW}  Файл пуст${RESET}"
        return
    fi

    # Размер файла и дата последней записи
    local size=$(du -sh "$file" | cut -f1)
    # stat -c %y — дата последнего изменения файла
    local last_modified=$(stat -c "%y" "$file" | cut -d. -f1)
    local lines=$(wc -l < "$file")

    echo -e "  Файл: $file"
    echo -e "  Размер: ${size}, строк: ${lines}, последнее изменение: ${last_modified}"

    # Проверяем есть ли ошибки в последних запусках
    local errors=$(grep -c -i "error\|fail\|❌\|ERR" "$file" 2>/dev/null || echo 0)
    if [ "$errors" -gt 0 ]; then
        echo -e "  ${RED}Найдено ошибок: $errors${RESET}"
    else
        echo -e "  ${GREEN}Ошибок не найдено${RESET}"
    fi

    echo ""
    echo -e "${CYAN}  Последние 10 строк:${RESET}"
    # tail -n 10 — последние 10 строк
    # sed — добавляем отступ для читаемости
    tail -n 10 "$file" | sed 's/^/  /'
}

# ─────────────────────────────────────────
# Функция: следить за всеми логами сразу
# ─────────────────────────────────────────
follow_all_logs() {
    echo -e "${CYAN}${BOLD}Слежу за логами (Ctrl+C для выхода)...${RESET}\n"

    # Собираем пути всех существующих логов
    local log_paths=()
    for name in "${!LOG_FILES[@]}"; do
        local file="${LOG_FILES[$name]}"
        if [ -f "$file" ]; then
            log_paths+=("$file")
        fi
    done

    if [ ${#log_paths[@]} -eq 0 ]; then
        echo -e "${YELLOW}Нет лог файлов — запусти: bash cron-setup.sh${RESET}"
        exit 1
    fi

    # tail -f на несколько файлов сразу — выводит имя файла перед каждой строкой
    tail -f "${log_paths[@]}"
}

# ─────────────────────────────────────────
# Функция: статус cron задач
# ─────────────────────────────────────────
show_cron_status() {
    echo -e "\n${CYAN}${BOLD}Расписание cron задач:${RESET}"
    echo ""

    # Парсим crontab и показываем расписание красиво
    crontab -l 2>/dev/null | grep "devops-lab-cron" | while read -r line; do
        # Извлекаем описание из комментария (после маркера)
        local desc=$(echo "$line" | sed 's/# devops-lab-cron //')
        echo -e "  ${GREEN}●${RESET} $desc"
    done

    if [ $(crontab -l 2>/dev/null | grep -c "devops-lab-cron") -eq 0 ]; then
        echo -e "  ${YELLOW}Cron задачи не установлены. Запусти: bash cron-setup.sh${RESET}"
    fi

    echo ""
    echo -e "${CYAN}${BOLD}Следующие запуски:${RESET}"
    echo "  Healthcheck:     каждые 5 минут"
    echo "  Контейнеры:      каждый час (в :00)"
    echo "  Бэкап:           ежедневно в 02:00"
    echo "  Очистка Docker:  воскресенье в 03:00"
    echo "  Обновление:      воскресенье в 04:00"
    echo "  Ротация логов:   воскресенье в 05:00"
    echo "  SSL сертификат:  1-е число месяца в 03:30"
}

# ─────────────────────────────────────────
# ГЛАВНАЯ ЛОГИКА
# ─────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║        Cron Logs — DevOps Lab        ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}"

# Создаём папку если нет
mkdir -p "$LOG_DIR"

case "$1" in

    "-f"|"--follow")
        # Следить за всеми логами в реальном времени
        follow_all_logs
        ;;

    "status")
        # Показать расписание и статус
        show_cron_status
        ;;

    "")
        # По умолчанию — показать сводку по всем логам
        show_cron_status
        echo ""
        echo -e "${CYAN}${BOLD}Логи задач:${RESET}"

        # Перебираем все задачи в фиксированном порядке
        for name in healthcheck containers backup cleanup update ssl-renew; do
            show_log_summary "$name" "${LOG_FILES[$name]}"
        done

        echo ""
        echo -e "${CYAN}Подсказка:${RESET}"
        echo "  bash cron-logs.sh backup    — только логи бэкапа"
        echo "  bash cron-logs.sh -f        — следить в реальном времени"
        ;;

    *)
        # Конкретная задача
        local_name="$1"
        local_file="${LOG_FILES[$local_name]}"

        if [ -z "$local_file" ]; then
            echo -e "${RED}Неизвестная задача: $1${RESET}"
            echo "Доступные: ${!LOG_FILES[@]}"
            exit 1
        fi

        show_log_summary "$local_name" "$local_file"

        # Если передан -f — переходим в режим слежения
        if [ "$2" = "-f" ]; then
            echo -e "\n${CYAN}Слежу за $local_file (Ctrl+C для выхода)...${RESET}\n"
            tail -f "$local_file"
        fi
        ;;
esac

echo ""
