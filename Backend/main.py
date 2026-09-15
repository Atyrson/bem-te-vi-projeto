from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
import psycopg2
from models import AnamneseCreate, Exam, GasEvaluation
from asiaCalculator import PraxisIscnsciCalculator
from gasCalculator import GasCalculator
from database import get_db_connection
from models import AnamneseCreate, Exam, GasEvaluation, ElectrodiagnosisCreate, MeemCreate
from pydantic import BaseModel
from typing import List

from models import (
    AnamneseCreate, 
    Exam, 
    GasEvaluation, 
    ElectrodiagnosisCreate, 
    MeemCreate, 
    PatientCreate, 
    PatientResponse,
    SignupRequest,
    LoginRequest,
    DensitometryCreate
)
from cif_api import router as cif_router

app = FastAPI(title="Bem-Te-Vi API", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(cif_router)

@app.get("/")
def read_root():
    return {"Status": "Servidor do Bem-te-vi no ar!"}

@app.post("/api/v1/gas-evaluations", summary="Calcula e Salva uma Avaliação GAS")
def create_gas_evaluation(eval_data: GasEvaluation):
    calculator = GasCalculator(eval_data)
    result = calculator.calculate_all()
    summary = result['summary'] 

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT id FROM pacientes WHERE nome_completo = %s;", (eval_data.patientIdentifier,))
        patient = cursor.fetchone()

        if patient:
            patient_id = patient[0]
        else:
            cursor.execute("INSERT INTO pacientes (nome_completo) VALUES (%s) RETURNING id;", (eval_data.patientIdentifier,))
            patient_id = cursor.fetchone()[0]

        cursor.execute(
            """
            INSERT INTO avaliacoes_gas (
                paciente_id, data_planejamento, data_reavaliacao, plano_intervencao, qi,
                gas_score_base_calculado, gas_score_alcancado, evolucao,
                somatorio_p1, somatorio_p2_pesos, somatorio_p3_base, somatorio_p4_alcancado
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id;
            """,
            (
                patient_id, eval_data.planningDate, eval_data.revaluationDate,
                eval_data.interventionPlan, eval_data.iq,
                summary['gasScoreBase'], summary['gasScoreAchieved'], summary['evolution'],
                summary['somatorioP1'], summary['somatorioP2'],
                summary['somatorioP3'], summary['somatorioP4']
            )
        )
        avaliacao_id = cursor.fetchone()[0]

        for goal_data in result['detailed_goals']:
            raw_goal = goal_data['raw_goal']

            print("CHAVES DISPONÍVEIS NO DICIONÁRIO:", goal_data.keys())
            
            cursor.execute(
                """
                INSERT INTO metas_gas (
                    avaliacao_gas_id, meta_id_original, descricao, importancia, dificuldade,
                    linha_de_base, alcancado, ponderacao1, ponderacao2_peso,
                    ponderacao3_base_ponderada, ponderacao4_alcancado_ponderado,
                    desc_piora, desc_linha_base, desc_esperado, 
                    desc_melhor_esperado, desc_muito_melhor
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
                """,
                (
                    avaliacao_id, raw_goal.id, raw_goal.description, raw_goal.importance, raw_goal.difficulty,
                    raw_goal.baseline, raw_goal.achieved,
                    goal_data['ponderation1'],
                    goal_data['ponderation2_peso'],
                    goal_data['ponderation3_base_ponderada'],
                    goal_data['ponderacao4_alcancado_ponderado'],
                    raw_goal.level_minus_2, raw_goal.level_minus_1, raw_goal.level_0,
                    raw_goal.level_plus_1, raw_goal.level_plus_2
                )
            )

        conn.commit()
        print(f"SUCESSO: Avaliação GAS ID {avaliacao_id} salva para o Paciente ID {patient_id}.")

    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO DE BANCO DE DADOS: {error}")
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail="Erro ao salvar avaliação GAS no banco de dados.")
    finally:
        if conn:
            cursor.close()
            conn.close()

    return result


