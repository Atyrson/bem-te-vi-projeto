import 'package:flutter/material.dart';
import 'package:projeto/Core/Constants/appStrings.dart';
import 'package:projeto/Core/Providers/patientProvider.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          ListTile(
            key: const ValueKey('app-drawer-anamnese'),
            leading: const Icon(Icons.description),
            title: const Text(AppStrings.formAnmenese),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/anamnese_form');
            },
          ),
          ListTile(
            key: const ValueKey('app-drawer-cif'),
            leading: const Icon(Icons.history_outlined),
            title: const Text('CIF'),
            onTap: () => _openCifHistory(context),
          ),
          ListTile(
            key: const ValueKey('app-drawer-asia'),
            leading: const Icon(Icons.description),
            title: const Text(AppStrings.formAsia),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/asia_form');
            },
          ),
          ListTile(
            key: const ValueKey('app-drawer-meem'),
            leading: const Icon(Icons.description),
            title: const Text('MEEM'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/meem_form');
            },
          ),
          ListTile(
            key: const ValueKey('app-drawer-eletro'),
            leading: const Icon(Icons.description),
            title: const Text('Eletrodiagnóstico'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/eletro_form');
            },
          ),
          ListTile(
            key: const ValueKey('app-drawer-dex'),
            leading: const Icon(Icons.description),
            title: const Text('DEX'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/dex_form');
            },
          ),
          ListTile(
            key: const ValueKey('app-drawer-gas'),
            leading: const Icon(Icons.description),
            title: const Text(AppStrings.formGas),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/gas_form');
            },
          ),
        ],
      ),
    );
  }

  void _openCifHistory(BuildContext context) {
    PatientProvider? patient;
    try {
      patient = Provider.of<PatientProvider>(context, listen: false);
    } on ProviderNotFoundException {
      patient = null;
    }
    if (patient?.id == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione um paciente antes de abrir o histórico CIF.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(context);
    Navigator.pushNamed(context, '/cif_history');
  }
}
