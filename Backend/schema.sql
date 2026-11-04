CREATE TABLE IF NOT EXISTS pacientes (
    id SERIAL PRIMARY KEY,
    nome_completo TEXT NOT NULL,
    data_nascimento DATE,
    peso DOUBLE PRECISION,
    altura DOUBLE PRECISION,
    cpf TEXT,
    rg TEXT,
    sexo TEXT,
    telefone TEXT,
    email TEXT,
    contato_emergencia_nome TEXT,
    contato_emergencia_telefone TEXT
);

CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    nome_completo TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    senha TEXT NOT NULL,
    perfil TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS avaliacoes_asia (
    id SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    data_exame DATE NOT NULL,
    nome_examinador TEXT NOT NULL,
    contracao_anal_voluntaria TEXT NOT NULL,
    pressao_anal_profunda TEXT NOT NULL,
    lowest_non_key_muscle_right TEXT,
    lowest_non_key_muscle_left TEXT,
    nivel_sensorial_direito TEXT,
    nivel_sensorial_esquerdo TEXT,
    nivel_motor_direito TEXT,
    nivel_motor_esquerdo TEXT,
    nivel_neurologico_lesao TEXT,
    classificacao_completude TEXT,
    escala_asia TEXT,
    zpp_sensorial_direito TEXT,
    zpp_sensorial_esquerdo TEXT,
    zpp_motor_direito TEXT,
    zpp_motor_esquerdo TEXT,
    total_uems_direito INTEGER,
    total_uems_esquerdo INTEGER,
    total_lems_direito INTEGER,
    total_lems_esquerdo INTEGER,
    total_lt_direito INTEGER,
    total_lt_esquerdo INTEGER,
    total_pp_direito INTEGER,
    total_pp_esquerdo INTEGER
);

CREATE TABLE IF NOT EXISTS scores_motores (
    id SERIAL PRIMARY KEY,
    avaliacao_id INTEGER NOT NULL REFERENCES avaliacoes_asia(id) ON DELETE CASCADE,
    miotomo TEXT NOT NULL,
    forca_direita TEXT,
    forca_esquerda TEXT
);

CREATE TABLE IF NOT EXISTS scores_sensoriais (
    id SERIAL PRIMARY KEY,
    avaliacao_id INTEGER NOT NULL REFERENCES avaliacoes_asia(id) ON DELETE CASCADE,
    dermatomo TEXT NOT NULL,
    tato_leve_direito TEXT,
    tato_leve_esquerdo TEXT,
    picada_direito TEXT,
    picada_esquerdo TEXT
);

CREATE TABLE IF NOT EXISTS avaliacoes_gas (
    id SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    data_planejamento DATE,
    data_reavaliacao DATE,
    plano_intervencao TEXT,
    qi TEXT,
    gas_score_base_calculado DOUBLE PRECISION,
    gas_score_alcancado DOUBLE PRECISION,
    evolucao DOUBLE PRECISION,
    somatorio_p1 DOUBLE PRECISION,
    somatorio_p2_pesos DOUBLE PRECISION,
    somatorio_p3_base DOUBLE PRECISION,
    somatorio_p4_alcancado DOUBLE PRECISION
);

CREATE TABLE IF NOT EXISTS metas_gas (
    id SERIAL PRIMARY KEY,
    avaliacao_gas_id INTEGER NOT NULL REFERENCES avaliacoes_gas(id) ON DELETE CASCADE,
    meta_id_original INTEGER,
    descricao TEXT,
    importancia INTEGER,
    dificuldade INTEGER,
    linha_de_base DOUBLE PRECISION,
    alcancado DOUBLE PRECISION,
    ponderacao1 DOUBLE PRECISION,
    ponderacao2_peso DOUBLE PRECISION,
    ponderacao3_base_ponderada DOUBLE PRECISION,
    ponderacao4_alcancado_ponderado DOUBLE PRECISION,
    desc_piora TEXT,
    desc_linha_base TEXT,
    desc_esperado TEXT,
    desc_melhor_esperado TEXT,
    desc_muito_melhor TEXT
);

