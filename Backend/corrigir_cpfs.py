import json
import random

ARQUIVO = 'dados_pacientes.json'

def gerar_cpf_unico(usados):
    while True:
        cpf = f"{random.randint(100, 999)}.{random.randint(100, 999)}.{random.randint(100, 999)}-{random.randint(10, 99)}"
        if cpf not in usados:
            usados.add(cpf)
            return cpf

def gerar_rg_unico(usados):
    while True:
        rg = ''.join(random.choices('0123456789', k=9))
        if rg not in usados:
            usados.add(rg)
            return rg

with open(ARQUIVO, 'r', encoding='utf-8') as f:
    pacientes = json.load(f)

cpfs_usados = set()
rgs_usados = set()

for p in pacientes:
    p['cpf'] = gerar_cpf_unico(cpfs_usados)
    p['rg'] = gerar_rg_unico(rgs_usados)

with open(ARQUIVO, 'w', encoding='utf-8') as f:
    json.dump(pacientes, f, indent=2, ensure_ascii=False)

print(f"CPFs e RGs corrigidos para {len(pacientes)} pacientes.")
