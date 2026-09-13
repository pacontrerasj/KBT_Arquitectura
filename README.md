# KBT_Arquitectura — FreshBox SpA 🥬

Repositorio del proyecto académico **FreshBox SpA** (**ARY1102 — Arquitectura, DuocUC**).
Aplicación de catálogo de productos orgánicos (5 microservicios Dockerizados + MySQL)
desplegada en **AWS** con **IaC (Terraform)** y **CI/CD (GitHub Actions)**.

> Esta guía está pensada para **reproducir el despliegue completo en otro dispositivo**
> que cumpla los mismos requisitos (cuenta AWS **Learner Lab** de AWS Academy).
> Sigue los pasos en orden y no se te escapará nada.

---

## 1. Arquitectura

```
                    INTERNET
                        │
              ┌─────────▼─────────┐
              │ ALB (HTTP 80)     │  Multi-AZ + SG público
              └─────────┬─────────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
┌────────▼────────┐    ┌────────▼────────┐
│ EC2 APP-1 (1a)  │    │ EC2 APP-2 (1b)  │   ASG t4g.small ARM64
│ 5 contenedores  │    │ 5 contenedores  │   Docker + ECR
└────────┬────────┘    └────────┬────────┘
         │                      │
         └───────────┬──────────┘
                     │
            ┌────────▼────────┐
            │ EC2 MySQL 8.0   │   Subred privada DATA
            │ BD "freshbox"   │
            └─────────────────┘
```

| Componente | Detalle |
|---|---|
| Red | VPC `10.0.0.0/22` — 6 subredes `/25` (2 públicas / 2 APP / 2 DATA), IGW y NAT |
| Cómputo APP | ASG (mín 2, máx 4, escalado por CPU) + Launch Template AL2023 ARM64 |
| Cómputo DATA | EC2 MySQL 8.0 (instancia `t4g.small`), user-data con auto-inicialización |
| Balanceador | ALB internet-facing, listener HTTP 80, health check |
| Contenedores | 5 imágenes ARM64 en repositorios **ECR MUTABLE** |
| Seguridad | Security Groups encadenados ALB → APP → DATA, IMDSv2 |
| Backups | Módulo opcional (deshabilitado: Learner Lab no permite crear roles IAM) |
| Estado | Remote state en **S3 + DynamoDB** (locks) |

---

## 2. Estructura del repositorio

```
.
├── .github/workflows/          # Pipelines de CI/CD + tests
│   ├── build-ecr.yml           # Build + push de 5 imágenes a ECR (ARM64)
│   ├── terraform.yml           # fmt/test/validate/plan-check/apply de la infra
│   ├── deploy.yml              # Deploy de contenedores en las EC2 (vía SSM)
│   ├── destroy.yml             # Destrucción total (requiere confirmación)
│   └── tests.yml               # Tests unitarios, sintaxis, Checkov y smoke/E2E
├── desarrolloappEP1/
│   └── desarrolloappEP1/
│       ├── docker-compose.yml              # App completa en local
│       ├── init.sql                        # Esquema + datos seed
│       ├── microservicioFrontend/          # nginx (UI estática + proxy)
│       └── microserviciosBackend/          # 4 APIs Node/Express
├── freshbox-ep1/
│   ├── infra/
│   │   ├── envs/dev/           # Entorno dev (orquestación raíz + backend)
│   │   │   └── tests/          # Terraform test (plan-only)
│   │   └── modules/            # network, security, ecr, alb, compute-*
│   ├── scripts/
│   │   ├── deploy-ec2.sh       # Deploy contenedores vía SSM
│   │   └── smoke-alb.mjs       # Smoke/E2E del CRUD contra el ALB
│   └── tests/
│       └── terraform_plan_check.py  # Aserciones del plan Terraform
└── informe-base-freshbox.md    # Base del informe académico
```

---

## 3. Guía de despliegue (paso a paso, reproducible)

### Paso 0 — Requisitos en el dispositivo nuevo

