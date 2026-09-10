#!/bin/bash
# FreshBox SpA - Deploy de contenedores vía SSM a las EC2 APP.
# Ejecutado por GitHub Actions después de que build-ecr.yml pushea las imágenes.

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
COMMIT_SHA="${COMMIT_SHA:-}"
TAG_NAME="${TAG_NAME:-freshbox-app-dev}"
DB_ENV_FILE="${DB_ENV_FILE:-/opt/freshbox/.env}"

if [ -z "$COMMIT_SHA" ]; then
  echo "ERROR: COMMIT_SHA es obligatorio"
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

SERVICES=("frontend" "get-products" "create-product" "update-product" "delete-product")
PORTS=(80 3001 3002 3003 3004)

INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${TAG_NAME}" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "No se encontraron instancias APP activas (tag: ${TAG_NAME})"
  exit 1
fi
echo "Instancias encontradas: ${INSTANCE_IDS}"

run_ssm() {
  local instance="$1"
  shift
  local command_id
  command_id=$(aws ssm send-command \
    --instance-ids "$instance" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=$1" \
    --query "Command.CommandId" \
    --output text)
  echo "$command_id"
}

for INSTANCE_ID in $INSTANCE_IDS; do
  echo "=== Desplegando en $INSTANCE_ID ==="

  run_ssm "$INSTANCE_ID" "[\"aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_BASE}\"]" >/dev/null 2>&1 || true
  sleep 10

  COMMANDS="docker network create --driver bridge freshbox-net 2>/dev/null || true"

  for i in "${!SERVICES[@]}"; do
    SVC="${SERVICES[$i]}"
    PORT="${PORTS[$i]}"
    IMAGE="${ECR_BASE}/freshbox-${SVC}:${COMMIT_SHA}"

    COMMANDS="${COMMANDS}\ndocker pull ${IMAGE}"
    COMMANDS="${COMMANDS}\ndocker stop freshbox-${SVC} 2>/dev/null || true"
    COMMANDS="${COMMANDS}\ndocker rm freshbox-${SVC} 2>/dev/null || true"

    if [ "$SVC" = "frontend" ]; then
      COMMANDS="${COMMANDS}\ndocker run -d --name freshbox-${SVC} --network freshbox-net --restart unless-stopped -p ${PORT}:80 ${IMAGE}"
    else
      COMMANDS="${COMMANDS}\ndocker run -d --name freshbox-${SVC} --network freshbox-net --network-alias ${SVC} --restart unless-stopped --env-file ${DB_ENV_FILE} -p ${PORT}:${PORT} ${IMAGE}"
    fi
  done

  COMMANDS="${COMMANDS}\ndocker ps"

  COMMAND_ID=$(run_ssm "$INSTANCE_ID" "[\"$(printf '%s' "$COMMANDS" | sed 's/"/\\"/g')\"]")
  echo "SSM Command $COMMAND_ID enviado a $INSTANCE_ID"

  sleep 15
  STATUS=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "Status" \
    --output text 2>/dev/null || echo "timeout")
  echo "Estado del deploy en $INSTANCE_ID: $STATUS"
done

echo "=== Deploy completado ==="