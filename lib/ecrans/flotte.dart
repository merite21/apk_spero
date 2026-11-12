import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'carte.dart';
import 'fiche_chauffeur.dart';
import 'fiche_tricycle.dart';
import 'formulaires.dart';

class Flotte extends StatelessWidget {
  const Flotte({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final admin = store.role == Role.admin;
    final alertes = store.alertesOuvertes();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flotte'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Tricycles (${store.tricycles.length})'),
              Tab(text: 'Chauffeurs (${store.chauffeursActifs.length})'),
            ],
          ),
          actions: [
            if (admin)
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle_outline),
                onSelected: (v) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => v == 't' ? const FormulaireTricycle() : const EcranInscriptions()),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 't', child: Text('Ajouter un tricycle')),
                  PopupMenuItem(value: 'c', child: Text('Inscriptions de chauffeurs')),
                ],
              ),
          ],
        ),
        body: TabBarView(
          children: [
            Largeur(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: store.tricycles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final t = store.tricycles[i];
                  final c = store.chauffeurDe(t.id);
                  final e = store.traceurs[t.id]!;
                  final roule = e.moteur && e.vitesse > 0;
                  final coupe = store.traceurCoupe(t.id);
                  final n = coupe ? Niveau.critique : niveauTricycle(store, t.id, alertes);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FicheTricycle(tricycleId: t.id))),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: (n?.couleur ?? SperoColors.vert).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                store.moteursBloques.contains(t.id) ? Icons.lock_rounded : Icons.electric_rickshaw_rounded,
                                color: n == Niveau.attention ? const Color(0xFFB08F00) : (n?.couleur ?? SperoColors.vert),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${t.id} · ${c?.nom ?? 'Disponible'}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    coupe
                                        ? 'Traceur sans signal'
                                        : '${roule ? 'En route · ${e.vitesse.round()} km/h' : 'À l\'arrêt'} · ${store.kmAujourdhui(t.id).round()} km aujourd\'hui',
                                    style: TextStyle(fontSize: 13, color: couleurGris(context)),
                                  ),
                                ],
                              ),
                            ),
                            if (n != null) Pastille(n.libelle, n) else Icon(Icons.chevron_right, color: couleurGris(context)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Largeur(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final c in store.inscriptionsEnAttente) ...[_LigneInscription(c), const SizedBox(height: 8)],
                  for (final c in [
                    ...store.chauffeursActifs,
                    ...store.chauffeurs.where((c) => !c.actif && c.statut == StatutInscription.valide),
                  ]) ...[
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: Initiales(c.nom, couleur: c.actif ? store.situation(c).niveau.couleur : SperoColors.gris),
                        title: Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          c.actif
                              ? '${c.tricycleId ?? 'Sans tricycle'} · dépôt complet ${(regularite(store, c) * 100).round()} % des jours'
                              : 'Contrat terminé',
                        ),
                        trailing: c.actif ? Pastille.situation(store.situation(c)) : null,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FicheChauffeur(chauffeurId: c.id))),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneInscription extends StatelessWidget {
  final Chauffeur c;
  const _LigneInscription(this.c);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: c.photoVisage != null ? PhotoBase64(c.photoVisage, hauteur: 42, rond: true) : Initiales(c.nom, couleur: SperoColors.jaune),
        title: Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('Inscrit ${DateFormatSimple.relative(c.dateInscription).toLowerCase()} · ${c.telephone}'),
        trailing: const Pastille('À valider', Niveau.attention),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FicheChauffeur(chauffeurId: c.id))),
      ),
    );
  }
}

/// Inscriptions de chauffeurs en attente de validation.
class EcranInscriptions extends StatelessWidget {
  const EcranInscriptions({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final attente = store.inscriptionsEnAttente;
    final refusees = store.chauffeurs.where((c) => c.statut == StatutInscription.refuse).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Inscriptions')),
      body: Largeur(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: SperoColors.vert),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pour recruter, demandez au chauffeur de télécharger Spero et de choisir « Créer mon compte chauffeur ». '
                        'Son inscription apparaît ici.',
                        style: TextStyle(color: couleurGris(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TitreSection('En attente (${attente.length})'),
            if (attente.isEmpty) const Card(child: Vide(Icons.how_to_reg_outlined, 'Aucune inscription en attente')),
            for (final c in attente) ...[_LigneInscription(c), const SizedBox(height: 8)],
            if (refusees.isNotEmpty) ...[
              const TitreSection('Refusées'),
              for (final c in refusees)
                Card(
                  child: ListTile(
                    leading: Initiales(c.nom, couleur: SperoColors.gris),
                    title: Text(c.nom),
                    subtitle: Text(c.motifRefus ?? ''),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
