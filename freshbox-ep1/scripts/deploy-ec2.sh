#!/bin/bash
# FreshBox SpA - Deploy de contenedores vía SSM a las EC2 APP.
# Envía cada comando como un elemento separado del array JSON de SSM.

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

# Envía comandos SSM y devuelve el CommandId. Los comandos van como
# elementos independientes del array JSON (parseo correcto de SSM).
run_ssm() {
  local instance="$1"
  shift
  local params_json
  params_json=$(python3 -c 'import json,sys; print(json.dumps({"commands": sys.argv[1:]}))' "$@")
  aws ssm send-command \
    --instance-ids "$instance" \
    --document-name "AWS-RunShellScript" \
    --parameters "$params_json" \
    --query "Command.CommandId" \
    --output text
}

wait_status() {
  local instance="$1"
  local command_id="$2"
  local status="Pending"
  for _ in $(seq 1 20); do
    status=$(aws ssm get-command-invocation \
      --command-id "$command_id" \
      --instance-id "$instance" \
      --query "Status" --output text 2>/dev/null || echo "Pending")
    if [ "$status" = "Success" ] || [ "$status" = "Failed" ] || [ "$status" = "Cancelled" ]; then
      break
    fi
    sleep 5
  done
  echo "$status"
}

for INSTANCE_ID in $INSTANCE_IDS; do
  echo "=== Desplegando en $INSTANCE_ID ==="

  # 1. Login ECR (se ignora el resultado, se reintenta abajo)
  LOGIN_ID=$(run_ssm "$INSTANCE_ID" \
    "aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_BASE}")
  wait_status "$INSTANCE_ID" "$LOGIN_ID" >/dev/null || true

  # 2. Preparar red + contenedores (cada comando es un elemento del array)
  CMDS=("docker network create --driver bridge freshbox-net 2>/dev/null || true")

  for i in "${!SERVICES[@]}"; do
    SVC="${SERVICES[$i]}"
    PORT="${PORTS[$i]}"
    IMAGE="${ECR_BASE}/freshbox-${SVC}:${COMMIT_SHA}"

    CMDS+=("docker pull ${IMAGE}")
    CMDS+=("docker stop freshbox-${SVC} 2>/dev/null || true")
    CMDS+=("docker rm freshbox-${SVC} 2>/dev/null || true")

    if [ "$SVC" = "frontend" ]; then
      CMDS+=("docker run -d --name freshbox-${SVC} --network freshbox-net --restart unless-stopped -p ${PORT}:80 ${IMAGE}")
    else
      CMDS+=("docker run -d --name freshbox-${SVC} --network freshbox-net --network-alias ${SVC} --restart unless-stopped --env-file ${DB_ENV_FILE} -p ${PORT}:${PORT} ${IMAGE}")
    fi
  done

  CMDS+=("docker ps")

  DEPLOY_ID=$(run_ssm "$INSTANCE_ID" "${CMDS[@]}")
  STATUS=$(wait_status "$INSTANCE_ID" "$DEPLOY_ID")
  echo "Estado del deploy en $INSTANCE_ID: $STATUS"

  # Imprimir salida real del comando para diagnóstico
  echo "--- Salida de docker ps ---"
  aws ssm get-command-invocation \
    --command-id "$DEPLOY_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "StandardOutputContent" --output text 2>/dev/null || true

  echo "--- Errores (si hubo) ---"
  aws ssm get-command-invocation \
    --command-id "$DEPLOY_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "StandardErrorContent" --output text 2>/dev/null || true
done

echo "=== Deploy completado ==="