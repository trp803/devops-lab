#!/bin/bash

# ============================================================
# ports.sh — все занятые порты на сервере с пояснениями
# Показывает: системные порты + Docker порты + кто их занимает
#
# Использование:
#   bash ports.sh          — все занятые порты
#   bash ports.sh docker   — только Docker порты
#   bash ports.sh <номер>  — проверить конкретный порт
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

# ─────────────────────────────────────────
# Функция: объяснить что это за порт
# ─────────────────────────────────────────
explain_port() {
    local port=$1
    case $port in
        # Системные и стандартные порты
        22)    echo "SSH — удалённый доступ к серверу" ;;
        80)    echo "HTTP — веб (Nginx reverse proxy)" ;;
        443)   echo "HTTPS — защищённый веб (SSL/TLS)" ;;
        3000)  echo "Node.js / Grafana (внутренний)" ;;
        # Наш проект
        3001)  echo "Grafana — дашборды мониторинга" ;;
        3100)  echo "Loki — API хранения логов" ;;
        8080)  echo "WordPress — CMS" ;;
        8081)  echo "Mongo Express — UI для MongoDB" ;;
        8082)  echo "cAdvisor — метрики Docker контейнеров" ;;
        8888)  echo "Final App — продакшн приложение" ;;
        9090)  echo "Prometheus — сбор и хранение метрик" ;;
        9100)  echo "Node Exporter — метрики сервера (CPU/RAM/диск)" ;;
        9080)  echo "Promtail — внутренний порт агента логов" ;;
        27017) echo "MongoDB — база данных (NoSQL)" ;;
        # Kubernetes
        6443)  echo "Kubernetes API Server" ;;
        10250) echo "Kubelet API" ;;
        2379)  echo "etcd — база данных кластера Kubernetes" ;;
        # Docker
        2376)  echo "Docker daemon (TLS)" ;;
        5000)  echo "Docker Registry" ;;
        *)     echo "—" ;;  # Неизвестный порт
    esac
}

# ─────────────────────────────────────────
# Функция: порты Docker контейнеров
# ─────────────────────────────────────────
show_docker_ports() {
    echo -e "\n${CYAN}${BOLD}Docker контейнеры:${RESET}"
    echo -e "${CYAN}$(printf '%-20s %-10s %-30s %s' 'КОНТЕЙНЕР' 'ПОРТ' 'СТАТУС' 'ОПИСАНИЕ')${RESET}"
    echo "────────────────────────────────────────────────────────────────────"

    # docker ps — только запущенные контейнеры
    # --format — JSON формат для удобного парсинга
    docker ps --format '{{.Names}}|{{.Ports}}|{{.Status}}' 2>/dev/null | while IFS='|' read -r name ports status; do
        if [ -z "$ports" ]; then
            # Контейнер без открытых портов (expose, не ports)
            printf "%-20s %-10s %-30s\n" "$name" "—" "$status"
        else
            # Порты в формате: 0.0.0.0:9090->9090/tcp, 0.0.0.0:3001->3000/tcp
            # Разбиваем по запятой если несколько портов
            echo "$ports" | tr ',' '\n' | while read -r port_mapping; do
                # Извлекаем внешний порт из "0.0.0.0:9090->9090/tcp"
                # sed 's/.*:\([0-9]*\)->.*/\1/' — берём цифры между : и ->
                ext_port=$(echo "$port_mapping" | sed 's/.*:\([0-9]*\)->.*/\1/' | tr -d ' ')
                description=$(explain_port "$ext_port")
                printf "%-20s %-10s %-30s %s\n" "$name" ":$ext_port" "$status" "$description"
            done
        fi
    done

    # Показываем если Docker не запущен или нет контейнеров
    if [ $(docker ps -q 2>/dev/null | wc -l) -eq 0 ]; then
        echo "  Нет запущенных контейнеров"
    fi
}

# ─────────────────────────────────────────
# Функция: системные порты (ss/netstat)
# ─────────────────────────────────────────
show_system_ports() {
    echo -e "\n${CYAN}${BOLD}Системные порты (слушают):${RESET}"
    echo -e "${CYAN}$(printf '%-10s %-25s %-20s %s' 'ПОРТ' 'АДРЕС' 'ПРОЦЕСС' 'ОПИСАНИЕ')${RESET}"
    echo "────────────────────────────────────────────────────────────────────"

    # ss — socket statistics (современная замена netstat)
    # -t = TCP соединения
    # -l = только listening (слушающие) сокеты
    # -n = числовые адреса (без DNS резолюции — быстрее)
    # -p = показать процесс который слушает
    # Требует root для показа процессов (или sudo)
    ss -tlnp 2>/dev/null | grep LISTEN | while read -r state recv_q send_q local_addr peer_addr process; do
        # Извлекаем порт из адреса "0.0.0.0:22" или ":::80"
        port=$(echo "$local_addr" | rev | cut -d: -f1 | rev)
        # Извлекаем имя процесса из поля process
        proc_name=$(echo "$process" | grep -oP 'users:\(\("([^"]+)"' | grep -oP '"[^"]+' | tr -d '"' | head -1)
        [ -z "$proc_name" ] && proc_name="—"
        description=$(explain_port "$port")
        printf "%-10s %-25s %-20s %s\n" ":$port" "$local_addr" "$proc_name" "$description"
    done | sort -t: -k1 -n   # Сортируем по номеру порта
}

# ─────────────────────────────────────────
# Функция: проверить конкретный порт
# ─────────────────────────────────────────
check_port() {
    local port=$1
    echo -e "\n${CYAN}${BOLD}Проверка порта $port:${RESET}"

    # Проверяем занят ли порт через ss
    local listeners=$(ss -tlnp "sport = :$port" 2>/dev/null | grep LISTEN)

    if [ -n "$listeners" ]; then
        echo -e "${RED}● Порт $port ЗАНЯТ${RESET}"
        echo "$listeners"
    else
        echo -e "${GREEN}● Порт $port СВОБОДЕН${RESET}"
    fi

    # Проверяем Docker контейнеры
    local docker_container=$(docker ps --format '{{.Names}}: {{.Ports}}' 2>/dev/null | grep ":$port->")
    if [ -n "$docker_container" ]; then
        echo -e "\n${YELLOW}Docker контейнер:${RESET}"
        echo "$docker_container"
    fi

    echo -e "\n${CYAN}Описание:${RESET} $(explain_port $port)"
}

# ─────────────────────────────────────────
# ГЛАВНАЯ ЛОГИКА
# ─────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════╗${RESET}"
echo -e "${CYAN}║       Порты сервера              ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════╝${RESET}"

case "$1" in
    "docker")
        # Только Docker порты
        show_docker_ports
        ;;

    [0-9]*)
        # Передали число — проверяем конкретный порт
        check_port "$1"
        ;;

    *)
        # По умолчанию — показать всё
        show_docker_ports
        show_system_ports

        echo -e "\n${CYAN}${BOLD}Порты проекта devops-lab:${RESET}"
        echo "  :80    Nginx (HTTP)"
        echo "  :443   Nginx (HTTPS)"
        echo "  :3001  Grafana"
        echo "  :9090  Prometheus"
        echo "  :9100  Node Exporter"
        echo "  :8082  cAdvisor"
        echo "  :3100  Loki"
        echo "  :8080  WordPress"
        echo "  :8081  Mongo Express"
        echo "  :27017 MongoDB"
        ;;
esac

echo ""