CREATE TABLE IF NOT EXISTS anamneses (
    id SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    nome_paciente TEXT,
    celular_paciente TEXT,
    email_paciente TEXT,
    data_nascimento DATE,
    data_exame DATE,
    comentarios TEXT
);

CREATE TABLE IF NOT EXISTS avaliacoes_eletrodiagnostico (
    id SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    data_exame DATE,
    nome_examinador TEXT,
    nome_equipamento TEXT
);

CREATE TABLE IF NOT EXISTS medicoes_musculares (
    id SERIAL PRIMARY KEY,
    avaliacao_id INTEGER NOT NULL REFERENCES avaliacoes_eletrodiagnostico(id) ON DELETE CASCADE,
    nome_musculo TEXT,
    reobase_direito DOUBLE PRECISION,
    acomodacao_direito DOUBLE PRECISION,
    cronaxia_direito DOUBLE PRECISION,
    reobase_esquerdo DOUBLE PRECISION,
    acomodacao_esquerdo DOUBLE PRECISION,
    cronaxia_esquerdo DOUBLE PRECISION,
    observacoes TEXT,
    indice_acomodacao_direito TEXT,
    indice_acomodacao_esquerdo TEXT
);

CREATE TABLE IF NOT EXISTS avaliacoes_meem (
    id SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    data_exame DATE,
    nome_examinador TEXT,
    idade_paciente INTEGER,
    escolaridade_paciente TEXT,
    orient_temp_dia_semana INTEGER,
    orient_temp_dia_mes INTEGER,
    orient_temp_mes INTEGER,
    orient_temp_ano INTEGER,
    orient_temp_horas INTEGER,
    orient_esp_local INTEGER,
    orient_esp_edificio INTEGER,
    orient_esp_bairro INTEGER,
    orient_esp_cidade INTEGER,
    orient_esp_estado INTEGER,
    mem_imediata_carro INTEGER,
    mem_imediata_vaso INTEGER,
    mem_imediata_tijolo INTEGER,
    atencao_calc_sub1 INTEGER,
    atencao_calc_sub2 INTEGER,
    atencao_calc_sub3 INTEGER,
    atencao_calc_sub4 INTEGER,
    atencao_calc_sub5 INTEGER,
    mem_evocativa_carro INTEGER,
    mem_evocativa_vaso INTEGER,
    mem_evocativa_tijolo INTEGER,
    ling_nomear_caneta INTEGER,
    ling_nomear_relogio INTEGER,
    ling_repetir_frase INTEGER,
    ling_comando_mao INTEGER,
    ling_comando_dobrar INTEGER,
    ling_comando_chao INTEGER,
    ling_escrita_ler INTEGER,
    ling_escrita_frase INTEGER,
    ling_escrita_copia INTEGER,
    pontuacao_total INTEGER
);

CREATE TABLE IF NOT EXISTS avaliacoes_densitometria (
    id SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    data_exame DATE,
    peso DOUBLE PRECISION,
    altura DOUBLE PRECISION,
    imc DOUBLE PRECISION
);

CREATE TABLE IF NOT EXISTS densitometria_regioes (
    id SERIAL PRIMARY KEY,
    avaliacao_id INTEGER NOT NULL REFERENCES avaliacoes_densitometria(id) ON DELETE CASCADE,
    tipo_secao TEXT NOT NULL,
    regiao TEXT NOT NULL,
    bmd DOUBLE PRECISION
);

CREATE TABLE IF NOT EXISTS densitometria_tendencias (
    id SERIAL PRIMARY KEY,
    avaliacao_id INTEGER NOT NULL REFERENCES avaliacoes_densitometria(id) ON DELETE CASCADE,
    tipo_secao TEXT NOT NULL,
    data_medida DATE,
    idade INTEGER,
    bmd DOUBLE PRECISION,
    tecido_gordura_percent DOUBLE PRECISION,
    massa_total_kg DOUBLE PRECISION,
    gordo_g DOUBLE PRECISION,
    magro_g DOUBLE PRECISION
);
