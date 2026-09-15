import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:projeto/Core/Constants/appStrings.dart';
import 'package:projeto/Core/Providers/asiaFormProvider.dart';
import 'package:projeto/Core/Providers/cifFormProvider.dart';
import 'package:projeto/Core/Providers/cifHistoryProvider.dart';
import 'package:projeto/Core/Providers/cifComparisonProvider.dart';
import 'package:projeto/Core/Providers/eletroFormProvider.dart';
import 'package:projeto/Core/Providers/meemFormProvider.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:projeto/Presentation/Screens/ananmeseForm.dart';
import 'package:projeto/Presentation/Screens/asiaForm.dart';
import 'package:projeto/Presentation/Screens/cadastro.dart';
import 'package:projeto/Presentation/Screens/cifForm.dart';
import 'package:projeto/Presentation/Screens/cifHistory.dart';
import 'package:projeto/Presentation/Screens/cifComparison.dart';
import 'package:projeto/Presentation/Screens/cifSummary.dart';
import 'package:projeto/Presentation/Screens/dex.dart';
import 'package:projeto/Presentation/Screens/eletroForm.dart';
import 'package:projeto/Presentation/Screens/gasForm.dart';
import 'package:projeto/Presentation/Screens/login.dart';
import 'package:projeto/Presentation/Screens/meemForm.dart';
import 'package:projeto/Presentation/Screens/pacienteCadastro.dart';
import 'package:projeto/Presentation/Screens/pacienteSearch.dart';
import 'package:projeto/Presentation/Screens/selecao.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => PatientProvider()),
        ChangeNotifierProvider(create: (context) => AsiaFormProvider()),
        ChangeNotifierProvider(create: (context) => CifFormProvider()),
        ChangeNotifierProvider(create: (context) => CifHistoryProvider()),
        ChangeNotifierProvider(create: (context) => CifComparisonProvider()),
        ChangeNotifierProvider(create: (context) => MeemFormProvider()),
        ChangeNotifierProvider(create: (context) => MeemFormProvider()),
        ChangeNotifierProvider(
          create: (context) => EletrodiagnosticoProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appTitle,
        theme: ThemeData(
          fontFamily: 'Inter',
          primaryColor: AppColors.emerald,
          scaffoldBackgroundColor: AppColors.background,

          inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(color: Colors.grey.shade600),
            filled: false,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.emerald, width: 2.0),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 4.0,
            ),
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 2,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ),

          datePickerTheme: DatePickerThemeData(
            headerBackgroundColor: AppColors.emerald,
            headerForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),

          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.emerald,
            primary: AppColors.emerald,
            background: AppColors.background,
          ),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pt', 'BR')],
        home: const LoginScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/selecao': (context) => const PatientSelectionScreen(),
          '/pacienteCadastro': (context) => const PatientRegistrationScreen(),
          '/pacienteSearch': (context) => const PatientSearchDialog(),
          '/asia_form': (context) => const AsiaForm(),
          '/cif_form': (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;
            final assessmentId = arguments is int
                ? arguments
                : arguments is Map && arguments['assessmentId'] is int
                ? arguments['assessmentId'] as int
                : null;
            return CifFormScreen(assessmentId: assessmentId);
          },
          '/cif_summary': (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;
            final assessmentId = arguments is int
                ? arguments
                : arguments is Map && arguments['assessmentId'] is int
                ? arguments['assessmentId'] as int
                : arguments is Map && arguments['assessment_id'] is int
                ? arguments['assessment_id'] as int
                : null;
            return CifSummaryScreen(assessmentId: assessmentId);
          },
          '/cif_history': (context) => const CifHistoryScreen(),
          '/cif_comparison': (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;
            final firstAssessmentId =
                arguments is Map && arguments['firstAssessmentId'] is int
                ? arguments['firstAssessmentId'] as int
                : arguments is Map && arguments['first_assessment_id'] is int
                ? arguments['first_assessment_id'] as int
                : null;
            final secondAssessmentId =
                arguments is Map && arguments['secondAssessmentId'] is int
                ? arguments['secondAssessmentId'] as int
                : arguments is Map && arguments['second_assessment_id'] is int
                ? arguments['second_assessment_id'] as int
                : null;
            return CifComparisonScreen(
              firstAssessmentId: firstAssessmentId,
              secondAssessmentId: secondAssessmentId,
            );
          },
          '/gas_form': (context) => const GasForm(),
          '/anmenese_form': (context) => const AnmeneseForm(),
          '/meem_form': (context) => const MeemFormScreen(),
          '/eletro_form': (context) => const EletrodiagnosticoScreen(),
          '/dex_form': (context) => const DensitometryFormPage(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
