#!/usr/bin/env python3
import subprocess
import sys
import os

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))

def run_script(nome, descricao):
    print(f"\n{'='*60}")
    print(f"▶ {descricao}...")
    print(f"{'='*60}")
    caminho = os.path.join(BACKEND_DIR, nome)
    result = subprocess.run([sys.executable, caminho], cwd=BACKEND_DIR)
    if result.returncode != 0:
        print(f"✘ ERRO: {descricao} falhou (código {result.returncode}). Abortando.")
        sys.exit(result.returncode)
    print(f"✔ {descricao} concluído.")

def main():
    print(f"{'='*60}")
    print("  ORQUESTRADOR — Bem-Te-Vi Database Setup")
    print(f"{'='*60}")

    run_script("criar_tabelas.py", "Criar/verificar tabelas no banco")
    run_script("corrigir_cpfs.py", "Corrigir CPFs/RGs duplicados")
    run_script("seed_usuarios.py", "Criar usuários de teste")
    run_script("gerador_dados.py", "Gerar dados de exames ASIA e GAS")
    run_script("enviar_dados.py", "Enviar ASIA e GAS para a API (25 pacientes fake)")
    run_script("enviar_densitometria.py", "Enviar Densitometria para a API (25 pacientes fixos)")
    run_script("atualizar_pacientes.py", "Atualizar dados completos dos 25 pacientes fixos")
    run_script("popula_novas_tabelas.py", "Enviar MEEM e Eletrodiagnóstico para todos os pacientes")

    print(f"\n{'='*60}")
    print("  ✔ POPULAÇÃO CONCLUÍDA!")
    print(f"{'='*60}")
    print()
    print("Usuários de teste criados:")
    print("  admin@bemtevi.com / admin123  (admin)")
    print("  fisio@bemtevi.com / fisio123  (fisioterapeuta)")
    print("  estagiario@bemtevi.com / estag123  (estagiario)")
    print()
    print("Para exportar os dados para CSV:")
    print("  python exportar_dados.py")

if __name__ == "__main__":
    main()
