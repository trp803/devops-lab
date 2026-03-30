#!/bin/bash

# ================================
# Скрипт автоматического бэкапа
# ================================

# Настройки
SOURCE_DIR="/home/ubuntu/devops-lab"
BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_NAME="backup_$DATE.tar.gz"

# Функция логирования
log() {
    echo "[$(date +%H:%M:%S)] $1"
}

# Создай папку для бэкапов если нет
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    log "Создана папка для бэкапов: $BACKUP_DIR"
fi

# Делаем бэкап
log "Начинаю бэкап папки: $SOURCE_DIR"

tar -czf "$BACKUP_DIR/$BACKUP_NAME" "$SOURCE_DIR" 2>/dev/null

# Проверяем успешно ли создался бэкап
if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
    log "✅ Бэкап успешно создан: $BACKUP_NAME (размер: $SIZE)"
else
    log "❌ Ошибка при создании бэкапа!"
    exit 1
fi

# Удаляем бэкапы старше 7 дней
log "Удаляю старые бэкапы (старше 7 дней)..."
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +7 -delete

# Показываем все бэкапы
log "Текущие бэкапы:"
ls -lh "$BACKUP_DIR"