@app.post("/api/v1/exams", summary="Calcula e Salva uma Avaliação ASIA")
def create_exam_and_calculate(exam_data: Exam):
    calculator = PraxisIscnsciCalculator(exam_data)
    result = calculator.calculate()

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT id FROM pacientes WHERE nome_completo = %s;", (exam_data.patientName,))
        paciente = cursor.fetchone()
        if paciente:
            paciente_id = paciente[0]
        else:
            cursor.execute("INSERT INTO pacientes (nome_completo) VALUES (%s) RETURNING id;", (exam_data.patientName,))
            paciente_id = cursor.fetchone()[0]

        classificacao = result['classification']
        totais = result['totals']
        zpp = classificacao['zoneOfPartialPreservations']
        neuro_levels = classificacao['neurologicalLevels']
        
        cursor.execute(
            """
            INSERT INTO avaliacoes_asia (
                paciente_id, data_exame, nome_examinador, 
                contracao_anal_voluntaria, pressao_anal_profunda,
                lowest_non_key_muscle_right, lowest_non_key_muscle_left,
                nivel_sensorial_direito, nivel_sensorial_esquerdo, nivel_motor_direito, nivel_motor_esquerdo,
                nivel_neurologico_lesao, classificacao_completude, escala_asia,
                zpp_sensorial_direito, zpp_sensorial_esquerdo, zpp_motor_direito, zpp_motor_esquerdo,
                total_uems_direito, total_uems_esquerdo, total_lems_direito, total_lems_esquerdo,
                total_lt_direito, total_lt_esquerdo, total_pp_direito, total_pp_esquerdo
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id;
            """,
            (
                paciente_id,
                exam_data.examDate,
                exam_data.examinerName,   
                exam_data.voluntaryAnalContraction,
                exam_data.deepAnalPressure,
                exam_data.right.lowestNonKeyMuscleWithMotorFunction,
                exam_data.left.lowestNonKeyMuscleWithMotorFunction,
                neuro_levels['sensoryRight'],
                neuro_levels['sensoryLeft'],
                neuro_levels['motorRight'],
                neuro_levels['motorLeft'],
                classificacao['neurologicalLevelOfInjury'],
                'Completa' if 'C' in classificacao['injuryComplete'] else 'Incompleta', 
                classificacao['asiaImpairmentScale'],
                zpp['sensoryRight'],
                zpp['sensoryLeft'], 
                zpp['motorRight'],
                zpp['motorLeft'],  
                None if totais['upperExtremityRight'] == 'ND' else totais['upperExtremityRight'], 
                None if totais['upperExtremityLeft'] == 'ND' else totais['upperExtremityLeft'],
                None if totais['lowerExtremityRight'] == 'ND' else totais['lowerExtremityRight'], 
                None if totais['lowerExtremityLeft'] == 'ND' else totais['lowerExtremityLeft'],
                None if totais['lightTouchRight'] == 'ND' else totais['lightTouchRight'], 
                None if totais['lightTouchLeft'] == 'ND' else totais['lightTouchLeft'],   
                None if totais['pinPrickRight'] == 'ND' else totais['pinPrickRight'],         
                None if totais['pinPrickLeft'] == 'ND' else totais['pinPrickLeft'],       
            )
        )
        avaliacao_id = cursor.fetchone()[0]

        for miotomo in calculator._motor_levels:
            cursor.execute("INSERT INTO scores_motores (avaliacao_id, miotomo, forca_direita, forca_esquerda) VALUES (%s, %s, %s, %s);", (avaliacao_id, miotomo, exam_data.right.motor.get(miotomo, ''), exam_data.left.motor.get(miotomo, '')))

        for dermatomo in calculator._sensory_levels:
            cursor.execute("INSERT INTO scores_sensoriais (avaliacao_id, dermatomo, tato_leve_direito, tato_leve_esquerdo, picada_direito, picada_esquerdo) VALUES (%s, %s, %s, %s, %s, %s);", (avaliacao_id, dermatomo, exam_data.right.lightTouch.get(dermatomo, ''), exam_data.left.lightTouch.get(dermatomo, ''), exam_data.right.pinPrick.get(dermatomo, ''), exam_data.left.pinPrick.get(dermatomo, '')))
        
        conn.commit()
        print(f"SUCESSO: Avaliação ASIA ID {avaliacao_id} salva no banco de dados para o Paciente ID {paciente_id}.")

    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO DE BANCO DE DADOS: {error}")
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail="Erro interno ao salvar os dados da avaliação ASIA.")
    finally:
        if conn:
            cursor.close()
            conn.close()

    return result

