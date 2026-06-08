#!/bin/bash

# ============================================
# Script de Backup Automatizado - Docker
# ============================================

DATA=$(date +%Y%m%d_%H%M%S)
DIR_BACKUP="$(cd "$(dirname "$0")/../backups" && pwd)"
VOLUME="mysql-prod-data"
CONTAINER="mysql-prod"
DB="escola"
USUARIO="root"
SENHA="senha123"

echo "============================================"
echo " INICIANDO BACKUP - $DATA"
echo "============================================"

# Backup SQL (mysqldump)
echo "[1/2] Gerando backup SQL..."
docker exec $CONTAINER mysqldump -u$USUARIO -p$SENHA $DB > "$DIR_BACKUP/backup-sql-$DATA.sql"
echo "      Arquivo: backup-sql-$DATA.sql"

# Backup do volume (.tar.gz)
echo "[2/2] Gerando backup do volume..."
docker run --rm \
  -v $VOLUME:/data \
  -v $DIR_BACKUP:/backup \
  ubuntu tar czf /backup/backup-volume-$DATA.tar.gz -C /data .
echo "      Arquivo: backup-volume-$DATA.tar.gz"

echo "============================================"
echo " BACKUP CONCLUÍDO COM SUCESSO!"
echo " Local: $DIR_BACKUP"
ls -lh "$DIR_BACKUP"/backup-*$DATA* 2>/dev/null
echo "============================================"
