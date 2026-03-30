#!/bin/bash

# ============================================================
# logs.sh — удобный просмотр логов контейнеров
# Обёртка над docker logs с фильтрацией и форматированием
#
# Использование:
#   bash logs.sh                    — список всех контейнеров
#   bash logs.sh nodeapp            — логи конкретного контейнера
#   bash logs.sh nodeapp -f         — следить за логами в реальном времени
#   bash logs.sh nodeapp error      — только строки содержащие "error"
#   bash logs.sh nodeapp error -f   — следить + фильтровать
#   bash logs.sh all                — логи всех контейнеров сразу
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

# ─────────────────────────────────────────
# Функция: показать список контейнеров
# ─────────────────────────────────────────
show_containers() {
    echo -e "\n${CYAN}${BOLD}Запущенные контейнеры:${RESET}"
    echo -e "${CYAN}$(printf '%-25s %-15s %s' 'ИМЯ' 'СТАТУС' 'ЗАПУЩЕН')${RESET}"
    echo "──────────────────────────────────────────────────"

    docker ps --format '{{.Names}}|{{.Status}}|{{.RunningFor}}' 2>/dev/null | while IFS='|' read -r name status running; do
        # Определяем цвет по статусу
        if echo "$status" | grep -q "Up"; then
            color=$GREEN
        else
            color=$RED
        fi
        printf "${color}%-25s${RESET} %-15s %s\n" "$name" "$status" "$running"
    done

    echo ""
    echo -e "${CYAN}Использование:${RESET}"
    echo "  bash logs.sh <имя_контейнера>           — показать логи"
    echo "  bash logs.sh <имя_контейнера> -f        — следить за логами"
    echo "  bash logs.sh <имя_контейнера> <слово>   — фильтровать"
    echo "  bash logs.sh all                        — все контейнеры"
}

# ─────────────────────────────────────────
# Функция: логи одного контейнера
# $1 = имя контейнера
# $2 = фильтр (опционально)
# $3 = -f (опционально)
# ─────────────────────────────────────────
show_logs() {
    local container=$1
    local filter=$2
    local follow=$3

    # Проверяем что контейнер существует
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}Контейнер '$container' не найден${RESET}"
        echo ""
        show_containers
        exit 1
    fi

    # Проверяем запущен ли контейнер
    local status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null)
    if [ "$status" != "running" ]; then
        echo -e "${YELLOW}Контейнер '$container' не запущен (статус: $status)${RESET}"
        echo -e "Показываю последние логи:\n"
    fi

    echo -e "${CYAN}${BOLD}Логи контейнера: $container${RESET}"
    [ -n "$filter" ] && echo -e "${CYAN}Фильтр: '$filter'${RESET}"
    echo "──────────────────────────────────────────────────"

    if [ "$follow" = "-f" ]; then
        # Режим слежения за логами в реальном времени
        # --follow = следить за новыми строками
        # --timestamps = показывать время каждой строки
        # --tail 50 = начать с последних 50 строк
        if [ -n "$filter" ]; then
            # Фильтруем через grep
            # --line-buffered — выводить буфер сразу (без накопления)
            # -i — регистронезависимый поиск
            # --color=always — подсветить найденное слово
            docker logs --follow --timestamps --tail 50 "$container" 2>&1 | grep --line-buffered -i --color=always "$filter"
        else
            docker logs --follow --timestamps --tail 50 "$container" 2>&1
        fi
    else
        # Разовый вывод последних логов
        # --tail 100 — последние 100 строк (не весь лог)
        if [ -n "$filter" ]; then
            docker logs --timestamps --tail 200 "$container" 2>&1 | grep -i --color=always "$filter"
        else
            docker logs --timestamps --tail 100 "$container" 2>&1
        fi
    fi
}

# ─────────────────────────────────────────
# Функция: логи всех контейнеров сразу
# Полезно для отладки взаимодействия сервисов
# ─────────────────────────────────────────
show_all_logs() {
    local follow=$1

    # Получаем список всех запущенных контейнеров
    local containers=$(docker ps --format '{{.Names}}' 2>/dev/null)

    if [ -z "$containers" ]; then
        echo -e "${YELLOW}Нет запущенных контейнеров${RESET}"
        exit 0
    fi

    echo -e "${CYAN}${BOLD}Логи всех контейнеров:${RESET}"
    echo "$(echo "$containers" | tr '\n' ', ')"
    echo "──────────────────────────────────────────────────"

    if [ "$follow" = "-f" ]; then
        # docker compose logs -f для всего проекта — показывает имя контейнера перед каждой строкой
        # Запускаем несколько docker logs параллельно через &
        # Каждая строка помечается именем контейнера
        echo "$containers" | while read -r container; do
            # Добавляем префикс с именем контейнера к каждой строке
            docker logs --follow --tail 10 "$container" 2>&1 | \
                sed "s/^/$(printf '%-15s' "$container") | /" &
            # & = запустить в фоне (параллельно)
        done
        # Ждём Ctrl+C от пользователя
        wait
    else
        echo "$containers" | while read -r container; do
            echo -e "\n${GREEN}=== $container ===${RESET}"
            docker logs --tail 20 "$container" 2>&1
        done
    fi
}

# ─────────────────────────────────────────
# ГЛАВНАЯ ЛОГИКА
# ─────────────────────────────────────────
echo ""

# Парсим аргументы
CONTAINER=$1    # Первый аргумент — имя контейнера или команда
FILTER=""       # Фильтр (опционально)
FOLLOW=""       # Флаг слежения

# Определяем что передали
case "$2" in
    "-f")
        # bash logs.sh nodeapp -f
        FOLLOW="-f"
        ;;
    "")
        # bash logs.sh nodeapp
        ;;
    *)
        # bash logs.sh nodeapp error (и возможно -f)
        FILTER="$2"
        FOLLOW="$3"
        ;;
esac

# Выбираем режим
case "$CONTAINER" in
    "")
        # Без аргументов — список контейнеров
        show_containers
        ;;
    "all")
        # Логи всех контейнеров
        show_all_logs "$2"
        ;;
    *)
        # Логи конкретного контейнера
        show_logs "$CONTAINER" "$FILTER" "$FOLLOW"
        ;;
esac
