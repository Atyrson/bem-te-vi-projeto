-- Migração aditiva da Fase 3: persistência das avaliações CIF.
-- Não altera as tabelas existentes e permite várias avaliações por paciente.

CREATE TABLE IF NOT EXISTS avaliacoes_cif (
    id BIGSERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
    data_avaliacao DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'rascunho'
        CHECK (status IN ('rascunho', 'concluida')),
    catalogo_versao TEXT NOT NULL,
    regras_versao TEXT NOT NULL,
    respostas JSONB NOT NULL DEFAULT '{}'::jsonb,
    resultados JSONB,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    concluido_em TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_avaliacoes_cif_paciente_data
    ON avaliacoes_cif (paciente_id, data_avaliacao DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_avaliacoes_cif_paciente_status
    ON avaliacoes_cif (paciente_id, status);
