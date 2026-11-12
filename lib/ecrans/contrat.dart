import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Articles du contrat, remplis avec les conditions propres au chauffeur.
/// Modèle de départ : à faire relire par un juriste avant usage réel.
List<(String, String)> articlesContrat(SperoStore store, Chauffeur c) {
  final t = store.tricycle(c.tricycleId);
  final p = store.parametres;
  return [
    (
      'Article 1 · Objet',
      'Le propriétaire confie au chauffeur ${c.nom} le tricycle ${t?.id ?? '(à attribuer)'}'
          '${t == null ? '' : ', immatriculé ${t.immatriculation}'}, pour le transport de personnes et de marchandises.',
    ),
    (
      'Article 2 · Durée',
      'Le contrat commence le ${DateFormatSimple.dateLongue(c.debutContrat)}, pour une durée indéterminée. '
          'Chaque partie peut y mettre fin avec un préavis de 7 jours, ou sans préavis en cas de faute grave.',
    ),
    (
      'Article 3 · Dépôt journalier',
      'Le chauffeur dépose ${fcfa(c.montantJournalier)} par jour travaillé, avant ${p.heureLimite} h, depuis l\'application Spero '
          '(MTN MoMo ou Moov Money), sur le compte du propriétaire. '
          '${c.reposDimanche ? 'Le dimanche est un jour de repos, aucun dépôt n\'est dû. ' : ''}'
          'Tout dépôt incomplet ou manquant est reporté en arriéré. Les dépôts suivants remboursent d\'abord les arriérés les plus anciens.',
    ),
    (
      'Article 4 · Salaire',
      'Le propriétaire verse au chauffeur un salaire de ${fcfa(c.salaireMensuel)} par mois, depuis l\'application. '
          'Chaque paiement apparaît dans l\'espace du chauffeur.',
    ),
    (
      'Article 5 · Caution',
      'Le chauffeur verse une caution de ${fcfa(c.caution)}. Elle lui est rendue à la fin du contrat, '
          'déduction faite des arriérés et des dommages non couverts.',
    ),
    (
      'Article 6 · Horaires et zone',
      'Le tricycle circule de ${c.heureDebut} h à ${c.heureFin} h, dans un rayon de ${p.rayonZoneKm.round()} km autour du centre de Cotonou. '
          'Toute sortie de zone ou circulation hors horaires doit être autorisée par le propriétaire.',
    ),
    (
      'Article 7 · Obligations du chauffeur',
      '• Ne pas prêter ni sous-louer le tricycle.\n'
          '• Ne pas débrancher, déplacer ni abîmer le traceur GPS.\n'
          '• Ne pas échanger de pièces du tricycle.\n'
          '• Signaler sans attendre toute panne, accident, vol ou contrôle de police.\n'
          '• Respecter le code de la route et garder un permis valide.\n'
          '• Prendre soin du tricycle et le présenter aux inspections.',
    ),
    (
      'Article 8 · Suivi GPS et coupe-moteur',
      'Le tricycle est équipé d\'un traceur GPS. Le chauffeur accepte que sa position soit suivie pendant le service. '
          'En cas d\'arriérés de plus de 3 jours, le propriétaire peut bloquer le démarrage à distance, uniquement tricycle à l\'arrêt.',
    ),
    (
      'Article 9 · Sanctions',
      'Retard de dépôt : rappel par notification. Plus de 3 jours d\'arriérés : suspension. '
          'Faute grave (sous-location, traceur saboté, pièces échangées, vol) : fin immédiate du contrat, caution retenue et poursuites possibles.',
    ),
    (
      'Article 10 · Données personnelles',
      'L\'identité, les photos (CIP et visage) et les positions du chauffeur servent uniquement à la gestion de ce contrat.',
    ),
  ];
}

/// Texte du contrat avec son état d'acceptation.
class ContratVue extends StatelessWidget {
  final Chauffeur chauffeur;
  const ContratVue(this.chauffeur, {super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final c = chauffeur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: c.contratAccepte
              ? (estSombre(context) ? const Color(0xFF16301F) : SperoColors.vertClair)
              : (estSombre(context) ? const Color(0xFF3A3110) : SperoColors.jauneClair),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  c.contratAccepte ? Icons.verified_rounded : Icons.pending_actions_rounded,
                  color: c.contratAccepte ? SperoColors.vert : const Color(0xFF9A7D00),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.contratAccepte
                        ? 'Accepté le ${DateFormatSimple.dateLongue(c.contratAccepteLe!)} à ${DateFormatSimple.heure(c.contratAccepteLe!)}, signé « ${c.signature} »'
                        : 'Pas encore accepté par le chauffeur',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contrat d\'exploitation de tricycle', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Entre le propriétaire de la flotte Spero et ${c.nom}', style: TextStyle(color: couleurGris(context))),
                const SizedBox(height: 4),
                Text(
                  'CIP ${c.pieceIdentite}${c.ifu == null ? '' : ' · IFU ${c.ifu}'} · ${c.telephone}',
                  style: TextStyle(color: couleurGris(context)),
                ),
                const Divider(height: 28),
                for (final (titre, texte) in articlesContrat(store, c)) ...[
                  Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(texte, style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Zone d'acceptation, côté chauffeur.
class AcceptationContrat extends StatefulWidget {
  final Chauffeur chauffeur;
  const AcceptationContrat(this.chauffeur, {super.key});

  @override
  State<AcceptationContrat> createState() => _AcceptationContratState();
}

class _AcceptationContratState extends State<AcceptationContrat> {
  bool _lu = false;
  final _signature = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final c = widget.chauffeur;
    final ok = _lu && _signature.text.trim().toLowerCase() == c.nom.toLowerCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Accepter le contrat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _lu,
              activeColor: SperoColors.vert,
              onChanged: (v) => setState(() => _lu = v ?? false),
              title: const Text('J\'ai lu le contrat en entier et j\'accepte toutes ses conditions.'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _signature,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Signature : écrivez « ${c.nom} »', prefixIcon: const Icon(Icons.draw_outlined)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: ok
                  ? () async {
                      await context.read<SperoStore>().accepterContrat(c, _signature.text.trim());
                      if (context.mounted) messageSucces(context, 'Contrat accepté. Bonne route !');
                    }
                  : null,
              child: const Text('J\'accepte le contrat'),
            ),
          ],
        ),
      ),
    );
  }
}
