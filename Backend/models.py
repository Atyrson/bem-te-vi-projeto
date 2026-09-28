from pydantic import BaseModel, EmailStr, StringConstraints
from typing import Annotated, Dict, Optional, List
from datetime import date


MotorValues = Dict[str, str]
SensoryValues = Dict[str, str]

class ExamSide(BaseModel):
    motor: MotorValues
    lightTouch: SensoryValues
    pinPrick: SensoryValues
    lowestNonKeyMuscleWithMotorFunction: Optional[str] = None

class Exam(BaseModel):
    patientName: str
    examDate: str 
    examinerName: str
    right: ExamSide
    left: ExamSide
    voluntaryAnalContraction: str
    deepAnalPressure: str


class Goal(BaseModel):
    id: int
    description: str
    importance: int
    difficulty: int
    baseline: Optional[float] = None
    achieved: Optional[float] = None
    
    level_minus_2: Optional[str] = None
    level_minus_1: Optional[str] = None
    level_0: Optional[str] = None
    level_plus_1: Optional[str] = None
    level_plus_2: Optional[str] = None

class GasEvaluation(BaseModel):
    patientIdentifier: str
    planningDate: Optional[date] = None
    revaluationDate: Optional[date] = None
    interventionPlan: Optional[str] = None
    iq: Optional[str] = None
    goals: List[Goal]

class AnamneseCreate(BaseModel):
    patientName: str
    patientPhone: Optional[str] = None
    patientEmail: Optional[EmailStr] = None
    examDate: date
    birthDate: date
    comments: Optional[str] = None


class MuscleMeasurement(BaseModel):
    """Dados de medição para um lado de um músculo."""
    reobase: Optional[float] = None
    accommodation: Optional[float] = None
    chronaxy: Optional[float] = None
    accommodationIndex: Optional[str] = None

class MuscleEvaluation(BaseModel):
    """Agrupa os dados de um músculo específico."""
    muscleName: str
    right: MuscleMeasurement
    left: MuscleMeasurement
    comments: Optional[str] = None

class ElectrodiagnosisCreate(BaseModel):
    """Modelo principal para receber um novo formulário de Eletrodiagnóstico."""
    patientName: str
    examinerName: str
    examDate: str 
    equipmentName: str
    muscles: List[MuscleEvaluation]

class PontosMeem(BaseModel):
    """Agrupa todos os pontos individuais do exame MEEM."""
    orientacaoTemporal: List[int]
    orientacaoEspacial: List[int]
    memoriaImediata: List[int]
    atencaoCalculo: List[int]
    memoriaEvocativa: List[int]
    linguagemNomear: List[int]
    linguagemRepetir: int
    linguagemComandoVerbal: List[int]
    linguagemComandoEscrito: int
    linguagemFrase: int
    linguagemCopia: int

class MeemCreate(BaseModel):
    """Modelo principal para receber um novo formulário MEEM."""
    patientName: str
    examDate: date
    examinerName: Optional[str] = None
    age: int
    escolaridade: str
    pontos: PontosMeem

class PatientUpdateByName(BaseModel):
    nome_completo: str
    data_nascimento: Optional[date] = None
    peso: Optional[float] = None
    altura: Optional[float] = None
    cpf: Optional[str] = None
    rg: Optional[str] = None
    sexo: Optional[str] = None
    telefone: Optional[str] = None
    email: Optional[EmailStr] = None
    emergencia_nome: Optional[str] = None
    emergencia_telefone: Optional[str] = None

RequiredPatientText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]

class PatientCreate(PatientUpdateByName):
    nome_completo: RequiredPatientText
    data_nascimento: date
    cpf: RequiredPatientText
    sexo: RequiredPatientText

class PatientResponse(BaseModel):
    id: int
    nome_completo: str
    data_nascimento: Optional[date] = None
    peso: Optional[float] = None
    altura: Optional[float] = None
    cpf: Optional[str] = None
    rg: Optional[str] = None
    sexo: Optional[str] = None
    telefone: Optional[str] = None
    email: Optional[EmailStr] = None
    emergencia_nome: Optional[str] = None
    emergencia_telefone: Optional[str] = None

class SignupRequest(BaseModel):
    name: str
    email: str
    password: str
    profile: str 

class LoginRequest(BaseModel):
    email: str
    password: str
    profile: str

class DensityRegion(BaseModel):
    regiao: str
    bmd: float

# Modelo para uma linha de tendência (inclui os campos extras de composição)
class DensityTrend(BaseModel):
    data: str # Recebe como string 'YYYY-MM-DD' ou ISO
    idade: int
    bmd: Optional[float] = None
    # Campos opcionais para a parte de composição corporal
    tecido_percent: Optional[float] = None
    massa_total: Optional[float] = None
    gordo: Optional[float] = None
    magro: Optional[float] = None

# Modelo Principal que agrupa tudo
class DensitometryCreate(BaseModel):
    patientName: str
    examDate: str
    weight: float
    height: float
    imc: float
    
    # Seção 2: Coluna Lombar
    lumbarRegions: List[DensityRegion]
    lumbarTrend: DensityTrend
    
    # Seção 3: Corpo Total
    bodyRegions: List[DensityRegion]
    bodyTrend: DensityTrend
    
    # Seção 3.1: Tendência Composição
    compositionTrend: DensityTrend
    
    # Seção 4: Fêmur Direito
    femurRightRegions: List[DensityRegion]
    femurRightTrend: DensityTrend
    
    # Seção 5: Fêmur Esquerdo
    femurLeftRegions: List[DensityRegion]
    femurLeftTrend: DensityTrend
