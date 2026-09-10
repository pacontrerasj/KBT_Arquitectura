# KBT_Arquitectura — FreshBox SpA

Repositorio del proyecto académico **FreshBox SpA** (ASIGNATURA ARY1102, DuocUC).
Contiene la aplicación de catálogo de productos orgánicos y toda la infraestructura
para desplegarla en AWS mediante **IaC (Terraform)** y **CI/CD (GitHub Actions)**.

---

## Estructura

```
Prueba1/
├── desarrolloappEP1/            # Aplicación (5 microservicios Dockerizados + MySQL)
│   └── desarrolloappEP1/
│       ├── docker-compose.yml   # Levantar la app en local
│       ├── init.sql             # Esquema + datos seed
│       ├── microservicioFrontend/   # nginx:alpine (UI estática + reverse proxy)
│       └── microserviciosBackend/   # 4 APIs Node/Express (get/create/update/delete)
├── freshbox-ep1/
│   ├── .github/workflows/       # 4 pipelines de GitHub Actions
│   ├── infra/
│   │   ├── bootstrap/           # State remoto (S3 + DynamoDB locks)
│   │   ├── envs/dev/            # Orquestación raíz del entorno dev
│   │   └── modules/             # Módulos Terraform reutilizables
│   └── scripts/
│       └── deploy-ec2.sh        # Deploy de contenedores vía SSM
└── infraestructura-freshbox.md  # Arquitectura target (EP1)
```

---

## Arquitectura AWS desplegada

Internet → **ALB** (subredes públicas, multi-AZ) → **ASG de EC2** `t4g.small` ARM
(min 2 / máx 4, escalado por CPU) con 5 contenedores Docker → **EC2 MySQL** 8.0
en subred privada de datos.

| Componente | Detalle |
|---|---|
| Red | VPC `10.0.0.0/22`, 6 subredes `/25` (2 públicas / 2 APP / 2 DATA), IGW, NAT |
| Cómputo APP | ASG + Launch Template AL2023 ARM64, EBS gp3 cifrado, IMDSv2 |
| Cómputo DATA | EC2 MySQL 8.0, EBS cifrado |
| Balanceador | ALB internet-facing, listener HTTP 80, health check |
| Contenedores | 5 imágenes en repositorios ECR (frontend, get, create, update, delete) |
| Seguridad | Security Groups encadenados ALB → APP → DATA |
| Backups | Módulo opcional deshabilitado por restricciones del Learner Lab |

---
## 1. Arquitectura General



```

┌─────────────────────────────────────────────────────────────────────┐

│                         INTERNET                                    │

└──────────────────────────────┬──────────────────────────────────────┘

                               │

                    ┌──────────▼──────────┐

                    │   ALB (Puerto 80)   │

                    │  Subredes Públicas   │

                    │   Multi-AZ (1a,1b)   │

                    └──────────┬──────────┘

                               │

              ┌────────────────┼────────────────┐

              │                                   │

   ┌──────────▼──────────┐           ┌──────────▼──────────┐

   │  EC2 APP-1 (AZ1a)  │           │  EC2 APP-2 (AZ1b)  │

   │   t4g.small ARM     │           │   t4g.small ARM     │

   │   Docker 5 Contenedores         │   Docker 5 Contenedores

   └──────────┬──────────┘           └──────────┬──────────┘

              │                                   │

              └────────────────┬────────────────┘

                               │

                    ┌──────────▼──────────┐

                    │  EC2 MySQL (AZ1a)   │

                    │   t4g.small ARM     │

                    │   freshbox BD       │

                    └─────────────────────┘

```



---


## Pipelines de GitHub Actions

| Workflow | Función |
|---|---|
| `build-ecr.yml` | Build + push de las 5 imágenes ARM64 a ECR (QEMU + Buildx) |
| `terraform.yml` | `terraform plan` / `apply` con state remoto en S3 |
| `deploy.yml` | Despliega contenedores vía SSM en las EC2 del ASG |
| `destroy.yml` | Elimina toda la infraestructura (requiere confirmación `DESTROY`) |

### Secrets requeridos en GitHub (Settings → Secrets → Actions)
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (Learner Lab)
- `DB_PASS` (`alumno123`), `DB_ROOT_PASS` (`root123`)

---

## Uso local

```bash
cd desarrolloappEP1/desarrolloappEP1
docker compose up -d --build
# Frontend: http://localhost:8080
```

## Desplegar infraestructura en AWS

```bash
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_SESSION_TOKEN=...
cd freshbox-ep1/infra/envs/dev
terraform init
terraform apply -var="db_pass=alumno123" -var="db_root_pass=root123"
```

## Eliminar infraestructura (ahorrar costos)

```bash
terraform destroy -var="db_pass=alumno123" -var="db_root_pass=root123"
```
o desde GitHub Actions → **Terraform Destroy** escribiendo `DESTROY` como confirmación.

---

## Documentación de referencia
- `infraestructura-freshbox.md` — arquitectura target detallada (EP1)
- `informe-base-freshbox.md` — base para el informe académico (stack, prácticas y mejoras)