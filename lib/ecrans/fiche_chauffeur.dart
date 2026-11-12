import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'contrat.dart';
import 'depots.dart';
import 'fiche_tricycle.dart';
import 'formulaires.dart';
import 'versements.dart';

/// Régularité : part des jours travaillés (30 derniers) où le dépôt complet est arrivé le jour même.
double regularite(SperoStore store, Chauffeur c, {int jours = 30}) {
  final aujourdhui = SperoStore.jour(DateTime.now());
  final debut = aujourdhui.subtract(Duration(days: jours));
  final liste = store.journalDepots(c).where((j) => j.jour.isBefore(aujourdhui) && !j.jour.isBefore(debut)).toList();
  if (liste.isEmpty) return 1;
  return liste.where((j) => j.deposeCeJour >= j.du).length / liste.length;
}

class FicheChauffeur extends StatelessWidget {
  final String chauffeurId;
  const FicheChauffeur({super.key, required this.chauffeurId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final c = store.chauffeur(chauffeurId);
    if (c == null) return const Scaffold(body: Vide(Icons.person_off, 'Chauffeur introuvable'));
    final admin = store.role == Role.admin;

    if (c.statut != StatutInscription.valide) {
      return Scaffold(
        appBar: AppBar(title: Text(c.enAttente ? 'Inscription à vérifier' : 'Inscription refusée')),
        body: Largeur(
          max: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              _Dossier(c),
              const SizedBox(height: 12),
              if (c.enAttente && admin) _Validation(c),
              if (c.enAttente && !admin) const Card(child: Vide(Icons.lock_outline, 'Seul le propriétaire peut valider une inscription.')),
              if (c.statut == StatutInscription.refuse)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.block, color: SperoColors.rouge),
                    title: const Text('Motif du refus'),
                    subtitle: Text(c.motifRefus ?? '-'),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final s = store.situation(c);
    final reg = regularite(store, c);
    final vs = store.versementsDe(c.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    final salaires = store.salairesDe(c.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    void ouvrir(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: AppBar(
        title: Text(c.nom),
        actions: [
          if (admin)
            IconButton(
              tooltip: 'Modifier le contrat',
              onPressed: () => ouvrir(FormulaireChauffeur(chauffeurId: c.id)),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Largeur(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    c.photoVisage != null
                        ? PhotoBase64(c.photoVisage, hauteur: 60, rond: true)
                        : Initiales(c.nom, taille: 60, couleur: s.niveau.couleur),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.nom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          SelectableText(
                            '${c.telephone}${c.email == null ? '' : ' · ${c.email}'}',
                            style: TextStyle(color: couleurGris(context)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Pastille.situation(s),
                              if (!c.contratAccepte) const Pastille('Contrat non accepté', Niveau.attention),
                              if (!c.actif) const Pastille('Contrat terminé', Niveau.ok, neutre: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            CarteDepotDuJour(
              c,
              onDeposer: store.role == Role.gestionnaire ? () => ouvrir(NouveauVersement(chauffeurId: c.id)) : null,
              libelleBouton: 'Enregistrer un dépôt en espèces',
            ),
            if (vs.any((v) => v.statut == StatutVersement.aConfirmer)) ...[
              const TitreSection('Dépôts à confirmer'),
              Card(
                child: Column(
                  children: [for (final v in vs.where((v) => v.statut == StatutVersement.aConfirmer)) LigneVersement(v, avecNom: false)],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Grille(
              enfants: [
                Indicateur(valeur: nombre(s.totalPaye), libelle: 'Total déposé (FCFA)', icone: Icons.savings_outlined),
                Indicateur(
                  valeur: '${(reg * 100).round()} %',
                  libelle: 'Dépôt complet le jour même (30 j)',
                  icone: Icons.verified_outlined,
                  couleur: reg >= 0.9 ? SperoColors.vert : (reg >= 0.75 ? const Color(0xFFC9A400) : SperoColors.rouge),
                ),
                Indicateur(valeur: nombre(c.montantJournalier), libelle: 'Dépôt par jour (FCFA)', icone: Icons.calendar_today_outlined),
                Indicateur(
                  valeur: nombre(c.salaireMensuel),
                  libelle: 'Salaire mensuel (FCFA)',
                  icone: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            const TitreSection('30 derniers jours'),
            CalendrierDepots(c),
            const TitreSection('Jour par jour'),
            ListeJoursDepots(c, limite: 10),
            TitreSection(
              'Salaire',
              action: admin
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () => payerSalaire(context, c),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Payer le salaire'),
                    )
                  : null,
            ),
            Card(
              child: salaires.isEmpty
                  ? const Vide(Icons.account_balance_wallet_outlined, 'Aucun salaire payé')
                  : Column(
                      children: [
                        for (final p in salaires)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.north_east_rounded, color: SperoColors.vert),
                            title: Text(p.periode, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${DateFormatSimple.relative(p.date)} · ${p.mode.libelle}'),
                            trailing: Text(fcfa(p.montant), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
            ),
            TitreSection(
              'Contrat',
              action: TextButton(
                onPressed: () => ouvrir(
                  Scaffold(
                    appBar: AppBar(title: const Text('Contrat')),
                    body: Largeur(
                      child: ListView(padding: const EdgeInsets.all(16), children: [ContratVue(c)]),
                    ),
                  ),
                ),
                child: const Text('Lire le contrat'),
              ),
            ),
            Card(
              child: Column(
                children: [
                  _info(
                    context,
                    Icons.verified_outlined,
                    'Acceptation',
                    c.contratAccepte
                        ? 'Le ${DateFormatSimple.date(c.contratAccepteLe!)} à ${DateFormatSimple.heure(c.contratAccepteLe!)}'
                        : 'En attente',
                  ),
                  _info(
                    context,
                    Icons.electric_rickshaw_rounded,
                    'Tricycle',
                    c.tricycleId ?? 'Aucun',
                    onTap: c.tricycleId == null ? null : () => ouvrir(FicheTricycle(tricycleId: c.tricycleId!)),
                  ),
                  _info(context, Icons.event_rounded, 'Début', DateFormatSimple.dateLongue(c.debutContrat)),
                  _info(context, Icons.schedule_rounded, 'Horaires autorisés', 'De ${c.heureDebut} h à ${c.heureFin} h'),
                  _info(context, Icons.weekend_outlined, 'Repos', c.reposDimanche ? 'Dimanche' : 'Aucun'),
                  _info(context, Icons.lock_outline, 'Caution', fcfa(c.caution)),
                  _info(context, Icons.handshake_outlined, 'Garant', c.garant.isEmpty ? '-' : '${c.garant} · ${c.telephoneGarant}'),
                ],
              ),
            ),
            const TitreSection('Dossier d\'inscription'),
            _Dossier(c, compact: true),
            TitreSection(
              'Historique des dépôts',
              action: admin ? Text('Appui long pour annuler', style: TextStyle(fontSize: 12, color: couleurGris(context))) : null,
            ),
            Card(
              child: vs.isEmpty
                  ? const Vide(Icons.inbox_outlined, 'Aucun dépôt')
                  : Column(children: [for (final v in vs.take(40)) LigneVersement(v, avecNom: false)]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context, IconData i, String a, String b, {VoidCallback? onTap}) => ListTile(
    dense: true,
    leading: Icon(i, size: 20, color: couleurGris(context)),
    title: Text(a, style: TextStyle(color: couleurGris(context))),
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Text(
        b,
        textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    onTap: onTap,
  );
}

/// Identité, photo de la CIP et selfie, côte à côte pour comparer.
class _Dossier extends StatelessWidget {
  final Chauffeur c;
  final bool compact;
  const _Dossier(this.c, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    final h = compact ? 150.0 : 210.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              Text(c.nom, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Inscrit ${DateFormatSimple.relative(c.dateInscription).toLowerCase()}', style: TextStyle(color: couleurGris(context))),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Visage', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      PhotoBase64(c.photoVisage, hauteur: h, vide: 'Pas de selfie (démonstration)'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CIP', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      PhotoBase64(c.photoCip, hauteur: h, vide: 'Pas de photo de CIP (démonstration)'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Vérifiez que le visage correspond à la photo de la CIP.', style: TextStyle(fontSize: 12.5, color: couleurGris(context))),
            const Divider(height: 24),
            _ligne(context, 'Téléphone', c.telephone),
            _ligne(context, 'E-mail', c.email ?? '-'),
            _ligne(context, 'N° CIP', c.pieceIdentite),
            _ligne(context, 'IFU', c.ifu ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _ligne(BuildContext context, String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(a, style: TextStyle(color: couleurGris(context))),
        ),
        Expanded(
          child: SelectableText(b, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// Formulaire de validation : attribution du tricycle et conditions du contrat.
class _Validation extends StatefulWidget {
  final Chauffeur c;
  const _Validation(this.c);

  @override
  State<_Validation> createState() => _ValidationState();
}

class _ValidationState extends State<_Validation> {
  String? _tricycle;
  DateTime _debut = SperoStore.jour(DateTime.now());
  final _montant = TextEditingController(text: '10000');
  final _salaire = TextEditingController(text: '75000');
  final _caution = TextEditingController(text: '50000');
  final _garant = TextEditingController();
  final _telGarant = TextEditingController(text: '+229 01 ');

  @override
  void initState() {
    super.initState();
    final store = context.read<SperoStore>();
    _tricycle = store.tricycles.where((t) => store.chauffeurDe(t.id) == null).firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final c = widget.c;
    InputDecoration fcfaDeco(String l) => InputDecoration(
      labelText: l,
      suffixIcon: const Padding(padding: EdgeInsets.all(14), child: Text('FCFA')),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Valider et attribuer un tricycle', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _tricycle,
              decoration: const InputDecoration(labelText: 'Tricycle'),
              items: [
                for (final t in store.tricycles)
                  DropdownMenuItem(
                    value: t.id,
                    child: Text('${t.id} · ${store.chauffeurDe(t.id) == null ? 'disponible' : 'loué à ${store.chauffeurDe(t.id)!.nom}'}'),
                  ),
              ],
              onChanged: (v) => setState(() => _tricycle = v),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.event_rounded),
                title: const Text('Début du contrat'),
                subtitle: Text(DateFormatSimple.dateLongue(_debut)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _debut,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) setState(() => _debut = d);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _montant,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fcfaDeco('Dépôt journalier'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _salaire,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fcfaDeco('Salaire mensuel'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caution,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fcfaDeco('Caution'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _garant,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Garant (facultatif)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telGarant,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone du garant'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
                final m = int.tryParse(_montant.text) ?? 0;
                if (_tricycle == null || m <= 0) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Choisissez un tricycle et un dépôt journalier.')));
                  return;
                }
                await store.validerInscription(
                  c,
                  tricycleId: _tricycle!,
                  debut: _debut,
                  montantJournalier: m,
                  salaireMensuel: int.tryParse(_salaire.text) ?? 0,
                  caution: int.tryParse(_caution.text) ?? 0,
                  garant: _garant.text.trim(),
                  telephoneGarant: _garant.text.trim().isEmpty ? '' : _telGarant.text.trim(),
                );
                if (context.mounted) messageSucces(context, '${c.nom} validé. Il doit maintenant accepter son contrat.');
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Valider l\'inscription'),
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
                  context,
                  titre: 'Refuser l\'inscription',
                  libelle: 'Motif (visible par le chauffeur)',
                  bouton: 'Refuser',
                );
                if (motif != null) await store.refuserInscription(c, motif);
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Refuser'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paiement du salaire d'un chauffeur par le propriétaire.
Future<void> payerSalaire(BuildContext context, Chauffeur c) async {
  final store = context.read<SperoStore>();
  final montant = TextEditingController(text: '${c.salaireMensuel}');
  var mode = c.modeHabituel == ModePaiement.moovMoney ? ModeSalaire.moovMoney : ModeSalaire.mtnMomo;
  final now = DateTime.now();
  final periodes = [DateFormatSimple.moisAnnee(DateTime(now.year, now.month - 1)), DateFormatSimple.moisAnnee(now)];
  var periode = periodes.last;
  final dejaPaye = store.salairesDe(c.id).map((p) => p.periode).toSet();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Payer le salaire de ${c.nom}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              const Text('Période', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in periodes)
                    ChoiceChip(
                      label: Text(dejaPaye.contains(p) ? '$p (déjà payé)' : p),
                      selected: periode == p,
                      showCheckmark: false,
                      selectedColor: SperoColors.vert,
                      labelStyle: TextStyle(color: periode == p ? Colors.white : null, fontWeight: FontWeight.w600),
                      onSelected: (_) => setS(() => periode = p),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: montant,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  suffixIcon: Padding(padding: EdgeInsets.all(14), child: Text('FCFA')),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ModeSalaire>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Moyen de paiement'),
                items: [for (final m in ModeSalaire.values) DropdownMenuItem(value: m, child: Text(m.libelle))],
                onChanged: (v) => setS(() => mode = v!),
              ),
              const SizedBox(height: 8),
              Text(
                mode == ModeSalaire.especes
                    ? 'Paiement en main propre, enregistré pour le suivi.'
                    : 'Vers ${c.telephone}. Paiement simulé dans la démonstration.',
                style: TextStyle(fontSize: 12.5, color: couleurGris(ctx)),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  final m = int.tryParse(montant.text) ?? 0;
                  if (m <= 0) return;
                  await store.payerSalaire(c, m, mode, periode);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) messageSucces(context, 'Salaire de ${fcfa(m)} payé à ${c.nom}. Il est prévenu.');
                },
                child: const Text('Payer'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
