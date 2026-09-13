#!/usr/bin/env python3
"""
FreshBox SpA - Evaluación automatizada del plan de Terraform.

Lee el plan generado (tfplan) y valida que la infraestructura cumpla
los requisitos de diseño. Uso: front a pytest/none, solo stdin? no:
    python3 terraform_plan_check.py tfplan

Salida legible con resultados PASS/FAIL; exit code != 0 si algo falla.
"""
import json
import subprocess
import sys
import tempfile
import os


def load_plan(plan_file):
    if not os.path.exists(plan_file):
        print(f"ERROR: no existe el plan '{plan_file}'. Ejecuta primero `terraform plan -out=tfplan`.")
        sys.exit(2)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tmp:
        subprocess.run(
            ["terraform", "show", "-json", plan_file],
            check=True, stdout=tmp,
        )
    with open(tmp.name) as fh:
        return json.load(fh)


def resources_by_address(plan_json):
    out = {}
    for change in plan_json.get("resource_changes", []):
        addr = change["address"]
        out.setdefault(addr, change["change"].get("after", {}))
    return out


def rm(resources, prefix):
    """Devuelve {direccion: valores} para todos los recursos con el prefijo dado."""
    return {addr: v for addr, v in resources.items() if addr.startswith(prefix)}


def check(name, condition, detail=""):
    label = "PASS" if condition else "FAIL"
    print(f"[{label}] {name}" + (f" -> {detail}" if detail else ""))
    return condition


def main():
    plan_file = sys.argv[1] if len(sys.argv) > 1 else "tfplan"
    data = load_plan(plan_file)
    resources = resources_by_address(data)

    ok = True

    # 1. Red
    vpcs = rm(resources, "aws_vpc.")
    ok &= check("VPC con CIDR 10.0.0.0/22", len(vpcs) == 1 and list(vpcs.values())[0].get("cidr_block") == "10.0.0.0/22", str(list(vpcs.values())))

    subnets = rm(resources, "aws_subnet.")
    ok &= check("Existen 6 subredes (2 public/2 app/2 data)", len(subnets) == 6, f"encontradas={len(subnets)}")
    for addr, vals in subnets.items():
        cidr = vals.get("cidr_block", "")
        ok &= check(f"Subred {addr} con prefijo /25", cidr.endswith("/25"), cidr)

    public_subnets = rm(resources, "aws_subnet.public[")
    app_subnets = rm(resources, "aws_subnet.app[")
    data_subnets = rm(resources, "aws_subnet.data[")
    ok &= check("2 subredes públicas", len(public_subnets) == 2, str(len(public_subnets)))
    ok &= check("2 subredes APP", len(app_subnets) == 2, str(len(app_subnets)))
    ok &= check("2 subredes DATA", len(data_subnets) == 2, str(len(data_subnets)))

    # 2. ECR
    ecrs = rm(resources, "aws_ecr_repository.")
    ok &= check("5 repositorios ECR", len(ecrs) == 5, f"encontrados={len(ecrs)}")
    for addr, vals in ecrs.items():
        ok &= check(f"ECR {addr} en modo MUTABLE", vals.get("image_tag_mutability") == "MUTABLE", str(vals.get("image_tag_mutability")))

    # 3. Compute
    lts = rm(resources, "aws_launch_template.")
    for addr, vals in lts.items():
        ok &= check(f"Launch template {addr} con t4g.small", vals.get("instance_type") == "t4g.small", str(vals.get("instance_type")))
    asgs = rm(resources, "aws_autoscaling_group.")
    ok &= check("1 Auto Scaling Group", len(asgs) == 1, str(len(asgs)))
    for addr, vals in asgs.items():
        ok &= check(f"ASG {addr} con desired_capacity 2", vals.get("desired_capacity") == 2, str(vals.get("desired_capacity")))

    # 4. Balanceador
    albs = rm(resources, "aws_lb.")
    ok &= check("1 ALB", len(albs) == 1, str(len(albs)))

    # 5. Seguridad
    sgs = rm(resources, "aws_security_group.")
    ok &= check("Security groups (ALB/APP/DATA) presentes", len(sgs) >= 3, str(len(sgs)))

    print("\n=== RESUMEN ===")
    print("TODOS LOS CHECKS OK" if ok else "EXISTEN FALLOS EN EL PLAN")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()