@app.post("/api/v1/anamneses", summary="Salva um novo formulário de Anamnese", status_code=status.HTTP_201_CREATED)
def create_anamnese(anamnese: AnamneseCreate):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT id FROM pacientes WHERE nome_completo = %s;", (anamnese.patientName,))
        paciente = cursor.fetchone()

        if paciente:
            paciente_id = paciente[0]
        else:
            cursor.execute("INSERT INTO pacientes (nome_completo) VALUES (%s) RETURNING id;", (anamnese.patientName,))
            paciente_id = cursor.fetchone()[0]

        sql = """
            INSERT INTO anamneses (
                paciente_id, nome_paciente, celular_paciente, email_paciente,
                data_nascimento, data_exame, comentarios
            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING id;
        """
        
        cursor.execute(sql, (
            paciente_id,
            anamnese.patientName,
            anamnese.patientPhone,
            anamnese.patientEmail,
            anamnese.birthDate,
            anamnese.examDate,
            anamnese.comments
        ))
        
        new_id = cursor.fetchone()[0]
        conn.commit()
        
        print(f"SUCESSO: Anamnese ID {new_id} salva para o Paciente ID {paciente_id}.")

    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO DE BANCO DE DADOS (Anamnese): {error}")
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail="Erro ao salvar anamnese no banco de dados.")
    finally:
        if conn:
            cursor.close()
            conn.close()

    return {"message": "Anamnese salva com sucesso!", "id": new_id, "paciente_id": paciente_id}

@app.post("/api/v1/electrodiagnosis", summary="Salva um novo formulário de Eletrodiagnóstico", status_code=status.HTTP_201_CREATED)
def create_electrodiagnosis(electro_data: ElectrodiagnosisCreate):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT id FROM pacientes WHERE nome_completo = %s;", (electro_data.patientName,))
        paciente = cursor.fetchone()

        if paciente:
            paciente_id = paciente[0]
        else:
            cursor.execute("INSERT INTO pacientes (nome_completo) VALUES (%s) RETURNING id;", (electro_data.patientName,))
            paciente_id = cursor.fetchone()[0]

        sql_avaliacao = """
            INSERT INTO avaliacoes_eletrodiagnostico (
                paciente_id, data_exame, nome_examinador, nome_equipamento
            ) VALUES (%s, %s, %s, %s)
            RETURNING id;
        """
        cursor.execute(sql_avaliacao, (
            paciente_id,
            electro_data.examDate,
            electro_data.examinerName,
            electro_data.equipmentName
        ))
        avaliacao_id = cursor.fetchone()[0]


        sql_medicao = """
            INSERT INTO medicoes_musculares (
                avaliacao_id, nome_musculo,
                reobase_direito, acomodacao_direito, cronaxia_direito,
                reobase_esquerdo, acomodacao_esquerdo, cronaxia_esquerdo,
                observacoes,
                indice_acomodacao_direito,
                indice_acomodacao_esquerdo
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
        """

        for muscle in electro_data.muscles:

            cursor.execute(sql_medicao, (
                avaliacao_id,                
                muscle.muscleName,              
                muscle.right.reobase,         
                muscle.right.accommodation,    
                muscle.right.chronaxy,         
                muscle.left.reobase,            
                muscle.left.accommodation,      
                muscle.left.chronaxy,          
                muscle.comments,              
                muscle.right.accommodationIndex,  
                muscle.left.accommodationIndex    
            ))

        conn.commit()
        print(f"SUCESSO: Eletrodiagnostico ID {avaliacao_id} salvo para o Paciente ID {paciente_id}.")

    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO DE BANCO DE DADOS (Eletrodiagnóstico): {error}")
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail="Erro ao salvar eletrodiagnóstico no banco de dados.")
    finally:
        if conn:
            cursor.close()
            conn.close()

    return {"message": "Eletrodiagnóstico salvo com sucesso!", "id": avaliacao_id, "paciente_id": paciente_id}

