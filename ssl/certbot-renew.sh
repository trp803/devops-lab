#!/bin/bash

# ============================================================
# Скрипт обновления SSL сертификата Let's Encrypt
# Сертификаты Let's Encrypt действительны 90 дней
# Этот скрипт нужно запускать по cron раз в месяц
#
# Добавить в cron: crontab -e
# 0 3 1 * * bash /home/ubuntu/devops-lab/ssl/certbot-renew.sh >> /var/log/certbot-renew.log 2>&1
# ↑ Каждое 1-е число месяца в 3:00 ночи
# ============================================================

log() {
    echo "[$(date +%Y-%m-%d %H:%M:%S)] $1"
}

log "Начинаю обновление сертификата..."

# --renew-before-expiry 30d — обновлять только если до истечения < 30 дней
# Если сертификат ещё действителен — Certbot ничего не делает
docker run --rm \
    -v /etc/letsencrypt:/etc/letsencrypt \
    -v /var/www/certbot:/var/www/certbot \
    certbot/certbot renew \
    --webroot \
    --webroot-path=/var/www/certbot \
    --quiet \                    # Минимальный вывод (только ошибки)
    --renew-before-expiry 30d   # Обновить если < 30 дней до истечения

if [ $? -eq 0 ]; then
    log "✅ Сертификат проверен/обновлён"

    # Перезагружаем Nginx чтобы он подхватил новый сертификат
    # --no-dep — не пересоздавать зависимые контейнеры
    docker compose -f /home/ubuntu/devops-lab/nginx/docker-compose.yml exec nginx nginx -s reload
    log "✅ Nginx перезагружен"
else
    log "❌ Ошибка обновления сертификата!"
    # Здесь можно добавить уведомление в Telegram
    exit 1
fi
