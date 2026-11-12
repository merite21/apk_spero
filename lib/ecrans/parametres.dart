import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class EcranParametres extends StatefulWidget {
  const EcranParametres({super.key});

  @override
  State<EcranParametres> createState() => _EcranParametresState();
}

class _EcranParametresState extends State<EcranParametres> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final p = store.parametres;

    Widget reglage(String titre, String sous, String valeur, VoidCallback moins, VoidCallback plus) => ListTile(
      title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sous),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(onPressed: moins, icon: const Icon(Icons.remove, size: 18)),
          SizedBox(
            width: 84,
            child: Text(
              valeur,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton.outlined(onPressed: plus, icon: const Icon(Icons.add, size: 18)),
        ],
      ),
    );

    void maj(VoidCallback f) {
      setState(f);
      store.sauverParametres();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: Largeur(
        max: 700,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const TitreSection('Versements'),
            Card(
              child: reglage(
                'Heure limite du versement',
                'Après cette heure, le versement du jour est en retard',
                '${p.heureLimite} h',
                () => maj(() => p.heureLimite = (p.heureLimite - 1).clamp(12, 23)),
                () => maj(() => p.heureLimite = (p.heureLimite + 1).clamp(12, 23)),
              ),
            ),
            const TitreSection('Dépenses'),
            Card(
              child: reglage(
                'Validation au-dessus de',
                'Le propriétaire valide les dépenses plus élevées',
                nombre(p.seuilDepense),
                () => maj(() => p.seuilDepense = (p.seuilDepense - 5000).clamp(5000, 500000)),
                () => maj(() => p.seuilDepense = (p.seuilDepense + 5000).clamp(5000, 500000)),
              ),
            ),
            const TitreSection('GPS et alertes'),
            Card(
              child: Column(
                children: [
                  reglage(
                    'Rayon de la zone autorisée',
                    'Autour du centre de Cotonou',
                    '${p.rayonZoneKm.round()} km',
                    () => maj(() => p.rayonZoneKm = (p.rayonZoneKm - 1).clamp(2, 40)),
                    () => maj(() => p.rayonZoneKm = (p.rayonZoneKm + 1).clamp(2, 40)),
                  ),
                  const Divider(height: 1),
                  reglage(
                    'Traceur sans signal',
                    'Alerte au-delà de cette durée',
                    '${p.minutesSansSignal} min',
                    () => maj(() => p.minutesSansSignal = (p.minutesSansSignal - 5).clamp(5, 240)),
                    () => maj(() => p.minutesSansSignal = (p.minutesSansSignal + 5).clamp(5, 240)),
                  ),
                  const Divider(height: 1),
                  reglage(
                    'Kilométrage anormal',
                    'Alerte si les km du jour dépassent la moyenne de',
                    '× ${p.facteurKm.toStringAsFixed(1)}',
                    () => maj(() => p.facteurKm = ((p.facteurKm * 10 - 1).clamp(11, 30)) / 10),
                    () => maj(() => p.facteurKm = ((p.facteurKm * 10 + 1).clamp(11, 30)) / 10),
                  ),
                  const Divider(height: 1),
                  reglage(
                    'Intervalle de vidange',
                    'Rappel d\'entretien',
                    '${nombre(p.kmVidange)} km',
                    () => maj(() => p.kmVidange = (p.kmVidange - 500).clamp(1000, 10000)),
                    () => maj(() => p.kmVidange = (p.kmVidange + 500).clamp(1000, 10000)),
                  ),
                ],
              ),
            ),
            const TitreSection('Données'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: const Text('Journal d\'activité'),
                    subtitle: const Text('Qui a saisi quoi, et quand'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EcranJournal())),
                  ),
                  if (!store.surServeur) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.restart_alt_rounded, color: SperoColors.rouge),
                      title: const Text('Réinitialiser la démonstration', style: TextStyle(color: SperoColors.rouge)),
                      subtitle: const Text('Efface les saisies et recrée les données d\'exemple'),
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Réinitialiser ?'),
                            content: const Text('Toutes les saisies faites sur cet appareil seront effacées.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: SperoColors.rouge, minimumSize: const Size(0, 44)),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Réinitialiser'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await store.reinitialiserDemo();
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                store.surServeur ? 'Spero · connecté au serveur' : 'Spero · version de démonstration',
                style: TextStyle(color: couleurGris(context), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EcranJournal extends StatelessWidget {
  const EcranJournal({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Journal d\'activité')),
      body: Largeur(
        child: store.journal.isEmpty
            ? const Vide(Icons.history, 'Aucune activité')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: store.journal.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final j = store.journal[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      j.auteur == 'Administrateur' ? Icons.admin_panel_settings_outlined : Icons.badge_outlined,
                      color: j.auteur == 'Administrateur' ? SperoColors.vert : const Color(0xFFB08F00),
                    ),
                    title: Text(j.action),
                    subtitle: Text('${DateFormatSimple.relative(j.date)} · ${j.auteur}'),
                  );
                },
              ),
      ),
    );
  }
}