@app.post("/api/v1/meem-evaluations", summary="Salva um novo formulário MEEM", status_code=status.HTTP_201_CREATED)
def create_meem_evaluation(meem_data: MeemCreate):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT id FROM pacientes WHERE nome_completo = %s;", (meem_data.patientName,))
        paciente = cursor.fetchone()

        if paciente:
            paciente_id = paciente[0]
        else:
            cursor.execute("INSERT INTO pacientes (nome_completo) VALUES (%s) RETURNING id;", (meem_data.patientName,))
            paciente_id = cursor.fetchone()[0]

        pontos = meem_data.pontos
        total_score = (
            sum(pontos.orientacaoTemporal) +
            sum(pontos.orientacaoEspacial) +
            sum(pontos.memoriaImediata) +
            sum(pontos.atencaoCalculo) +
            sum(pontos.memoriaEvocativa) +
            sum(pontos.linguagemNomear) +
            pontos.linguagemRepetir +
            sum(pontos.linguagemComandoVerbal) +
            pontos.linguagemComandoEscrito +
            pontos.linguagemFrase +
            pontos.linguagemCopia
        )
        
        sql = """
            INSERT INTO avaliacoes_meem (
                paciente_id, data_exame, nome_examinador, idade_paciente, escolaridade_paciente,
                orient_temp_dia_semana, orient_temp_dia_mes, orient_temp_mes, orient_temp_ano, orient_temp_horas,
                orient_esp_local, orient_esp_edificio, orient_esp_bairro, orient_esp_cidade, orient_esp_estado,
                mem_imediata_carro, mem_imediata_vaso, mem_imediata_tijolo,
                atencao_calc_sub1, atencao_calc_sub2, atencao_calc_sub3, atencao_calc_sub4, atencao_calc_sub5,
                mem_evocativa_carro, mem_evocativa_vaso, mem_evocativa_tijolo,
                ling_nomear_caneta, ling_nomear_relogio, ling_repetir_frase,
                ling_comando_mao, ling_comando_dobrar, ling_comando_chao,
                ling_escrita_ler, ling_escrita_frase, ling_escrita_copia,
                pontuacao_total
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id;
        """
        
        cursor.execute(sql, (
            paciente_id, meem_data.examDate, meem_data.examinerName, meem_data.age, meem_data.escolaridade,
            *pontos.orientacaoTemporal,
            *pontos.orientacaoEspacial,
            *pontos.memoriaImediata,
            *pontos.atencaoCalculo,
            *pontos.memoriaEvocativa,
            *pontos.linguagemNomear,
            pontos.linguagemRepetir,
            *pontos.linguagemComandoVerbal,
            pontos.linguagemComandoEscrito,
            pontos.linguagemFrase,
            pontos.linguagemCopia,
            total_score
        ))
        
        new_id = cursor.fetchone()[0]
        conn.commit()
        
        print(f"SUCESSO: Avaliação MEEM ID {new_id} salva para o Paciente ID {paciente_id}.")

    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO DE BANCO DE DADOS (MEEM): {error}")
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail="Erro ao salvar avaliação MEEM no banco de dados.")
    finally:
        if conn:
            cursor.close()
            conn.close()

    return {"message": "Avaliação MEEM salva com sucesso!", "id": new_id, "paciente_id": paciente_id}

@app.post("/api/v1/register", summary="Cadastra um novo usuário (Fisio, Estagiário ou Paciente)", status_code=status.HTTP_201_CREATED)
def register_user(user_data: SignupRequest):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Verifica se o email já existe
        cursor.execute("SELECT id FROM usuarios WHERE email = %s;", (user_data.email,))
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="Este email já está em uso.")

        # 2. Insere o novo usuário
        query = """
            INSERT INTO usuarios (nome_completo, email, senha, perfil)
            VALUES (%s, %s, %s, %s) RETURNING id;
        """
        cursor.execute(query, (
            user_data.name, 
            user_data.email, 
            user_data.password, # OBS: Em produção, use hash (bcrypt) aqui!
            user_data.profile
        ))
        
        new_id = cursor.fetchone()[0]
        conn.commit()

        print(f"NOVO USUÁRIO: {user_data.name} ({user_data.profile}) cadastrado com sucesso.")
        return {"message": "Cadastro realizado com sucesso!", "user_id": new_id}

    except HTTPException as he:
        raise he # Repassa erros de validação (email duplicado)
    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO NO CADASTRO: {error}")
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail="Erro interno ao cadastrar usuário.")
    finally:
        if conn:
            cursor.close()
            conn.close()


