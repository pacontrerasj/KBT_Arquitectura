#!/usr/bin/env python3
"""
FreshBox SpA - Evaluación automatizada del despliegue Terraform.

Lee el estado actual Y el plan (si se entrega un tfplan) y valida que la
infraestructura cumpla los requisitos de diseño. Al detectar cambios en el plan
se usan esos valores; si no hay cambios (plan idempotente) se usa el estado
real de AWS.

Uso:
    python3 terraform_plan_check.py            (solo estado actual)
    python3 terraform_plan_check.py tfplan     (estado + plan)

Salida legible con resultados PASS/FAIL; exit code != 0 si algo falla.
"""
import json
import re
import subprocess
import sys
import tempfile


def tf_show_json(args):
    """Ejecuta `terraform show -json [arg]` y devuelve el JSON."""
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tmp:
        subprocess.run(["terraform", "show", "-json"] + args, check=True, stdout=tmp)
    with open(tmp.name) as fh:
        return json.load(fh)


def type_of(address):
    """Tipo de recurso a partir de la dirección (ignora el prefijo de módulo)."""
    parts = re.findall(r"(\w+)\.", address)
    return parts[-1] if parts else address


def name_of(address):
    """Nombre del recurso (ultimo componente, sin indice for_each)."""
    m = re.search(r"\.([A-Za-z0-9_-]+)(?:\[[^\]]*\])?$", address)
    return m.group(1) if m else address


def collect_state():
    """Dirección -> valores desde `terraform show -json` (estado actual)."""
    data = tf_show_json([])
    out = {}

    def walk(module_obj):
        for res in module_obj.get("resources", []):
            addr = res.get("address")
            for inst in (res.get("instances") or [{}]):
                attrs = inst.get("attributes")
                if not isinstance(attrs, dict):
                    continue
                key = inst.get("index_key")
                full = addr if key is None and "[" not in (addr or "") else f'{addr}["{key}"]'
                out[full] = attrs
        for child in module_obj.get("child_modules", []):
            walk(child)

    walk(data.get("values", {}).get("root_module", {}))
    return out


def collect_plan(plan_file):
    """Dirección -> valores desde el plan (resource_changes)."""
    data = tf_show_json([plan_file])
    out = {}
    for chg in data.get("resource_changes", []):
        after = (chg.get("change") or {}).get("after")
        if isinstance(after, dict):
            out[chg.get("address")] = after
    return out


def group_by_type(values):
    groups = {}
    for addr, _ in values.items():
        groups.setdefault(type_of(addr), []).append(addr)
    return groups


def check(name, condition, detail=""):
    label = "PASS" if condition else "FAIL"
    print(f"[{label}] {name}" + (f" -> {detail}" if detail else ""))
    return bool(condition)


def main():
    plan_file = sys.argv[1] if len(sys.argv) > 1 else None

    print("Obteniendo estado actual...")
    state = collect_state()
    merged = dict(state)
    print(f"Recursos en estado: {len(state)}")

    if plan_file:
        print(f"Combinando con el plan: {plan_file}")
        plan = collect_plan(plan_file)
        merged.update(plan)
        print(f"Recursos en plan: {len(plan)}")

    by_type = group_by_type(merged)
    ok = True

    # 1. Red
    vpcs = [a for a in by_type.get("aws_vpc", [])]
    ok &= check("VPC con CIDR 10.0.0.0/22",
                len(vpcs) == 1 and merged[vpcs[0]].get("cidr_block") == "10.0.0.0/22",
                str([merged.get(a, {}).get("cidr_block") for a in vpcs]))

    subnets = by_type.get("aws_subnet", [])
    ok &= check("Existen 6 subredes (2 public/2 app/2 data)", len(subnets) == 6, f"encontradas={len(subnets)}")
    for addr in subnets:
        cidr = merged[addr].get("cidr_block", "")
        ok &= check(f"Subred {type_of(addr)}/{name_of(addr)} con prefijo /25", cidr.endswith("/25"), cidr)

    tiers = {}
    for addr in subnets:
        tiers.setdefault(name_of(addr), []).append(addr)
    ok &= check("2 subredes public", len(tiers.get("public", [])) == 2, str(len(tiers.get("public", []))))
    ok &= check("2 subredes app", len(tiers.get("app", [])) == 2, str(len(tiers.get("app", []))))
    ok &= check("2 subredes data", len(tiers.get("data", [])) == 2, str(len(tiers.get("data", []))))

    # 2. ECR
    ecrs = by_type.get("aws_ecr_repository", [])
    ok &= check("5 repositorios ECR", len(ecrs) == 5, f"encontrados={len(ecrs)}")
    for addr in ecrs:
        ok &= check(f"ECR {name_of(addr)} en modo MUTABLE",
                    merged[addr].get("image_tag_mutability") == "MUTABLE",
                    str(merged[addr].get("image_tag_mutability")))

    # 3. Compute
    lts = by_type.get("aws_launch_template", [])
    for addr in lts:
        ok &= check(f"Launch template {name_of(addr)} con t4g.small",
                    merged[addr].get("instance_type") == "t4g.small",
                    str(merged[addr].get("instance_type")))
    asgs = by_type.get("aws_autoscaling_group", [])
    ok &= check("1 Auto Scaling Group", len(asgs) == 1, str(len(asgs)))
    for addr in asgs:
        ok &= check(f"ASG {name_of(addr)} con desired_capacity 2",
                    merged[addr].get("desired_capacity") == 2,
                    str(merged[addr].get("desired_capacity")))

    # 4. Balanceador
    albs = by_type.get("aws_lb", [])
    ok &= check("1 ALB", len(albs) == 1, str(len(albs)))

    # 5. Seguridad
    sgs = by_type.get("aws_security_group", [])
    ok &= check("Security groups (ALB/APP/DATA) presentes", len(sgs) >= 3, str(len(sgs)))

    print("\n=== RESUMEN ===")
    print("TODOS LOS CHECKS OK" if ok else "EXISTEN FALLOS EN EL DESPLIEGUE")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()