| Herramienta | Version mínima | Comando para verificar |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | 1.6+ | `terraform version` |
| [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | 2.x | `aws --version` |
| [Node.js](https://nodejs.org) | 18+ (para tests) | `node --version` |
| [Docker](https://www.docker.com/products/docker-desktop/) | 24+ (opcional, local) | `docker --version` |
| Git | cualquiera | `git --version` |
| `python3` | 3.8+ (para tests) | `python3 --version` |

### Paso 1 — Clonar y autenticar por SSH (recomendado)

```bash
# 1) Generar clave SSH (si no la tienes)
ssh-keygen -t ed25519 -C "tu-correo@dominio.cl"

# 2) Copiar la clave pública a GitHub
#    Settings → SSH and GPG keys → New SSH key → pegar el contenido de ~/.ssh/id_ed25519.pub

# 3) Clonar con SSH
git clone git@github.com:pacontrerasj/KBT_Arquitectura.git
cd KBT_Arquitectura
```

> Evita el HTTPS con token en texto plano. Verifica la conexión:
> `ssh -T git@github.com` → debería salir `Hi pacontrerasj!`.

### Paso 2 — Configurar los Secrets de GitHub

Las pipelines necesitan credenciales. En el repo: **Settings → Secrets and variables → Actions**.

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID` | De la sesión del Learner Lab (ver Paso 3) |
| `AWS_SECRET_ACCESS_KEY` | De la sesión del Learner Lab |
| `AWS_SESSION_TOKEN` | De la sesión del Learner Lab (¡es temporal!) |
| `DB_PASS` | `alumno123` |
| `DB_ROOT_PASS` | `root123` |

### Paso 3 — Obtener credenciales AWS (Learner Lab)

1. Entra a `https://awsacademy.instructure.com` → abre tu **Learner Lab** → botón **Start Lab**.
2. Una vez que la luz del lab esté verde, clic en **AWS Details** (arriba) y copia
   los valores de `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN`.
3. En tu terminal, exporta las variables **en cada sesión nueva** (las credenciales son temporales):

```bash
export AWS_ACCESS_KEY_ID="REEMPLAZAR"
export AWS_SECRET_ACCESS_KEY="REEMPLAZAR"
export AWS_SESSION_TOKEN="REEMPLAZAR"
export AWS_DEFAULT_REGION=us-east-1

# Verificar
aws sts get-caller-identity
```

### Paso 4 — Bootstrap del estado remoto (S3 + DynamoDB)

Solo la primera vez por cuenta (los **nombres deben ser únicos** en toda AWS,
cámbialos si otro proyecto los usa):

```bash
# 1) Bucket S3 para el state (.tfstate)
aws s3api create-bucket --bucket freshbox-s3-tfstate --region us-east-1

# 2) Tabla DynamoDB para bloqueo de ejecuciones
aws dynamodb create-table \
  --table-name freshbox-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

> Si un `terraform apply` falla con error de S3 (`AccessDenied` / SCP), impórtalo a mano
> o crea el bucket manualmente desde la consola (limitaciones del Learner Lab, ver §6).

El backend ya apunta a esos nombres (`freshbox-ep1/infra/envs/dev/backend.tf`).

### Paso 5 — Desplegar la infraestructura (Terraform)

```bash
cd freshbox-ep1/infra/envs/dev

# 1) Variables locales (¡no se commitear — está en .gitignore!)
cp terraform.tfvars.example terraform.tfvars
#   editar terraform.tfvars y completar db_pass = "alumno123" y db_root_pass = "root123"

# 2) Inicializar con el backend remoto
terraform init

# 3) Ver y aplicar
terraform plan -var="db_pass=alumno123" -var="db_root_pass=root123"
terraform apply -var="db_pass=alumno123" -var="db_root_pass=root123"
```

Al terminar, Terraform imprime los outputs (VPC, ASG, DNS del ALB, IP del MySQL, etc.).
Guarda el **DNS del ALB** para el paso 8.

> **Ojo — primera vez en una cuenta nueva:** el usuario MySQL se crea en el primer arranque
> de la instancia (`user-data`). Si el `apply` muestra `Access denied for 'alumno'`
> al consultar la BD, ejecuta la receta de MySQL de la §7 de Troubleshooting.

### Paso 6 — Build + push de imágenes y deploy (CI/CD)

El flujo automático es:

```
git push origin main
  └─▶ build-ecr.yml   (QEMU + Buildx → construye y sube 5 imágenes ARM64 a ECR)
        │
        └─▶ deploy.yml (workflow_run → SSM a las EC2 del ASG: pull + docker run x5)
```

```bash
git add -A
git commit -m "Mi cambio"
git push origin main
```

En **Actions** verás 3 pipelines corriendo: `Build & Push to ECR` → `Deploy Containers to EC2`
(+ `Terraform Infrastructure` si tocaste `freshbox-ep1/infra/**`, y `Tests de Calidad`).

> **Después de un `destroy`** (o en una cuenta nueva) ejecuta en orden por **Run workflow**:
> ① `Terraform Infrastructure` (aplica: crea VPC, ECR, ALB, ASG y las EC2;
> por defecto aplica aunque sea manual, usa `apply=false` para solo planear) →
> ② `Build & Push to ECR` → ③ `Deploy Containers to EC2` (se dispara al terminar el build).
> No corras el build antes que el terraform: los repos ECR aún no existirían.

Para deploy **manual** (sin cambiar código): Actions → **Deploy Containers to EC2** →
**Run workflow** (deja el SHA vacío para usar el último build).

### Paso 7 — Verificar la aplicación

```bash
# Trae el DNS del ALB desde Terraform o la consola EC2 → Load Balancers
ALB="http://<alb-dns>"

# Listado de productos (debe devolver JSON con el seed)
curl "$ALB/api/products"

# Health checks de los microservicios (deben responder OK)
curl "$ALB/api/products" -o /dev/null -w "%{http_code}\n"   # 200
```

Abre el DNS del ALB en el navegador: verás la **UI de FreshBox** (frontend nginx).
Prueba crear / editar / eliminar un producto.

> **502 Bad Gateway justo después del deploy:** es normal mientras los contenedores
> arrancan (0 a 60 s). Recarga pasados unos segundos.

### Paso 8 — Correr los tests

```bash
# ── Tests unitarios de los microservicios (node:test) ──
for svc in get-products create-product update-product delete-product; do
  cd "desarrolloappEP1/desarrolloappEP1/microserviciosBackend/$svc"
  npm install --no-audit --no-fund && npm test
  cd - > /dev/null
done

# ── Terraform: formato + validación ──
cd freshbox-ep1/infra/envs/dev
terraform fmt -check -recursive   # formato correcto
terraform validate                # configuración válida
terraform test -verbose           # tests nativos (plan-only)

# ── Aserciones del plan (diseño) ── (requiere credenciales AWS)
terraform plan -out=tfplan -var="db_pass=alumno123" -var="db_root_pass=root123"
python3 ../../../tests/terraform_plan_check.py tfplan

# ── Smoke/E2E contra el despliegue ──
ALB_URL="http://<alb-dns>" node freshbox-ep1/scripts/smoke-alb.mjs
```

Todos estos checks corren **automáticamente en GitHub Actions** en cada push
(workflow `Tests de Calidad` + pasos de Terraform en `terraform.yml`).

### Paso 9 — Eliminar todo (ahorrar costos)

```bash
cd freshbox-ep1/infra/envs/dev
terraform destroy -var="db_pass=alumno123" -var="db_root_pass=root123"
```

O desde GitHub Actions: **Terraform Destroy** → escribe `DESTROY` como confirmación
(previene borrados accidentales).

---

## 4. Tests y marcos de referencia

| Capa | Marco / herramienta | Qué valida | Dónde corre |
|---|---|---|---|
| Microservicios (Node) | `node:test` + `node:assert` (runner oficial de Node) | Respuestas HTTP, validaciones, 400/404/500 y flujos CRUD con BD simulada | Local + `tests.yml` |
| Sintaxis JS | `node --check` | Parseo válido de cada microservicio | `tests.yml` |
| IaC (Terraform) | `terraform fmt` / `validate` / `test` | Formato, configuración válida y diseño del entorno (plan-only) | Local + `terraform.yml` |
| Diseño del plan | Script propio `terraform_plan_check.py` | CIDR VPC, 6 subredes /25, ECR MUTABLE ×5, ASG desired=2, t4g.small | Local + `terraform.yml` |
| Seguridad IaC | **Checkov** (framework estándar CIS) | Escaneo estático de las plantillas Terraform | `tests.yml` |
| Smoke / E2E | Script `smoke-alb.mjs` sobre la API | CRUD real contra el ALB desplegado | Manual + `tests.yml` |

> Cómo correr cada uno: §3 Paso 8.

---

## 5. Uso local (sin AWS)

```bash
cd desarrolloappEP1/desarrolloappEP1
docker compose up -d --build
# Frontend:  http://localhost:8080
# Microservicios: http://localhost:3001..3004
docker compose down
```

Los passwords locales coinciden con los de producción: BD `freshbox`,
usuario `alumno` / `alumno123`, root `root123`.

---

## 6. Limitaciones del Learner Lab (importante)

- **Credenciales temporales:** se exportan de nuevo en cada sesión; los
  `AWS_SESSION_TOKEN` en GitHub Secrets caducan → actualízalos al comenzar el lab.
- **No permite `iam:CreateRole`** → el módulo de **backup** está deshabilitado
  por defecto (`enable_backup = false`) y se referencia el perfil `LabInstanceProfile`.
- **SCP restringe algunas operaciones S3** → si `terraform apply` falla creando
  el bucket del backend, créalo manualmente (Paso 4) y borra la entrada del plan.
- **Sin soporte garantizado de EIP** → `assign_eip = false`; el MySQL usa IP privada.
- **ECR en modo MUTABLE** → el `latest` se sobrescribe en cada build (permite
  iterar varias veces sin colisiones de tags inmutables).
- **Política de passwords de MySQL 8** → el user-data relaja la validación
  (`validate_password.policy = LOW`, `length = 7`) para aceptar `root123`.

---

## 7. Troubleshooting (errores ya resueltos)

| Síntoma | Causa | Solución |
|---|---|---|
| `502 Bad Gateway` en el ALB | Contenedores aún arrancando | Esperar 30-60 s y recargar; revisar `docker ps` vía SSM |
| `Access denied for user 'alumno'@...` en MySQL | Usuario no creado (o password policy de MySQL 8) | Aplicar receta de la §8 o reinstanciar (re-aplica user-data) |
| `exec format error` al correr contenedores | Imagen x86 en EC2 ARM | Activar QEMU + Buildx en `build-ecr.yml` (ya configurado) |
| ECR `latest` no se sobrescribe | Repositorio `IMMUTABLE` | `image_tag_mutability = "MUTABLE"` |
| Actions no corre el workflow | Workflows dentro de carpeta anidada | Deben estar en `.github/workflows/` de la **raíz** del repo |
| `detached HEAD` en git | Movida de rama | `git branch -f main HEAD && git checkout main` |
| `TEMP_PASS` vacío en user-data | Log de MySQL aún no generado | `sleep` / reintentar; o extraer con otra ruta de log |
| Deploy SSM falla por comando multilínea | Comandos concatenados inválidos | Comandos como **array JSON** (ya implementado en `deploy-ec2.sh`) |

### §8 — Receta manual de MySQL (si un `apply` dejó la BD sin usuario)

```bash
# En la instancia freshbox-mysql-dev vía EC2 → Conectar → Session Manager:
TEMP_PASS=$(sudo grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}' | tail -1)
sudo mysql --connect-expired-password -uroot -p"$TEMP_PASS" <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED BY 'Freshbox!2026';
SET GLOBAL validate_password.policy = LOW;
SET GLOBAL validate_password.length = 7;
ALTER USER 'root'@'localhost' IDENTIFIED BY 'root123';
CREATE DATABASE IF NOT EXISTS freshbox;
CREATE USER IF NOT EXISTS 'alumno'@'%' IDENTIFIED BY 'alumno123';
ALTER USER 'alumno'@'%' IDENTIFIED BY 'alumno123';
GRANT ALL PRIVILEGES ON freshbox.* TO 'alumno'@'%';
FLUSH PRIVILEGES;
SQL
mysql -ualumno -palumno123 freshbox -e "SHOW TABLES;"
```

---

## 8. Referencias

- `informe-base-freshbox.md` — base del informe académico (stack, prácticas y mejoras).
- `freshbox-ep1/infra/` — estructura Terraform con módulos reutilizables.
- `freshbox-ep1/scripts/deploy-ec2.sh` — detalle del deploy vía SSM.