# --- ENDPOINT: LOGIN ---
@app.post("/api/v1/login", summary="Realiza login via Email e Perfil")
def login_user(login_data: LoginRequest):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Busca usuário que combine Email + Senha + Perfil
        query = """
            SELECT id, nome_completo, perfil FROM usuarios 
            WHERE email = %s AND senha = %s AND perfil = %s;
        """
        cursor.execute(query, (login_data.email, login_data.password, login_data.profile))
        user = cursor.fetchone()

        if user:
            return {
                "status": "success",
                "message": "Login realizado com sucesso",
                "user_id": user[0],
                "nome": user[1],
                "perfil": user[2]
            }
        else:
            # Se não achar, retorna erro 401 (Não autorizado)
            raise HTTPException(status_code=401, detail="Email, senha ou perfil incorretos.")

    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO NO LOGIN: {error}")
        raise HTTPException(status_code=500, detail="Erro interno no servidor.")
    finally:
        if conn:
            cursor.close()
            conn.close()


@app.post("/api/v1/patients", summary="Cadastra um novo paciente com dados completos", status_code=status.HTTP_201_CREATED)
def create_patient(patient: PatientCreate):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Opcional: Verificar se CPF já existe antes de inserir
        if patient.cpf:
            cursor.execute("SELECT id FROM pacientes WHERE cpf = %s;", (patient.cpf,))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Já existe um paciente com este CPF.")

        query = """
            INSERT INTO pacientes (
                nome_completo, data_nascimento, peso, altura, cpf, rg, sexo, 
                telefone, email, contato_emergencia_nome, contato_emergencia_telefone
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id;
        """
        
        cursor.execute(query, (
            patient.nome_completo,
            patient.data_nascimento,
            patient.peso,
            patient.altura,
            patient.cpf,
            patient.rg,
            patient.sexo,
            patient.telefone,
            patient.email,
            patient.emergencia_nome,
            patient.emergencia_telefone
        ))
        
        new_id = cursor.fetchone()[0]
        conn.commit()
        
        print(f"PACIENTE CADASTRADO: {patient.nome_completo} ID: {new_id}")
        return {"message": "Paciente cadastrado com sucesso!", "id": new_id}

    except HTTPException as he:
        raise he
    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO AO CADASTRAR PACIENTE: {error}")
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail="Erro ao salvar paciente.")
    finally:
        if conn:
            cursor.close()
            conn.close()

# --- ENDPOINT: BUSCAR TODOS OS PACIENTES ---
@app.get("/api/v1/patients", response_model=List[PatientResponse], summary="Lista todos os pacientes cadastrados")
def get_all_patients():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # --- CORREÇÃO AQUI: Selecionar TODAS as colunas necessárias ---
        query = """
            SELECT 
                id, 
                nome_completo, 
                data_nascimento, 
                peso, 
                altura, 
                cpf, 
                rg, 
                sexo, 
                telefone, 
                email, 
                contato_emergencia_nome, 
                contato_emergencia_telefone
            FROM pacientes 
            ORDER BY nome_completo ASC;
        """
        cursor.execute(query)
        rows = cursor.fetchall()

        patients_list = []
        for row in rows:
            # Mapear cada coluna para o campo certo do JSON
            patients_list.append({
                "id": row[0],
                "nome_completo": row[1],
                "data_nascimento": row[2],
                "peso": row[3],
                "altura": row[4],
                "cpf": row[5],
                "rg": row[6],
                "sexo": row[7],
                "telefone": row[8],
                "email": row[9],
                "emergencia_nome": row[10],
                "emergencia_telefone": row[11]
            })

        return patients_list

    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO AO BUSCAR PACIENTES: {error}")
        raise HTTPException(status_code=500, detail="Erro ao buscar lista de pacientes.")
    finally:
        if conn:
            cursor.close()
            conn.close()

@app.put("/api/v1/patients/update-by-name", summary="Atualiza dados de um paciente buscando pelo nome")
def update_patient_by_name(patient_data: PatientCreate):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Verifica se o paciente existe pelo nome
        cursor.execute("SELECT id FROM pacientes WHERE nome_completo = %s;", (patient_data.nome_completo,))
        record = cursor.fetchone()

        if not record:
            raise HTTPException(status_code=404, detail=f"Paciente '{patient_data.nome_completo}' não encontrado.")

        patient_id = record[0]

        # 2. Atualiza os dados
        query = """
            UPDATE pacientes 
            SET 
                data_nascimento = %s,
                peso = %s,
                altura = %s,
                cpf = %s,
                rg = %s,
                sexo = %s,
                telefone = %s,
                email = %s,
                contato_emergencia_nome = %s,
                contato_emergencia_telefone = %s
            WHERE id = %s;
        """
        
        cursor.execute(query, (
            patient_data.data_nascimento,
            patient_data.peso,
            patient_data.altura,
            patient_data.cpf,
            patient_data.rg,
            patient_data.sexo,
            patient_data.telefone,
            patient_data.email,
            patient_data.emergencia_nome,
            patient_data.emergencia_telefone,
            patient_id
        ))
        
        conn.commit()
        print(f"PACIENTE ATUALIZADO: {patient_data.nome_completo}")
        return {"message": "Dados atualizados com sucesso!", "id": patient_id}

    except HTTPException as he:
        raise he
    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO AO ATUALIZAR PACIENTE: {error}")
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail="Erro ao atualizar paciente.")
    finally:
        if conn:
            cursor.close()
            conn.close()

