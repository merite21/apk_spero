import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fiche_chauffeur.dart';
import 'formulaires.dart';

class Versements extends StatefulWidget {
  const Versements({super.key});

  @override
  State<Versements> createState() => _VersementsState();
}

class _VersementsState extends State<Versements> {
  String _filtre = 'Tous';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dépôts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Situation du jour'),
              Tab(text: 'Historique'),
            ],
          ),
        ),
        floatingActionButton: store.role == Role.gestionnaire
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NouveauVersement())),
                backgroundColor: SperoColors.vert,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Dépôt espèces', style: TextStyle(fontWeight: FontWeight.w700)),
              )
            : null,
        body: TabBarView(children: [_situation(store), _historique(store)]),
      ),
    );
  }

  Widget _situation(SperoStore store) {
    final liste = store.chauffeursActifs.where((c) {
      final s = store.situation(c);
      return switch (_filtre) {
        'À jour' => s.joursRetard == 0 && s.payeAujourdhui,
        'À recevoir' => !s.payeAujourdhui && s.joursRetard == 0,
        'En retard' => s.joursRetard > 0,
        _ => true,
      };
    }).toList()..sort((a, b) => store.situation(b).arrieres.compareTo(store.situation(a).arrieres));

    return Largeur(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in ['Tous', 'À recevoir', 'En retard', 'À jour'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _filtre == f,
                      showCheckmark: false,
                      selectedColor: SperoColors.vert,
                      labelStyle: TextStyle(color: _filtre == f ? Colors.white : null, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _filtre = f),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (store.depotsAConfirmer.isNotEmpty) ...[
            TitreSection('Dépôts à confirmer (${store.depotsAConfirmer.length})'),
            Card(child: Column(children: [for (final v in store.depotsAConfirmer) LigneVersement(v)])),
            const SizedBox(height: 12),
          ],
          if (liste.isEmpty) const Card(child: Vide(Icons.inbox_outlined, 'Aucun chauffeur dans ce filtre.')),
          for (final c in liste) ...[_LigneChauffeur(c), const SizedBox(height: 8)],
        ],
      ),
    );
  }

  Widget _historique(SperoStore store) {
    final liste = [...store.versements]..sort((a, b) => b.date.compareTo(a.date));
    final groupes = <DateTime, List<Versement>>{};
    for (final v in liste.take(200)) {
      groupes.putIfAbsent(SperoStore.jour(v.date), () => []).add(v);
    }
    return Largeur(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          for (final g in groupes.entries) ...[
            TitreSection(
              DateFormatSimple.dateLongue(g.key),
              action: Text(fcfa(g.value.fold(0, (s, v) => s + v.montant)), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Card(child: Column(children: [for (final v in g.value) LigneVersement(v)])),
          ],
        ],
      ),
    );
  }
}

class _LigneChauffeur extends StatelessWidget {
  final Chauffeur c;
  const _LigneChauffeur(this.c);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final s = store.situation(c);
    final admin = store.role == Role.admin;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FicheChauffeur(chauffeurId: c.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Initiales(c.nom, couleur: s.niveau.couleur),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        c.tricycleId ?? 'Sans tricycle',
                        '${nombre(c.montantJournalier)}/jour',
                        if (s.arrieres > 0) 'arriérés ${fcfa(s.arrieres)}',
                        if (s.avance > 0) 'avance ${fcfa(s.avance)}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: couleurGris(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Pastille.situation(s),
                  if (!s.payeAujourdhui && !admin) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NouveauVersement(chauffeurId: c.id))),
                      child: const Text(
                        'Dépôt espèces',
                        style: TextStyle(color: SperoColors.vert, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LigneVersement extends StatelessWidget {
  final Versement v;
  final bool avecNom;
  const LigneVersement(this.v, {super.key, this.avecNom = true});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final c = store.chauffeur(v.chauffeurId);
    final annule = store.estAnnule(v) || v.statut == StatutVersement.rejete;
    final estAnnulation = v.annuleId != null;
    final aConfirmer = v.statut == StatutVersement.aConfirmer;
    final staff = store.role == Role.admin || store.role == Role.gestionnaire;
    final icone = switch (v.mode) {
      ModePaiement.especes => Icons.payments_outlined,
      _ => Icons.phone_android_rounded,
    };
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (estAnnulation ? SperoColors.rouge : SperoColors.vert).withValues(alpha: 0.12),
        child: Icon(estAnnulation ? Icons.undo_rounded : icone, color: estAnnulation ? SperoColors.rouge : SperoColors.vert, size: 20),
      ),
      title: Text(
        avecNom ? (c?.nom ?? v.chauffeurId) : (estAnnulation ? 'Annulation' : v.mode.libelle),
        style: TextStyle(fontWeight: FontWeight.w600, decoration: annule ? TextDecoration.lineThrough : null),
      ),
      subtitle: Text(
        estAnnulation
            ? 'Annulation · ${v.motif ?? ''}'
            : [
                DateFormatSimple.relative(v.date),
                v.mode.libelle,
                v.saisiPar,
                if (aConfirmer) 'à confirmer',
                if (v.statut == StatutVersement.rejete) 'rejeté : ${v.motif ?? ''}',
                if (store.estAnnule(v)) 'annulé',
              ].join(' · '),
        style: TextStyle(fontSize: 12.5, color: couleurGris(context)),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            fcfa(v.montant),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: estAnnulation ? SperoColors.rouge : null,
              decoration: annule ? TextDecoration.lineThrough : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (aConfirmer) ...[const SizedBox(height: 3), const Pastille('À confirmer', Niveau.attention)],
        ],
      ),
      onTap: aConfirmer && staff ? () => decisionDepot(context, v) : null,
      onLongPress: store.role == Role.admin && !annule && !estAnnulation && v.compte
          ? () async {
              final motif = await demanderTexte(
                context,
                titre: 'Annuler ce versement ?',
                libelle: 'Motif de l\'annulation',
                bouton: 'Annuler le versement',
              );
              if (motif != null) await store.annulerVersement(v, motif);
            }
          : null,
    );
  }
}

/// Confirmer ou rejeter un dépôt fait par un chauffeur dans l'application.
Future<void> decisionDepot(BuildContext context, Versement v) async {
  final store = context.read<SperoStore>();
  final c = store.chauffeur(v.chauffeurId);
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dépôt de ${fcfa(v.montant)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${c?.nom ?? ''} · ${v.mode.libelle} · ${DateFormatSimple.relative(v.date)}', style: TextStyle(color: couleurGris(ctx))),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: SperoColors.jauneClair, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'Vérifiez sur le compte Mobile Money du propriétaire que l\'argent est bien arrivé avant de confirmer.',
                style: TextStyle(color: SperoColors.surJaune),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await store.confirmerVersement(v);
                if (context.mounted) messageSucces(context, 'Dépôt confirmé. Il compte pour ${c?.prenom ?? 'le chauffeur'}.');
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Argent reçu : confirmer'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: SperoColors.rouge,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                final motif = await demanderTexte(
                  ctx,
                  titre: 'Rejeter ce dépôt',
                  libelle: 'Motif (visible par le chauffeur)',
                  bouton: 'Rejeter',
                );
                if (motif == null) return;
                if (ctx.mounted) Navigator.pop(ctx);
                await store.rejeterVersement(v, motif);
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Argent pas reçu : rejeter'),
            ),
          ],
        ),
      ),
    ),
  );
}
