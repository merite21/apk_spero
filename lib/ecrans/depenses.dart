import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'formulaires.dart';

class EcranDepenses extends StatelessWidget {
  const EcranDepenses({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final admin = store.role == Role.admin;
    final attente = store.depenses.where((d) => d.statut == StatutDepense.enAttente).toList()..sort((a, b) => b.date.compareTo(a.date));
    final autres = store.depenses.where((d) => d.statut != StatutDepense.enAttente).toList()..sort((a, b) => b.date.compareTo(a.date));
    final now = DateTime.now();
    final totalMois = store.depensesEntre(DateTime(now.year, now.month), now.add(const Duration(days: 1)));

    return Scaffold(
      appBar: AppBar(title: const Text('Dépenses et entretien')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NouvelleDepense())),
        backgroundColor: SperoColors.vert,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Dépense', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Largeur(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            Indicateur(
              valeur: fcfa(totalMois),
              libelle: 'Dépenses de ${DateFormatSimple.moisAnnee(now)}',
              icone: Icons.receipt_long_rounded,
              couleur: const Color(0xFFC9A400),
            ),
            TitreSection(admin ? 'À valider (${attente.length})' : 'En attente de validation (${attente.length})'),
            if (attente.isEmpty) const Card(child: Vide(Icons.check_circle_outline, 'Aucune dépense en attente')),
            for (final d in attente) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${d.tricycleId} · ${d.categorie.libelle}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                          Text(fcfa(d.montant), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(d.description),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormatSimple.relative(d.date)} · ${d.saisiPar}',
                        style: TextStyle(fontSize: 12.5, color: couleurGris(context)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (!d.avecRecu) const Pastille('Sans reçu', Niveau.critique),
                          if (d.montant > store.parametres.seuilDepense)
                            Pastille('Plus de ${nombre(store.parametres.seuilDepense)}', Niveau.attention),
                        ],
                      ),
                      if (admin) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: SperoColors.rouge,
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () => store.deciderDepense(d, false),
                                child: const Text('Refuser'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                                onPressed: () => store.deciderDepense(d, true),
                                child: const Text('Valider'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const TitreSection('Historique'),
            Card(
              child: Column(
                children: [
                  for (final d in autres.take(60))
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: SperoColors.jauneClair,
                        child: Icon(_icone(d.categorie), size: 18, color: SperoColors.surJaune),
                      ),
                      title: Text('${d.tricycleId} · ${d.categorie.libelle}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${DateFormatSimple.relative(d.date)} · ${d.description}'),
                      trailing: Text(
                        d.statut == StatutDepense.refusee ? 'Refusée' : fcfa(d.montant),
                        style: TextStyle(fontWeight: FontWeight.w800, color: d.statut == StatutDepense.refusee ? SperoColors.rouge : null),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icone(CategorieDepense c) => switch (c) {
    CategorieDepense.reparation => Icons.build_rounded,
    CategorieDepense.vidange => Icons.oil_barrel_rounded,
    CategorieDepense.pneus => Icons.tire_repair_rounded,
    CategorieDepense.pieces => Icons.settings_rounded,
    CategorieDepense.carburant => Icons.local_gas_station_rounded,
    CategorieDepense.autre => Icons.more_horiz_rounded,
  };
}
