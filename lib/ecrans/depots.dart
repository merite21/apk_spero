import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Carte « dépôt du jour » : déposé, dû, ce qui manque.
class CarteDepotDuJour extends StatelessWidget {
  final Chauffeur chauffeur;
  final VoidCallback? onDeposer;
  final String libelleBouton;
  const CarteDepotDuJour(this.chauffeur, {super.key, this.onDeposer, this.libelleBouton = 'Faire mon dépôt'});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final s = store.situation(chauffeur);
    final du = s.duAujourdhui;
    final couvert = du - s.manqueAujourdhui;
    final ratio = du == 0 ? 1.0 : (couvert / du).clamp(0.0, 1.0);
    final complet = s.manqueAujourdhui == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Dépôt du jour', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                if (du == 0)
                  const Pastille('Repos', Niveau.ok, neutre: true)
                else if (complet)
                  const Pastille('Complet', Niveau.ok)
                else
                  Pastille('Manque ${nombre(s.manqueAujourdhui)}', s.niveau == Niveau.ok ? Niveau.attention : s.niveau),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(
                  fcfa(couvert),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('sur ${fcfa(du)}', style: TextStyle(color: couleurGris(context))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                color: complet ? SperoColors.vert : SperoColors.jaune,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              du == 0
                  ? 'Aujourd\'hui est un jour de repos.'
                  : complet
                  ? 'Le dépôt d\'aujourd\'hui est complet.'
                  : 'Il manque ${fcfa(s.manqueAujourdhui)} pour aujourd\'hui. Heure limite : ${store.parametres.heureLimite} h.',
              style: TextStyle(color: couleurGris(context)),
            ),
            if (s.enAttenteConfirmation > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 18, color: Color(0xFF9A7D00)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${fcfa(s.enAttenteConfirmation)} déposé, en attente de confirmation du propriétaire',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9A7D00)),
                    ),
                  ),
                ],
              ),
            ],
            if (s.arrieres > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: estSombre(context) ? const Color(0xFF3A1419) : SperoColors.rougeClair,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: SperoColors.rouge),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Arriérés : ${fcfa(s.arrieres)} sur ${s.joursRetard} jour(s) précédent(s)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (onDeposer != null && s.resteAujourdhui > 0) ...[
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: onDeposer, icon: const Icon(Icons.send_to_mobile_rounded), label: Text(libelleBouton)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Liste jour par jour des dépôts (du plus récent au plus ancien).
class ListeJoursDepots extends StatelessWidget {
  final Chauffeur chauffeur;
  final int limite;
  const ListeJoursDepots(this.chauffeur, {super.key, this.limite = 30});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final aujourdhui = SperoStore.jour(DateTime.now());
    final jours = store.journalDepots(chauffeur).reversed.take(limite).toList();
    if (jours.isEmpty) return const Card(child: Vide(Icons.inbox_outlined, 'Aucun jour de travail pour l\'instant'));
    return Card(
      child: Column(
        children: [
          for (final j in jours)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: _couleur(j, aujourdhui).withValues(alpha: 0.15),
                child: Text(
                  '${j.jour.day}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _couleur(j, aujourdhui) == SperoColors.jaune ? const Color(0xFF8A7000) : _couleur(j, aujourdhui),
                  ),
                ),
              ),
              title: Text(DateFormatSimple.dateLongue(j.jour), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Déposé ce jour : ${fcfa(j.deposeCeJour)} · dû ${fcfa(j.du)}', style: TextStyle(color: couleurGris(context))),
              trailing: _pastille(j, aujourdhui),
            ),
        ],
      ),
    );
  }

  Color _couleur(JourDepot j, DateTime aujourdhui) {
    if (j.complet) return SperoColors.vert;
    if (j.partiel || j.jour == aujourdhui) return SperoColors.jaune;
    return SperoColors.rouge;
  }

  Widget _pastille(JourDepot j, DateTime aujourdhui) {
    if (j.complet) return const Pastille('Complet', Niveau.ok);
    if (j.jour == aujourdhui) return Pastille('Manque ${nombre(j.manque)}', Niveau.attention);
    if (j.partiel) return Pastille('Manque ${nombre(j.manque)}', Niveau.attention);
    return Pastille('Rien reçu', Niveau.critique);
  }
}

/// Calendrier des 30 derniers jours : vert complet, jaune incomplet, rouge rien reçu.
class CalendrierDepots extends StatelessWidget {
  final Chauffeur chauffeur;
  const CalendrierDepots(this.chauffeur, {super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final aujourdhui = SperoStore.jour(DateTime.now());
    final parJour = {for (final j in store.journalDepots(chauffeur)) j.jour: j};
    final jours = List.generate(30, (i) => aujourdhui.subtract(Duration(days: 29 - i)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 5, runSpacing: 5, children: [for (final d in jours) _case(context, parJour[d], d, d == aujourdhui)]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _legende(SperoColors.vert, 'Complet'),
                _legende(SperoColors.jaune, 'Incomplet'),
                _legende(SperoColors.rouge, 'Rien reçu'),
                _legende(Theme.of(context).colorScheme.surfaceContainerHighest, 'Repos ou hors contrat'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _case(BuildContext context, JourDepot? j, DateTime d, bool aujourdhui) {
    Color fond;
    Color texte = Colors.white;
    String info;
    if (j == null) {
      fond = Theme.of(context).colorScheme.surfaceContainerHighest;
      texte = couleurGris(context);
      info = 'repos ou hors contrat';
    } else if (j.complet) {
      fond = SperoColors.vert;
      info = 'complet (${fcfa(j.du)})';
    } else if (j.partiel || aujourdhui) {
      fond = SperoColors.jaune;
      texte = SperoColors.surJaune;
      info = 'il manque ${fcfa(j.manque)}';
    } else {
      fond = SperoColors.rouge;
      info = 'rien reçu, il manque ${fcfa(j.manque)}';
    }
    return Tooltip(
      message: '${DateFormatSimple.dateLongue(d)} : $info',
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(9),
          border: aujourdhui ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 1.5) : null,
        ),
        child: Text(
          '${d.day}',
          style: TextStyle(color: texte, fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
      ),
    );
  }

  Widget _legende(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 6),
      Text(t, style: const TextStyle(fontSize: 12)),
    ],
  );
}
