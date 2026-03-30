# Makefile — удобные команды для управления проектом
# Использование: make <команда>
# Пример: make up, make logs, make test
#
# Makefile автоматически находит и запускает нужные команды
# Каждая "цель" (target) — это имя команды после make

# .PHONY — говорим Make что это не файлы а команды
# Без этого Make будет искать файл с таким именем на диске
.PHONY: help up down logs test backup status clean monitoring-up monitoring-down nginx-up nginx-down update cleanup ports cron-setup cron-remove cron-list cron-logs

# ─────────────────────────────────────────
# Переменные
# ─────────────────────────────────────────

# Цвета для красивого вывода в терминале
# \033[0;32m = зелёный, \033[0;33m = жёлтый, \033[0m = сброс цвета
GREEN  = \033[0;32m
YELLOW = \033[0;33m
CYAN   = \033[0;36m
RESET  = \033[0m

# ─────────────────────────────────────────
# HELP — список всех команд
# Запускается по умолчанию если просто написать: make
# ─────────────────────────────────────────

# Первый target в файле = цель по умолчанию
help:
	# @echo — выполнить без вывода самой команды (@ подавляет echo команды)
	@echo ""
	@echo "$(CYAN)╔══════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)║        DevOps Lab — Команды          ║$(RESET)"
	@echo "$(CYAN)╚══════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(GREEN)Приложение:$(RESET)"
	@echo "  make up              — запустить Node.js + Nginx"
	@echo "  make down            — остановить Node.js + Nginx"
	@echo "  make logs            — логи всех сервисов (Ctrl+C для выхода)"
	@echo "  make status          — статус всех контейнеров"
	@echo ""
	@echo "$(GREEN)Мониторинг:$(RESET)"
	@echo "  make monitoring-up   — запустить Prometheus + Grafana + Loki"
	@echo "  make monitoring-down — остановить мониторинг"
	@echo "  make monitoring-logs — логи мониторинга"
	@echo ""
	@echo "$(GREEN)База данных:$(RESET)"
	@echo "  make mongo-up        — запустить MongoDB + Mongo Express"
	@echo "  make mongo-down      — остановить MongoDB"
	@echo "  make wordpress-up    — запустить WordPress + MySQL"
	@echo "  make wordpress-down  — остановить WordPress"
	@echo ""
	@echo "$(GREEN)Разработка:$(RESET)"
	@echo "  make test            — запустить Jest тесты"
	@echo "  make build           — собрать Docker образ nodeapp"
	@echo "  make backup          — создать бэкап проекта"
	@echo "  make health          — проверить состояние сервера"
	@echo "  make info            — информация о сервере"
	@echo "  make ports           — все занятые порты"
	@echo "  make logs-c c=<name> — логи контейнера"
	@echo "  make update          — обновить все Docker образы"
	@echo "  make update-s s=<s>  — обновить один стек"
	@echo "  make cleanup         — мягкая очистка Docker"
	@echo "  make cleanup-full    — полная очистка (с подтверждением)"
	@echo ""
	@echo "$(GREEN)Cron:$(RESET)"
	@echo "  make cron-setup      — установить все cron задачи"
	@echo "  make cron-remove     — удалить cron задачи"
	@echo "  make cron-list       — показать расписание"
	@echo "  make cron-logs       — логи cron задач"
	@echo "  make cron-logs-f     — следить за логами"
	@echo ""
	@echo "$(GREEN)Очистка:$(RESET)"
	@echo "  make clean           — удалить остановленные контейнеры и неиспользуемые образы"
	@echo "  make clean-all       — полная очистка (volumes, сети, образы)"
	@echo ""

# ─────────────────────────────────────────
# ПРИЛОЖЕНИЕ — Node.js + Nginx
# ─────────────────────────────────────────

# Запустить основное приложение
# -d = detached mode (в фоне)
up:
	@echo "$(GREEN)Запускаю Node.js + Nginx...$(RESET)"
	docker compose -f nginx/docker-compose.yml up -d
	@echo "$(GREEN)Готово! Открой: http://localhost$(RESET)"

# Остановить основное приложение
down:
	@echo "$(YELLOW)Останавливаю Node.js + Nginx...$(RESET)"
	docker compose -f nginx/docker-compose.yml down

# Логи в реальном времени
# -f = follow (следить за новыми записями)
logs:
	docker compose -f nginx/docker-compose.yml logs -f

# Статус всех контейнеров проекта
# --format = форматируем вывод: имя, статус, порты
status:
	@echo "$(CYAN)Статус контейнеров:$(RESET)"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker не запущен"

# ─────────────────────────────────────────
# МОНИТОРИНГ — Prometheus + Grafana + Loki
# ─────────────────────────────────────────

monitoring-up:
	@echo "$(GREEN)Запускаю стек мониторинга...$(RESET)"
	@# Проверяем что .env файл существует
	@test -f monitoring/.env || (echo "$(YELLOW)Создай monitoring/.env из .env.example$(RESET)" && cp monitoring/.env.example monitoring/.env)
	docker compose -f monitoring/docker-compose.yml up -d
	@echo "$(GREEN)Grafana:    http://localhost:3001  (admin/admin123)$(RESET)"
	@echo "$(GREEN)Prometheus: http://localhost:9090$(RESET)"

monitoring-down:
	@echo "$(YELLOW)Останавливаю мониторинг...$(RESET)"
	docker compose -f monitoring/docker-compose.yml down

monitoring-logs:
	docker compose -f monitoring/docker-compose.yml logs -f

# ─────────────────────────────────────────
# БАЗЫ ДАННЫХ
# ─────────────────────────────────────────

mongo-up:
	@echo "$(GREEN)Запускаю MongoDB...$(RESET)"
	@test -f docker/mongodb/.env || (echo "$(YELLOW)Скопируй .env.example в .env для MongoDB$(RESET)" && exit 1)
	docker compose -f docker/mongodb/docker-compose.yml up -d
	@echo "$(GREEN)Mongo Express: http://localhost:8081$(RESET)"

mongo-down:
	docker compose -f docker/mongodb/docker-compose.yml down

wordpress-up:
	@echo "$(GREEN)Запускаю WordPress...$(RESET)"
	@test -f docker/wordpress/.env || (echo "$(YELLOW)Скопируй .env.example в .env для WordPress$(RESET)" && exit 1)
	docker compose -f docker/wordpress/docker-compose.yml up -d
	@echo "$(GREEN)WordPress: http://localhost:8080$(RESET)"

wordpress-down:
	docker compose -f docker/wordpress/docker-compose.yml down

# ─────────────────────────────────────────
# РАЗРАБОТКА
# ─────────────────────────────────────────

# Запустить Jest тесты
test:
	@echo "$(CYAN)Запускаю тесты...$(RESET)"
	@# Проверяем что node_modules установлены
	@test -d docker/nodeapp/node_modules || (cd docker/nodeapp && npm install)
	cd docker/nodeapp && npm test
	@echo "$(GREEN)Тесты пройдены!$(RESET)"

# Собрать Docker образ nodeapp
build:
	@echo "$(CYAN)Собираю образ nodeapp...$(RESET)"
	docker build -t nodeapp:latest docker/nodeapp
	@echo "$(GREEN)Образ собран: nodeapp:latest$(RESET)"

# Создать бэкап
backup:
	@echo "$(CYAN)Создаю бэкап...$(RESET)"
	bash bash/backup.sh

# Проверить состояние сервера
health:
	@echo "$(CYAN)Проверяю состояние сервера...$(RESET)"
	bash bash/healthcheck.sh

# Информация о сервере
info:
	bash bash/server-info.sh

# Показать все занятые порты
ports:
	bash bash/ports.sh

# Логи контейнера: make logs-c c=nodeapp
logs-c:
	bash bash/logs.sh $(c)

# Обновить все Docker образы
update:
	@echo "$(CYAN)Обновляю Docker образы...$(RESET)"
	bash bash/update.sh

# Обновить конкретный стек: make update-s s=monitoring
update-s:
	bash bash/update.sh $(s)

# Мягкая очистка Docker
cleanup:
	bash bash/cleanup.sh

# Полная очистка (с подтверждением)
cleanup-full:
	bash bash/cleanup.sh --full

# ─────────────────────────────────────────
# CRON — автоматизация по расписанию
# ─────────────────────────────────────────

# Установить все cron задачи
cron-setup:
	@echo "$(CYAN)Устанавливаю cron задачи...$(RESET)"
	bash bash/cron-setup.sh

# Удалить все cron задачи проекта
cron-remove:
	@echo "$(YELLOW)Удаляю cron задачи...$(RESET)"
	bash bash/cron-setup.sh remove

# Показать текущие cron задачи и расписание
cron-list:
	bash bash/cron-setup.sh list

# Просмотр логов cron задач
cron-logs:
	bash bash/cron-logs.sh

# Следить за логами в реальном времени
cron-logs-f:
	bash bash/cron-logs.sh -f

# ─────────────────────────────────────────
# ЗАПУСТИТЬ ВСЁ СРАЗУ
# ─────────────────────────────────────────

# Запустить всё: приложение + мониторинг
all-up: up monitoring-up
	@echo ""
	@echo "$(GREEN)══════════════════════════════════$(RESET)"
	@echo "$(GREEN)Всё запущено!$(RESET)"
	@echo "$(GREEN)Приложение:  http://localhost$(RESET)"
	@echo "$(GREEN)Grafana:     http://localhost:3001$(RESET)"
	@echo "$(GREEN)Prometheus:  http://localhost:9090$(RESET)"
	@echo "$(GREEN)══════════════════════════════════$(RESET)"

# Остановить всё
all-down: down monitoring-down
	@echo "$(YELLOW)Всё остановлено$(RESET)"

# ─────────────────────────────────────────
# ОЧИСТКА
# ─────────────────────────────────────────

# Мягкая очистка: только остановленные контейнеры и dangling образы
# dangling = образы без тега (обычно остаются после пересборки)
clean:
	@echo "$(YELLOW)Очищаю Docker ресурсы...$(RESET)"
	docker container prune -f   # Удалить остановленные контейнеры
	docker image prune -f       # Удалить dangling образы
	@echo "$(GREEN)Готово$(RESET)"

# Жёсткая очистка: всё включая volumes (ОСТОРОЖНО: удалит данные БД!)
clean-all:
	@echo "$(YELLOW)ВНИМАНИЕ: Будут удалены все данные включая БД!$(RESET)"
	@read -p "Продолжить? [y/N]: " confirm && [ "$$confirm" = "y" ]
	docker system prune -af --volumes
	@echo "$(GREEN)Полная очистка завершена$(RESET)"
