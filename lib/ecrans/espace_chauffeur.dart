import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'contrat.dart';
import 'depots.dart';

/// Application côté chauffeur.
class EspaceChauffeur extends StatefulWidget {
  const EspaceChauffeur({super.key});

  @override
  State<EspaceChauffeur> createState() => _EspaceChauffeurState();
}

class _EspaceChauffeurState extends State<EspaceChauffeur> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final c = store.moi;
    if (c == null) return const Scaffold(body: Vide(Icons.person_off, 'Compte introuvable'));
    if (c.statut != StatutInscription.valide) return _EnAttente(c);

    final pages = [_AccueilChauffeur(c, allerA: (i) => setState(() => _index = i)), _MesDepots(c), _MonContrat(c), _Profil(c)];
    final contratBadge = !c.contratAccepte;
    return Scaffold(
      body: Largeur(
        max: 720,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Mes dépôts',
          ),
          NavigationDestination(
            icon: Badge(isLabelVisible: contratBadge, backgroundColor: SperoColors.rouge, child: const Icon(Icons.description_outlined)),
            selectedIcon: Badge(
              isLabelVisible: contratBadge,
              backgroundColor: SperoColors.rouge,
              child: const Icon(Icons.description_rounded),
            ),
            label: 'Contrat',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}

// ---------------- Inscription en attente / refusée ----------------

class _EnAttente extends StatelessWidget {
  final Chauffeur c;
  const _EnAttente(this.c);

  @override
  Widget build(BuildContext context) {
    final refuse = c.statut == StatutInscription.refuse;
    Widget etape(String t, bool fait, {bool enCours = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            fait ? Icons.check_circle : (enCours ? Icons.hourglass_top_rounded : Icons.radio_button_unchecked),
            color: fait ? SperoColors.vert : (enCours ? const Color(0xFFC9A400) : couleurGris(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(t, style: TextStyle(fontWeight: enCours ? FontWeight.w800 : FontWeight.w500)),
          ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Largeur(
          max: 520,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.read<SperoStore>().deconnecter(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                ),
              ),
              Center(child: PhotoBase64(c.photoVisage, hauteur: 110, rond: true, vide: 'Photo')),
              const SizedBox(height: 16),
              Text(
                'Bonjour ${c.prenom}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                refuse ? 'Votre inscription n\'a pas été acceptée.' : 'Votre inscription a bien été envoyée.',
                textAlign: TextAlign.center,
                style: TextStyle(color: couleurGris(context), fontSize: 16),
              ),
              const SizedBox(height: 24),
              if (refuse)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Motif', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(c.motifRefus ?? '-'),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        etape('Inscription envoyée le ${DateFormatSimple.date(c.dateInscription)}', true),
                        etape('Vérification de votre dossier par le propriétaire', false, enCours: true),
                        etape('Attribution de votre tricycle', false),
                        etape('Lecture et acceptation du contrat', false),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (!refuse)
                Text(
                  'Vous recevrez une notification dès que le propriétaire aura validé votre compte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: couleurGris(context)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Accueil ----------------

class _AccueilChauffeur extends StatelessWidget {
  final Chauffeur c;
  final void Function(int) allerA;
  const _AccueilChauffeur(this.c, {required this.allerA});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final notifs = store.notificationsChauffeur(c);
    final urgentes = notifs.where((n) => n.niveau != Niveau.ok).length;
    void ouvrir(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: SperoColors.vert,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 26),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: SperoColors.jaune, width: 3),
                      ),
                      child: PhotoBase64(c.photoVisage, hauteur: 52, rond: true, vide: ''),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour ${c.prenom}',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${c.tricycleId ?? 'Pas de tricycle'} · ${DateFormatSimple.dateLongue(DateTime.now())}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => ouvrir(_Notifications(c)),
                      icon: Badge(
                        isLabelVisible: urgentes > 0,
                        label: Text('$urgentes'),
                        backgroundColor: SperoColors.rouge,
                        child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          sliver: SliverList.list(
            children: [
              if (!c.contratAccepte) ...[
                Card(
                  color: estSombre(context) ? const Color(0xFF3A1419) : SperoColors.rougeClair,
                  child: ListTile(
                    leading: const Icon(Icons.description_rounded, color: SperoColors.rouge),
                    title: const Text('Votre contrat vous attend', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Lisez-le et acceptez-le pour commencer.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => allerA(2),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              CarteDepotDuJour(c, onDeposer: () => ouvrir(EcranDepot(c))),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  child: Grille(
                    colonnes: 4,
                    colonnesLarge: 4,
                    ecart: 4,
                    enfants: [
                      TuileAction(
                        icone: Icons.send_to_mobile_rounded,
                        libelle: 'Déposer',
                        couleur: SperoColors.vert,
                        fond: SperoColors.vertClair,
                        onTap: () => ouvrir(EcranDepot(c)),
                      ),
                      TuileAction(
                        icone: Icons.receipt_long_rounded,
                        libelle: 'Mes dépôts',
                        couleur: SperoColors.jaune,
                        fond: SperoColors.jauneClair,
                        onTap: () => allerA(1),
                      ),
                      TuileAction(
                        icone: Icons.account_balance_wallet_rounded,
                        libelle: 'Mon salaire',
                        couleur: SperoColors.vert,
                        fond: SperoColors.vertClair,
                        onTap: () => ouvrir(_MonSalaire(c)),
                      ),
                      TuileAction(
                        icone: Icons.description_rounded,
                        libelle: 'Contrat',
                        couleur: SperoColors.rouge,
                        fond: SperoColors.rougeClair,
                        onTap: () => allerA(2),
                      ),
                    ],
                  ),
                ),
              ),
              TitreSection(
                'Notifications',
                action: TextButton(onPressed: () => ouvrir(_Notifications(c)), child: const Text('Tout voir')),
              ),
              if (notifs.isEmpty) const Card(child: Vide(Icons.notifications_none, 'Aucune notification')),
              for (final n in notifs.take(4)) ...[CarteAlerte(n), const SizedBox(height: 8)],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- Dépôt ----------------

class EcranDepot extends StatefulWidget {
  final Chauffeur c;
  const EcranDepot(this.c, {super.key});

  @override
  State<EcranDepot> createState() => _EcranDepotState();
}

class _EcranDepotState extends State<EcranDepot> {
  final _montant = TextEditingController();
  ModePaiement _mode = ModePaiement.mtnMomo;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<SperoStore>();
    final s = store.situation(widget.c);
    _montant.text = '${s.resteAujourdhui > 0 ? s.resteAujourdhui : widget.c.montantJournalier}';
    if (widget.c.modeHabituel != ModePaiement.especes) _mode = widget.c.modeHabituel;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final c = widget.c;
    final s = store.situation(c);
    final montant = int.tryParse(_montant.text) ?? 0;
    final apres = (s.resteAujourdhui - montant).clamp(0, 1 << 31);

    Widget puce(String t, int m) => ActionChip(
      label: Text('$t · ${nombre(m)}'),
      onPressed: () => setState(() => _montant.text = '$m'),
      backgroundColor: montant == m ? SperoColors.vertClair : null,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: montant == m ? SperoColors.vertFonce : null),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Faire un dépôt')),
      body: Largeur(
        max: 560,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _ligne('Dû aujourd\'hui', fcfa(s.duAujourdhui)),
                    _ligne('Déjà déposé aujourd\'hui', fcfa(s.deposeAujourdhui)),
                    if (s.arrieres > 0) _ligne('Arriérés', fcfa(s.arrieres), couleur: SperoColors.rouge),
                    const Divider(),
                    _ligne('Reste à déposer', fcfa(s.resteAujourdhui), gras: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s.manqueAujourdhui > 0) puce('Aujourd\'hui', s.manqueAujourdhui),
                if (s.arrieres > 0) puce('Tout régler', s.resteAujourdhui),
                puce('Une journée', c.montantJournalier),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _montant,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                labelText: 'Montant à déposer',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixIcon: Padding(padding: EdgeInsets.all(14), child: Text('FCFA')),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              montant <= 0
                  ? ''
                  : apres == 0
                  ? 'Après ce dépôt, vous serez à jour.'
                  : 'Après ce dépôt, il manquera encore ${fcfa(apres)}.',
              style: TextStyle(color: apres == 0 ? SperoColors.vert : const Color(0xFF9A7D00), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            const Text('Payer avec', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final m in [ModePaiement.mtnMomo, ModePaiement.moovMoney]) ...[
                  if (m == ModePaiement.moovMoney) const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _mode = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _mode == m ? SperoColors.vert : Theme.of(context).dividerColor,
                            width: _mode == m ? 2.5 : 1,
                          ),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.phone_android_rounded,
                              color: m == ModePaiement.mtnMomo ? const Color(0xFFC9A400) : const Color(0xFF1565C0),
                            ),
                            const SizedBox(height: 4),
                            Text(m.libelle, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.account_balance_rounded, size: 18, color: couleurGris(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Vers le compte du propriétaire de la flotte Spero', style: TextStyle(color: couleurGris(context))),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _envoi || montant <= 0 ? null : () => _payer(store, montant),
              child: Text('Déposer ${montant > 0 ? fcfa(montant) : ''}'),
            ),
            const SizedBox(height: 10),
            Text(
              'Démonstration : le paiement Mobile Money est simulé. Une fois branché, vous confirmerez avec votre code secret sur votre téléphone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: couleurGris(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _payer(SperoStore store, int montant) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.phone_android_rounded, color: SperoColors.vert, size: 36),
        title: Text('Confirmer ${fcfa(montant)}'),
        content: Text('Un message ${_mode.libelle} va s\'afficher sur votre téléphone. Entrez votre code secret pour valider le dépôt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('J\'ai validé'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _envoi = true);
    await store.deposer(widget.c, montant, _mode);
    if (!mounted) return;
    Navigator.pop(context);
    messageSucces(context, 'Dépôt de ${fcfa(montant)} envoyé. Il sera compté dès que le propriétaire aura confirmé la réception.');
  }

  Widget _ligne(String a, String b, {Color? couleur, bool gras = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(a, style: TextStyle(fontWeight: gras ? FontWeight.w800 : FontWeight.w500)),
        ),
        Text(
          b,
          style: TextStyle(fontWeight: FontWeight.w800, color: couleur),
        ),
      ],
    ),
  );
}

// ---------------- Mes dépôts ----------------

class _MesDepots extends StatelessWidget {
  final Chauffeur c;
  const _MesDepots(this.c);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final s = store.situation(c);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes dépôts')),
      floatingActionButton: s.resteAujourdhui > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EcranDepot(c))),
              backgroundColor: SperoColors.vert,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.send_to_mobile_rounded),
              label: const Text('Déposer', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Grille(
            enfants: [
              Indicateur(
                valeur: nombre(s.arrieres),
                libelle: 'Arriérés (FCFA)',
                icone: Icons.hourglass_bottom_rounded,
                couleur: s.arrieres > 0 ? SperoColors.rouge : SperoColors.vert,
              ),
              Indicateur(valeur: nombre(s.totalPaye), libelle: 'Total déposé (FCFA)', icone: Icons.savings_outlined),
            ],
          ),
          const TitreSection('30 derniers jours'),
          CalendrierDepots(c),
          const TitreSection('Jour par jour'),
          ListeJoursDepots(c),
          const SizedBox(height: 8),
          Text(
            'Quand un dépôt dépasse le montant du jour, le surplus rembourse d\'abord les jours incomplets les plus anciens.',
            style: TextStyle(fontSize: 12.5, color: couleurGris(context)),
          ),
        ],
      ),
    );
  }
}

// ---------------- Contrat ----------------

class _MonContrat extends StatelessWidget {
  final Chauffeur c;
  const _MonContrat(this.c);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon contrat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          ContratVue(c),
          if (!c.contratAccepte) ...[const SizedBox(height: 12), AcceptationContrat(c)],
        ],
      ),
    );
  }
}

// ---------------- Salaire ----------------

class _MonSalaire extends StatelessWidget {
  final Chauffeur c;
  const _MonSalaire(this.c);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final liste = store.salairesDe(c.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: const Text('Mon salaire')),
      body: Largeur(
        max: 560,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          children: [
            Indicateur(
              valeur: fcfa(c.salaireMensuel),
              libelle: 'Salaire mensuel prévu au contrat',
              icone: Icons.account_balance_wallet_rounded,
            ),
            const TitreSection('Salaires reçus'),
            Card(
              child: liste.isEmpty
                  ? const Vide(Icons.hourglass_empty, 'Aucun salaire reçu pour l\'instant')
                  : Column(
                      children: [
                        for (final p in liste)
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: SperoColors.vertClair,
                              child: Icon(Icons.south_west_rounded, color: SperoColors.vert),
                            ),
                            title: Text(p.periode, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${DateFormatSimple.relative(p.date)} · ${p.mode.libelle}'),
                            trailing: Text(fcfa(p.montant), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Notifications ----------------

class _Notifications extends StatelessWidget {
  final Chauffeur c;
  const _Notifications(this.c);

  @override
  Widget build(BuildContext context) {
    final notifs = context.watch<SperoStore>().notificationsChauffeur(c);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Largeur(
        max: 600,
        child: notifs.isEmpty
            ? const Vide(Icons.notifications_none, 'Aucune notification')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notifs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => CarteAlerte(notifs[i]),
              ),
      ),
    );
  }
}

// ---------------- Profil ----------------

class _Profil extends StatelessWidget {
  final Chauffeur c;
  const _Profil(this.c);

  @override
  Widget build(BuildContext context) {
    Widget info(IconData i, String a, String b) => ListTile(
      dense: true,
      leading: Icon(i, size: 20, color: couleurGris(context)),
      title: Text(a, style: TextStyle(color: couleurGris(context))),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          b,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          Center(child: PhotoBase64(c.photoVisage, hauteur: 110, rond: true, vide: 'Photo')),
          const SizedBox(height: 12),
          Text(
            c.nom,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                info(Icons.phone_outlined, 'Téléphone', c.telephone),
                info(Icons.alternate_email, 'E-mail', c.email ?? '-'),
                info(Icons.badge_outlined, 'CIP', c.pieceIdentite),
                info(Icons.receipt_outlined, 'IFU', c.ifu ?? '-'),
                info(Icons.electric_rickshaw_rounded, 'Tricycle', c.tricycleId ?? '-'),
                info(Icons.event_rounded, 'Début du contrat', DateFormatSimple.date(c.debutContrat)),
              ],
            ),
          ),
          const TitreSection('Photo de la CIP'),
          PhotoBase64(c.photoCip, hauteur: 190, vide: 'Pas de photo (compte de démonstration)'),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: SperoColors.rouge,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => context.read<SperoStore>().deconnecter(),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
