[README.md](https://github.com/user-attachments/files/28691446/README.md)
#  Infraestrutura com Persistência de Dados em Docker

**Disciplina:** Infraestrutura e Serviços de TI  
**Professor:** DANIEL OHATA  
**Aluno:** Kaike Figueiredo  
**Repositório:** infra-persistencia-docker  

---

## 1. Introdução

### Containers Efêmeros e a Necessidade de Persistência

Containers Docker são, por natureza, **efêmeros**: quando um container é removido, todos os dados armazenados internamente são perdidos junto com ele. Esse comportamento é intencional e faz parte da filosofia de infraestrutura imutável — cada container pode ser destruído e recriado a qualquer momento sem efeitos colaterais.

No entanto, aplicações reais — como bancos de dados, sistemas de arquivos, logs e configurações — precisam que seus dados **sobrevivam ao ciclo de vida dos containers**. É nesse contexto que surgem os mecanismos de persistência de dados do Docker.

### Mecanismos de Persistência

O Docker oferece três formas principais de persistir dados:

| Mecanismo | Descrição |
|-----------|-----------|
| **Named Volumes** | Volumes gerenciados pelo Docker, armazenados em `/var/lib/docker/volumes/` |
| **Bind Mounts** | Mapeamento direto de um diretório do host para dentro do container |
| **tmpfs Mounts** | Armazenamento temporário em memória RAM (não persiste) |

### Objetivo da Atividade

Esta atividade tem como objetivo implementar e validar na prática os mecanismos de persistência de dados em ambientes containerizados, abordando volumes nomeados, backup e restauração, Bind Mounts, compartilhamento entre containers e automação de backup via script Bash.

---

## 2. Ambiente Utilizado

| Item | Versão / Detalhe |
|------|-----------------|
| Sistema Operacional | Ubuntu 24.04 LTS (Desktop) |
| Virtualização | VirtualBox |
| Docker Engine | 29.5.3, build d1c06ef |
| Docker Compose | v5.1.4 |
| Git | 2.53.0 |
| Acesso remoto | SSH via PowerShell (Windows) |
| Hardware | VM com 2 vCPUs, 4GB RAM |

### Verificação do Ambiente

```bash
docker --version
# Docker version 29.5.3, build d1c06ef

docker compose version
# Docker Compose version v5.1.4

git --version
# git version 2.53.0

docker run hello-world
# Hello from Docker!
```

---

## 3. Desenvolvimento da Atividade

---

### CENÁRIO 1 — Persistência de Dados com MySQL e Named Volume

**Objetivo:** Validar que dados armazenados em um volume nomeado sobrevivem à remoção do container.

#### Conceito Técnico

Um **Named Volume** é gerenciado inteiramente pelo Docker. Ele existe independentemente do ciclo de vida de qualquer container — mesmo que o container seja removido com `docker rm -f`, o volume e seus dados permanecem intactos em `/var/lib/docker/volumes/<nome>/`.

#### Comandos Executados

**1. Criação do volume nomeado:**
```bash
docker volume create mysql-prod-data
docker volume ls
```

**2. Criação do container MySQL com volume persistente:**
```bash
docker run -d \
  --name mysql-prod \
  -e MYSQL_ROOT_PASSWORD=senha123 \
  -e MYSQL_DATABASE=escola \
  -v mysql-prod-data:/var/lib/mysql \
  mysql:8.0
```

A flag `-v mysql-prod-data:/var/lib/mysql` mapeia o volume `mysql-prod-data` para o diretório interno do MySQL onde ele armazena seus dados.

**3. Criação da tabela e inserção de registros:**
```bash
docker exec -it mysql-prod mysql -uroot -psenha123 escola
```

```sql
CREATE TABLE usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100),
  email VARCHAR(100),
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO usuarios (nome, email) VALUES
  ('Ana Silva', 'ana@email.com'),
  ('Bruno Costa', 'bruno@email.com'),
  ('Carla Souza', 'carla@email.com');

SELECT * FROM usuarios;
```

**Resultado:**
```
+----+-------------+------------------+---------------------+
| id | nome        | email            | criado_em           |
+----+-------------+------------------+---------------------+
|  1 | Ana Silva   | ana@email.com    | 2026-06-08 01:49:50 |
|  2 | Bruno Costa | bruno@email.com  | 2026-06-08 01:49:50 |
|  3 | Carla Souza | carla@email.com  | 2026-06-08 01:49:50 |
+----+-------------+------------------+---------------------+
```

**4. Validação da persistência:**
```bash
# Remove o container
docker rm -f mysql-prod

# Recria o container usando o mesmo volume
docker run -d \
  --name mysql-prod \
  -e MYSQL_ROOT_PASSWORD=senha123 \
  -e MYSQL_DATABASE=escola \
  -v mysql-prod-data:/var/lib/mysql \
  mysql:8.0

# Valida os dados após recriar o container
docker exec -it mysql-prod mysql -uroot -psenha123 escola -e "SELECT * FROM usuarios;"
```

**Resultado:** Os 3 registros foram encontrados intactos após a remoção e recriação do container, comprovando a persistência via Named Volume.

#### Análise Técnica

O volume `mysql-prod-data` funciona como um disco externo acoplado ao container. Quando o container é removido, o volume permanece no host. Ao recriar o container com a mesma flag `-v`, o Docker reanexa o volume com todos os dados preservados. Isso demonstra a separação entre **estado do container** (efêmero) e **estado dos dados** (persistente).

---

### CENÁRIO 2 — Backup e Restauração de Volume

**Objetivo:** Implementar estratégias de backup e recuperação de dados de volumes Docker.

#### Conceito Técnico

Existem duas estratégias complementares de backup em ambientes Docker:

- **mysqldump:** Exporta o banco de dados em formato SQL legível, portátil e versionável.
- **Backup do volume (.tar.gz):** Copia os arquivos binários do volume completo, útil para restauração rápida em ambiente idêntico.

#### Comandos Executados

**1. Backup SQL via mysqldump:**
```bash
docker exec mysql-prod mysqldump -uroot -psenha123 escola > backups/escola-backup.sql
```

**2. Backup completo do volume em .tar.gz:**
```bash
docker run --rm \
  -v mysql-prod-data:/data \
  -v $(pwd)/backups:/backup \
  ubuntu tar czf /backup/mysql-prod-data.tar.gz -C /data .
```

Este comando sobe um container Ubuntu temporário (`--rm`), monta o volume de dados e o diretório de backup, e cria um arquivo compactado com todo o conteúdo do volume.

**3. Simulação de perda total de dados:**
```bash
docker rm -f mysql-prod
docker volume rm mysql-prod-data
```

**4. Restauração completa:**
```bash
# Recria o volume
docker volume create mysql-prod-data

# Restaura os arquivos do volume a partir do .tar.gz
docker run --rm \
  -v mysql-prod-data:/data \
  -v $(pwd)/backups:/backup \
  ubuntu tar xzf /backup/mysql-prod-data.tar.gz -C /data

# Sobe o container novamente
docker run -d \
  --name mysql-prod \
  -e MYSQL_ROOT_PASSWORD=senha123 \
  -e MYSQL_DATABASE=escola \
  -v mysql-prod-data:/var/lib/mysql \
  mysql:8.0

# Valida os dados restaurados
docker exec -it mysql-prod mysql -uroot -psenha123 escola -e "SELECT * FROM usuarios;"
```

**Resultado:** Os 3 registros foram recuperados com sucesso após simulação de perda total, comprovando a eficácia da estratégia de backup e restauração.

#### Arquivos Gerados

| Arquivo | Tamanho | Tipo |
|---------|---------|------|
| escola-backup.sql | 2.2K | Dump SQL |
| mysql-prod-data.tar.gz | 5.4M | Backup binário do volume |

---

### CENÁRIO 3 — Bind Mount e Desenvolvimento

**Objetivo:** Compreender o funcionamento de Bind Mounts em ambientes de desenvolvimento.

#### Conceito Técnico

Um **Bind Mount** mapeia diretamente um diretório do sistema de arquivos do **host** para dentro do container. Diferentemente dos Named Volumes, o Bind Mount não é gerenciado pelo Docker — o caminho do host é exposto diretamente ao container.

| Característica | Named Volume | Bind Mount |
|---------------|-------------|------------|
| Gerenciado por | Docker | Sistema operacional (host) |
| Localização | `/var/lib/docker/volumes/` | Qualquer caminho do host |
| Uso principal | Produção / persistência | Desenvolvimento / hot reload |
| Portabilidade | Alta | Depende do host |

#### Comandos Executados

**1. Criação do diretório e arquivo local:**
```bash
mkdir -p ~/infra-persistencia-docker/docker/app
echo "<h1>Ambiente de Desenvolvimento</h1>" > ~/infra-persistencia-docker/docker/app/index.html
```

**2. Container Nginx com Bind Mount:**
```bash
docker run -d \
  --name webserver-dev \
  -p 8080:80 \
  -v ~/infra-persistencia-docker/docker/app:/usr/share/nginx/html \
  nginx:latest
```

**3. Validação do arquivo dentro do container:**
```bash
docker exec -it webserver-dev cat /usr/share/nginx/html/index.html
# <h1>Ambiente de Desenvolvimento</h1>
```

**4. Modificação no host e reflexo imediato no container:**
```bash
echo "<h1>Arquivo Atualizado pelo Host!</h1>" > ~/infra-persistencia-docker/docker/app/index.html
docker exec -it webserver-dev cat /usr/share/nginx/html/index.html
# <h1>Arquivo Atualizado pelo Host!</h1>
```

**Resultado:** A alteração feita no host foi refletida imediatamente dentro do container **sem necessidade de reinicialização**, demonstrando o comportamento de hot reload do Bind Mount.

#### Análise Técnica

O Bind Mount cria um espelho em tempo real entre o host e o container. Qualquer escrita em um lado é imediatamente visível no outro, pois ambos apontam para o mesmo inode no sistema de arquivos. Isso torna o Bind Mount ideal para ambientes de desenvolvimento onde o desenvolvedor edita arquivos localmente e quer ver o resultado imediatamente no container.

---

### CENÁRIO 4 — Compartilhamento de Dados Entre Containers

**Objetivo:** Demonstrar o compartilhamento de armazenamento entre múltiplos containers usando um volume compartilhado.

#### Conceito Técnico

Um volume Docker pode ser montado simultaneamente em múltiplos containers. Isso permite padrões de arquitetura como **produtor/consumidor**, onde um serviço grava dados e outro os lê, sem necessidade de comunicação direta via rede.

#### Comandos Executados

**1. Criação do volume compartilhado:**
```bash
docker volume create dados-compartilhados
```

**2. Container Produtor (grava mensagens a cada 5 segundos):**
```bash
docker run -d \
  --name produtor \
  -v dados-compartilhados:/dados \
  ubuntu bash -c "while true; do echo \"[$(date)] Mensagem do produtor\" >> /dados/log.txt; sleep 5; done"
```

**3. Container Consumidor (lê o arquivo compartilhado):**
```bash
docker run -d \
  --name consumidor \
  -v dados-compartilhados:/dados \
  ubuntu bash -c "while true; do cat /dados/log.txt; sleep 5; done"
```

**4. Validação em tempo real:**
```bash
docker logs consumidor
docker exec consumidor cat /dados/log.txt
```

**Resultado:** O container consumidor leu com sucesso as mensagens gravadas pelo container produtor através do volume compartilhado, em tempo real, sem qualquer comunicação de rede entre eles.

#### Análise Técnica

Ambos os containers montam o mesmo volume (`dados-compartilhados`) no caminho `/dados`. Como o Docker garante que o volume é o mesmo objeto no sistema de arquivos, qualquer arquivo criado pelo produtor é imediatamente visível para o consumidor. Esse padrão é amplamente utilizado em arquiteturas de microsserviços para compartilhamento de logs, arquivos de configuração e dados temporários.

**Limpeza após o cenário:**
```bash
docker rm -f produtor consumidor
```

---

### CENÁRIO 5 — Automação de Backup

**Objetivo:** Automatizar o processo de backup via script Bash, simulando práticas operacionais reais de DevOps.

#### Conceito Técnico

Em ambientes de produção, backups manuais são inviáveis. Scripts Bash automatizados — combinados com agendadores como `cron` — garantem que backups sejam realizados periodicamente e com nomenclatura padronizada (timestamp), facilitando auditoria e recuperação.

#### Script de Backup (`scripts/backup.sh`)

```bash
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
```

#### Execução

```bash
chmod +x scripts/backup.sh
bash scripts/backup.sh
```

**Saída do script:**
```
============================================
 INICIANDO BACKUP - 20260608_020735
============================================
[1/2] Gerando backup SQL...
      Arquivo: backup-sql-20260608_020735.sql
[2/2] Gerando backup do volume...
      Arquivo: backup-volume-20260608_020735.tar.gz
============================================
 BACKUP CONCLUÍDO COM SUCESSO!
 Local: /home/kaike/infra-persistencia-docker/backups
-rw-rw-r-- 1 kaike docker 2.2K Jun 8 02:07 backup-sql-20260608_020735.sql
-rw-r--r-- 1 root  root   5.4M Jun 8 02:07 backup-volume-20260608_020735.tar.gz
============================================
```

#### Análise Técnica

O script gera dois tipos de backup com timestamp no nome (`YYYYMMDD_HHMMSS`), garantindo que cada execução produza arquivos únicos sem sobrescrever backups anteriores. O uso de variáveis no início do script facilita a adaptação para outros bancos, volumes e containers sem modificar a lógica principal.

---

## 4. Evidências

As evidências de cada cenário estão organizadas na pasta `screenshots/` do repositório:

| Pasta | Conteúdo |
|-------|----------|
| `screenshots/cenario1/` | Volume criado, tabela com dados, persistência validada |
| `screenshots/cenario2/` | Arquivos de backup, simulação de perda, restauração |
| `screenshots/cenario3/` | Bind Mount ativo, hot reload validado |
| `screenshots/cenario4/` | Log compartilhado entre produtor e consumidor |
| `screenshots/cenario5/` | Execução do script, arquivos gerados com timestamp |

---

## 5. Problemas Encontrados e Soluções

### Problema 1 — `newgrp` não encontrado após instalar Docker

**Erro:**
```
Command 'newgrp' not found, but can be installed with:
sudo apt install util-linux-extra
```

**Causa:** O utilitário `newgrp` não estava presente na instalação padrão do Ubuntu 24.04.

**Solução:**
```bash
sudo apt install util-linux-extra -y
```

---

### Problema 2 — Copiar/colar não funcionava na VM VirtualBox

**Causa:** Os Guest Additions do VirtualBox não estavam instalados, desabilitando a área de transferência compartilhada.

**Solução adotada:** Acesso ao Ubuntu via SSH pelo PowerShell do Windows, eliminando a dependência do clipboard da VM.

```bash
ssh kaike@192.168.X.X
```

---

### Problema 3 — Push rejeitado pelo GitHub (fetch first)

**Erro:**
```
error: failed to push some refs
hint: Updates were rejected because the remote contains work that you do not have locally
```

**Causa:** O repositório foi criado no GitHub com um README automático, gerando divergência com o repositório local.

**Solução:**
```bash
git push -u origin main --force
```

---

### Problema 4 — Git sem identidade configurada

**Erro:**
```
fatal: unable to auto-detect email address
```

**Causa:** O Git não foi configurado com nome e e-mail antes do primeiro commit.

**Solução:**
```bash
git config --global user.email "kaikefigueiredo113@gmail.com"
git config --global user.name "Kaike-figueiredo9"
```

---

## 6. Conclusão

Esta atividade demonstrou na prática os principais mecanismos de persistência de dados em ambientes Docker:

- **Named Volumes** garantem que dados sobrevivam ao ciclo de vida dos containers, sendo a solução recomendada para produção.
- **Bind Mounts** oferecem acesso direto ao sistema de arquivos do host, ideais para desenvolvimento com hot reload.
- **Volumes compartilhados** permitem comunicação entre containers sem necessidade de rede, habilitando padrões como produtor/consumidor.
- **Backup e restauração** de volumes são operações essenciais para garantir resiliência em ambientes reais.
- **Automação via Bash** simula práticas operacionais de DevOps, preparando para ambientes de produção com agendamento via cron.

A combinação dessas técnicas é fundamental para qualquer profissional que trabalhe com infraestrutura containerizada, especialmente em contextos de Cloud Computing, DevOps e Segurança da Informação.

---

## 7. Referências

- [Docker Documentation — Volumes](https://docs.docker.com/storage/volumes/)
- [Docker Documentation — Bind Mounts](https://docs.docker.com/storage/bind-mounts/)
- [MySQL Docker Hub](https://hub.docker.com/_/mysql)
- [Nginx Docker Hub](https://hub.docker.com/_/nginx)
