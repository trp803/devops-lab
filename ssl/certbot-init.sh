#!/bin/bash

# ============================================================
# Скрипт получения SSL сертификата от Let's Encrypt через Certbot
# Использование: bash certbot-init.sh yourdomain.com your@email.com
#
# Требования:
#   - Домен должен указывать на IP этого сервера (DNS A запись)
#   - Порт 80 должен быть открыт (Let's Encrypt проверяет по HTTP)
#   - Docker должен быть установлен
# ============================================================

# Аргументы скрипта
DOMAIN=$1    # Домен: example.com
EMAIL=$2     # Email для уведомлений об истечении сертификата

log() {
    echo "[$(date +%H:%M:%S)] $1"
}

# Проверяем что аргументы переданы
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Использование: bash certbot-init.sh <домен> <email>"
    echo "Пример: bash certbot-init.sh example.com admin@example.com"
    exit 1
fi

log "Получаю сертификат для домена: $DOMAIN"

# Создаём папки для Certbot
# /etc/letsencrypt — здесь будут храниться сертификаты
# /var/www/certbot — здесь Certbot размещает файлы для проверки домена
mkdir -p /etc/letsencrypt
mkdir -p /var/www/certbot

# Запускаем Certbot в Docker (не нужно устанавливать Certbot на сервер)
# certonly — только получить сертификат, не настраивать веб-сервер
# --webroot — метод проверки: через файл в папке веб-сервера
# --webroot-path — где размещать файлы проверки
# --email — для уведомлений об истечении
# --agree-tos — принять условия использования Let's Encrypt
# --no-eff-email — не подписываться на рассылку EFF
# -d — для каких доменов получить сертификат
docker run --rm \
    -v /etc/letsencrypt:/etc/letsencrypt \
    -v /var/www/certbot:/var/www/certbot \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN \
    -d www.$DOMAIN     # Получаем сертификат и для www.domain.com

# Проверяем что сертификат создан
if [ $? -eq 0 ]; then
    log "✅ Сертификат получен!"
    log "Путь: /etc/letsencrypt/live/$DOMAIN/"
    log ""
    log "Следующие шаги:"
    log "1. Отредактируй nginx/nginx-ssl.conf — замени yourdomain.com на $DOMAIN"
    log "2. cp nginx/nginx-ssl.conf nginx/nginx.conf"
    log "3. docker compose -f nginx/docker-compose.yml restart nginx"
else
    log "❌ Ошибка получения сертификата!"
    log "Проверь:"
    log "  - DNS запись домена $DOMAIN указывает на этот сервер?"
    log "  - Порт 80 открыт?"
    log "  - Nginx запущен и отдаёт /.well-known/acme-challenge/?"
    exit 1
fi
