import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fiche_chauffeur.dart';
import 'fiche_tricycle.dart';
import 'versements.dart';

/// Ouvre le détail d'une alerte : voir la cible, ou la marquer comme traitée.
Future<void> ouvrirAlerte(BuildContext context, Alerte a) async {
  final store = context.read<SperoStore>();
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Pastille(a.niveau.libelle, a.niveau)]),
            const SizedBox(height: 10),
            Text(a.titre, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(a.detail, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text(DateFormatSimple.relative(a.date), style: TextStyle(color: couleurGris(ctx))),
            const SizedBox(height: 20),
            if (a.tricycleId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FicheTricycle(tricycleId: a.tricycleId!)));
                  },
                  icon: const Icon(Icons.electric_rickshaw_rounded),
                  label: Text('Voir le tricycle ${a.tricycleId}'),
                ),
              ),
            if (a.chauffeurId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FicheChauffeur(chauffeurId: a.chauffeurId!)));
                  },
                  icon: const Icon(Icons.person_rounded),
                  label: const Text('Voir le chauffeur'),
                ),
              ),
            if (a.id.startsWith('confirmer-'))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.icon(
                  onPressed: () {
                    final v = store.versements.where((x) => 'confirmer-${x.id}' == a.id).firstOrNull;
                    Navigator.pop(ctx);
                    if (v != null) decisionDepot(context, v);
                  },
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Confirmer ou rejeter le dépôt'),
                ),
              )
            else
              FilledButton.icon(
                onPressed: () async {
                  final c = await demanderTexte(ctx, titre: 'Marquer comme traitée', libelle: 'Ce qui a été fait', bouton: 'Enregistrer');
                  if (c == null) return;
                  await store.traiterAlerte(a, c);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Marquer comme traitée'),
              ),
          ],
        ),
      ),
    ),
  );
}

class EcranAlertes extends StatefulWidget {
  const EcranAlertes({super.key});

  @override
  State<EcranAlertes> createState() => _EcranAlertesState();
}

class _EcranAlertesState extends State<EcranAlertes> {
  Niveau? _filtre;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final toutes = store.alertesOuvertes();
    final liste = _filtre == null ? toutes : toutes.where((a) => a.niveau == _filtre).toList();
    final traitees = store.journal.where((j) => j.action.startsWith('Alerte traitée')).take(20).toList();

    Widget puce(String t, Niveau? n) {
      final nb = n == null ? toutes.length : toutes.where((a) => a.niveau == n).length;
      final choisi = _filtre == n;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('$t ($nb)'),
          selected: choisi,
          showCheckmark: false,
          selectedColor: n?.couleur ?? SperoColors.vert,
          labelStyle: TextStyle(color: choisi ? (n?.surCouleur ?? Colors.white) : null, fontWeight: FontWeight.w600),
          onSelected: (_) => setState(() => _filtre = n),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Alertes')),
      body: Largeur(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  puce('Toutes', null),
                  puce('Critiques', Niveau.critique),
                  puce('À vérifier', Niveau.attention),
                  puce('Infos', Niveau.ok),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (liste.isEmpty) const Card(child: Vide(Icons.verified_user_outlined, 'Aucune alerte ouverte')),
            for (final a in liste) ...[CarteAlerte(a, onTap: () => ouvrirAlerte(context, a)), const SizedBox(height: 8)],
            if (traitees.isNotEmpty) ...[
              const TitreSection('Traitées récemment'),
              Card(
                child: Column(
                  children: [
                    for (final j in traitees)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.check_circle, color: SperoColors.vert),
                        title: Text(j.action.replaceFirst('Alerte traitée ', '')),
                        subtitle: Text('${DateFormatSimple.relative(j.date)} · ${j.auteur}'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
