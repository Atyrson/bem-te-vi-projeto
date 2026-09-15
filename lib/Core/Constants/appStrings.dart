import 'dart:ui';

class AppStrings {
  static const String appTitle = 'Bem-Te-Vi';

  // Drawer
  static const String formAsia = 'ASIA';
  static const String formGas = 'GAS';
  static const String formAnmenese = 'Anamnese';

  // ASIA form
  static const String asiaFormTitle = 'Classificação ISNCSCI (ASIA)';
  static const String motorLabel = 'Motor';
  static const String sensoryLabel = 'Sensorial';
  static const String keyMusclesLabel = 'Músculos-chave';
  static const String keySensoryPointsLabel = 'Pontos Sensoriais-chave';
  static const String lightTouchLabel = 'Toque Leve (TL)';
  static const String pinPrickLabel = 'Estímulo com agulha (EA)';
  static const String rightSideLabel = 'Direita';
  static const String leftSideLabel = 'Esquerda';
  static const String totalsLabelRight = 'DIREITA TOTAIS';
  static const String totalsLabelLeft = 'ESQUERDA TOTAIS';
  static const String maximumLabel = '(Máximo)';
  static const String vacLabel = '(VAC) Contração Anal Voluntária';
  static const String dapLabel = '(DAP) Pressão Anal Profunda';
  static const String vacYes = 'Sim';
  static const String vacNo = 'Não';
  static const String vacNt = 'NT';

  // Subscores
  static const String motorSubscoresTitle = 'Escore Motor';
  static const String sensorySubscoresTitle = 'Escore Sensitivo';
  static const String uerLabel = 'ES Direita'; // Upper Extremity Right
  static const String uelLabel = 'ES Esquerda'; // Upper Extremity Left
  static const String lerLabel = 'EI Direita'; // Lower Extremity Right
  static const String lelLabel = 'EI Esquerda'; // Lower Extremity Left
  static const String uemsTotal = '= Total ES'; // Upper Extremity Motor Score
  static const String lemsTotal = '= Total EI'; // Lower Extremity Motor Score
  static const String ltTotal = '= TL Total'; // Light Touch Total
  static const String ppTotal = '= EA Total'; // Pin Prick Total

  // Totals Section
  static const String neurologicalLevelsTitle = 'Níveis Neurológicos';
  static const String neurologicalLevelsHelper =
      'Passos 1-6 para classificação';
  static const String sensoryTotalStep = '1. Sensorial';
  static const String motorTotalStep = '2. Motor';
  static const String nliTitle = '3. Nível Neurológico da Lesão (NNL)';
  static const String completenessTitle = '4. Completo ou Incompleto?';
  static const String completenessHelper =
      'Incompleto = Qualquer função sensorial ou motora em S4-5';
  static const String aisTitle = '5. Escala de Deficiência ASIA (AIS)';
  static const String zppTitle = '6. Zona de Preservação Parcial';
  static const String zppHelper = 'Nível mais caudal com qualquer inervação';

  static const List<String> motorLevels = [
    'C5',
    'C6',
    'C7',
    'C8',
    'T1',
    'L2',
    'L3',
    'L4',
    'L5',
    'S1',
  ];

  static const List<String> sensoryLevels = [
    'C2',
    'C3',
    'C4',
    'C5',
    'C6',
    'C7',
    'C8',
    'T1',
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'T8',
    'T9',
    'T10',
    'T11',
    'T12',
    'L1',
    'L2',
    'L3',
    'L4',
    'L5',
    'S1',
    'S2',
    'S3',
    'S4-5',
  ];

  static const Map<String, String> motorHelpers = {
    'C5': 'Flexor do cotovelo',
    'C6': 'Extensor do punho',
    'C7': 'Extensores do cotovelo',
    'C8': 'Flexores dos dedos',
    'T1': 'Abdutores dos dedos',
    'L2': 'Flexores do quadril',
    'L3': 'Extensores do joelho',
    'L4': 'Dorsiflexores do tornozelo',
    'L5': 'Extensores longo do hálux',
    'S1': 'Flexores plantares do tornozelo',
  };

  static const List<String> analSensationOptions = [vacYes, vacNo, vacNt];

  static const Map<String, String> lowestNonKeyMuscleOptions = {
    '0': 'Nenhum',
    '4':
        'C5 - Ombro: Flexão, extensão, abdução, adução, rotação interna e externa - Cotovelo: Supinação',
    '5': 'C6 - Cotovelo: Pronação - Punho: Flexão',
    '6':
        'C7 - Dedo: Flexão na articulação proximal, extensão. Polegar: Flexão, extensão e abdução no plano do polegar',
    '7':
        'C8 - Dedo: Flexão na articulação MCF Polegar: Oposição, adução e abdução perpendicular à palma',
    '8': 'T1 - Dedo: Abdução do dedo indicador',
    '21': 'L2 - Quadril: Adução',
    '22': 'L3 - Quadril: Rotação externa',
    '23':
        'L4 - Quadril: Extensão, abdução, rotação interna - Joelho: Flexão - Tornozelo: Inversão e eversão - Dedo do pé: Extensão MP e IP',
    '24': 'L5 - Hálux e Dedo do pé: Flexão e abdução DIP e PIP',
    '25': 'S1 - Hálux: Adução',
  };

  // GAS form
  static const String gasFormTitle0 = 'GAS';
  static const String gasFormTitle1 =
      'PROSPECÇÃO E CUMPRIMENTO DE PLANO DE INTERVENÇÃO';
  static const String gasFormTitle2 = 'DESCRITIVO DO ALCANCE DE METAS';

  // Caption card
  static const String captionTitle = 'Legenda de Pondereção';
  static const String captionZero = 'Nenhuma';
  static const String captionOne = 'Fraca';
  static const String captionTwo = 'Muita';
  static const String captionThree = 'Extrema';

  // Organização das metas
  static const String mainCategory1 = 'Fisioprofilaxia';
  static const String mainCategory2 = 'Fisioterapia';
  static const String secundaryCategory0 = 'Direcionadora';
  static const String secundaryCategory1 = 'Aprimoramento de atividade';
  static const String secundaryCategory2 = 'Consolidação de participação';
  static const String secundaryCategory3 =
      'Aprimoramento das funções do corpo ';
  static const String secundaryCategory4 = 'Efetividade de estruturas do corpo';
  static const String secundaryCategory5 = 'Prevenção de dor e desconforto';
  static const String secundaryCategory6 = 'Dispositivos assistivos em uso';
  static const String secundaryCategory7 = 'Combate à limitação em atividade';
  static const String secundaryCategory8 =
      'Eliminação de restrição à participação';
  static const String secundaryCategory9 = 'Recuperação de funções do corpo ';
  static const String secundaryCategory10 = 'Adaptação de estruturas do corpo';
  static const String secundaryCategory11 = 'Alívio de dor e desconforto';
  static const String secundaryCategory12 = 'Adaptação ambiental';

  // Formulário anmenese
  static const anmeneseTitle = 'Formulário de Anamnese';

  // Formulário MEEM
}

class AppColors {
  static const Color emerald = Color.fromARGB(255, 80, 200, 120);
  static const Color greenSecundary = Color.fromARGB(255, 6, 190, 123);
  static const Color background = Color(0xFFF8F9FA);
}