@app.post("/api/v1/densitometry", summary="Salva formulário de Densitometria Óssea", status_code=status.HTTP_201_CREATED)
def create_densitometry(data: DensitometryCreate):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Busca ou Cria o Paciente
        cursor.execute("SELECT id FROM pacientes WHERE nome_completo = %s;", (data.patientName,))
        paciente = cursor.fetchone()

        if paciente:
            paciente_id = paciente[0]
        else:
            cursor.execute("INSERT INTO pacientes (nome_completo) VALUES (%s) RETURNING id;", (data.patientName,))
            paciente_id = cursor.fetchone()[0]

        # 2. Insere a Avaliação Principal (Pai)
        sql_main = """
            INSERT INTO avaliacoes_densitometria (
                paciente_id, data_exame, peso, altura, imc
            ) VALUES (%s, %s, %s, %s, %s) RETURNING id;
        """
        cursor.execute(sql_main, (
            paciente_id, data.examDate, data.weight, data.height, data.imc
        ))
        avaliacao_id = cursor.fetchone()[0]

        # 3. Função Auxiliar para inserir Regiões (Tabelas de cima)
        def insert_regions(regions_list, tipo_secao):
            sql_reg = "INSERT INTO densitometria_regioes (avaliacao_id, tipo_secao, regiao, bmd) VALUES (%s, %s, %s, %s);"
            for item in regions_list:
                cursor.execute(sql_reg, (avaliacao_id, tipo_secao, item.regiao, item.bmd))

        # 4. Função Auxiliar para inserir Tendências (Tabelas de baixo)
        def insert_trend(trend_data, tipo_secao):
            sql_trend = """
                INSERT INTO densitometria_tendencias (
                    avaliacao_id, tipo_secao, data_medida, idade, bmd,
                    tecido_gordura_percent, massa_total_kg, gordo_g, magro_g
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);
            """
            cursor.execute(sql_trend, (
                avaliacao_id, tipo_secao, trend_data.data, trend_data.idade, trend_data.bmd,
                trend_data.tecido_percent, trend_data.massa_total, trend_data.gordo, trend_data.magro
            ))

        # --- INSERINDO OS DADOS ---
        
        # Coluna Lombar
        insert_regions(data.lumbarRegions, 'LOMBAR')
        insert_trend(data.lumbarTrend, 'LOMBAR_TREND')

        # Corpo Total
        insert_regions(data.bodyRegions, 'CORPO_TOTAL')
        insert_trend(data.bodyTrend, 'CORPO_TOTAL_TREND')

        # Composição Corporal (Só tem tendência)
        insert_trend(data.compositionTrend, 'COMPOSICAO_TREND')

        # Fêmur Direito
        insert_regions(data.femurRightRegions, 'FEMUR_DIR')
        insert_trend(data.femurRightTrend, 'FEMUR_DIR_TREND')

        # Fêmur Esquerdo
        insert_regions(data.femurLeftRegions, 'FEMUR_ESQ')
        insert_trend(data.femurLeftTrend, 'FEMUR_ESQ_TREND')

        conn.commit()
        print(f"SUCESSO: Densitometria ID {avaliacao_id} salva para {data.patientName}.")
        return {"message": "Exame salvo com sucesso!", "id": avaliacao_id}

    except (Exception, psycopg2.DatabaseError) as error:
        print(f"ERRO DE BANCO DE DADOS (Densitometria): {error}")
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail=f"Erro ao salvar densitometria: {str(error)}")
    finally:
        if conn:
            cursor.close()
            conn.close()
