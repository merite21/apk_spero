import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

InputDecoration _champ(String libelle, {String? aide, Widget? suffixe}) =>
    InputDecoration(labelText: libelle, helperText: aide, suffixIcon: suffixe);

int? _entier(String s) => int.tryParse(s.replaceAll(RegExp(r'\s'), ''));

class _Page extends StatelessWidget {
  final String titre;
  final List<Widget> enfants;
  final Widget bouton;
  const _Page({required this.titre, required this.enfants, required this.bouton});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: Largeur(
        max: 620,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [...enfants, const SizedBox(height: 24), bouton]),
      ),
    );
  }
}

class _ChoixTricycle extends StatelessWidget {
  final String? valeur;
  final ValueChanged<String?> onChanged;
  final bool vide;
  const _ChoixTricycle({required this.valeur, required this.onChanged, this.vide = false});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      initialValue: valeur,
      decoration: _champ('Tricycle'),
      items: [
        if (vide) const DropdownMenuItem(value: null, child: Text('Aucun')),
        for (final t in store.tricycles)
          DropdownMenuItem(value: t.id, child: Text('${t.id} · ${store.chauffeurDe(t.id)?.nom ?? 'disponible'}')),
      ],
      onChanged: onChanged,
    );
  }
}

// ---------------- Versement ----------------

class NouveauVersement extends StatefulWidget {
  final String? chauffeurId;
  const NouveauVersement({super.key, this.chauffeurId});

  @override
  State<NouveauVersement> createState() => _NouveauVersementState();
}

class _NouveauVersementState extends State<NouveauVersement> {
  String? _chauffeur;
  final _montant = TextEditingController();
  ModePaiement _mode = ModePaiement.especes;

  @override
  void initState() {
    super.initState();
    _chauffeur = widget.chauffeurId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _preremplir());
  }

  void _preremplir() {
    final store = context.read<SperoStore>();
    final c = store.chauffeur(_chauffeur);
    if (c == null) return;
    final s = store.situation(c);
    setState(() {
      _montant.text = (s.resteAujourdhui > 0 ? s.resteAujourdhui : c.montantJournalier).toString();
      _mode = c.modeHabituel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final c = store.chauffeur(_chauffeur);
    final s = c == null ? null : store.situation(c);
    return _Page(
      titre: 'Dépôt en espèces',
      enfants: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _chauffeur,
          decoration: _champ('Chauffeur'),
          items: [
            for (final ch in store.chauffeursActifs) DropdownMenuItem(value: ch.id, child: Text('${ch.nom} · ${ch.tricycleId ?? '-'}')),
          ],
          onChanged: (v) {
            setState(() => _chauffeur = v);
            _preremplir();
          },
        ),
        if (s != null) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _ligne('Montant journalier', fcfa(c!.montantJournalier)),
                  _ligne('Arriérés', fcfa(s.arrieres), couleur: s.arrieres > 0 ? SperoColors.rouge : null),
                  if (s.avance > 0) _ligne('Avance', fcfa(s.avance), couleur: SperoColors.vert),
                  const Divider(),
                  _ligne('Reste à payer aujourd\'hui', fcfa(s.resteAujourdhui), gras: true),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _montant,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: _champ(
            'Montant reçu',
            suffixe: const Padding(padding: EdgeInsets.all(14), child: Text('FCFA')),
          ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.always),
        ),
        const SizedBox(height: 16),
        const Text('Mode de paiement', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SegmentedButton<ModePaiement>(
          segments: [for (final m in ModePaiement.values) ButtonSegment(value: m, label: Text(m.libelle))],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => _mode = v.first),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.sms_outlined, size: 18, color: couleurGris(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c == null ? 'Un SMS de reçu sera envoyé au chauffeur.' : 'Un SMS de reçu sera envoyé au ${c.telephone}.',
                style: TextStyle(color: couleurGris(context), fontSize: 13),
              ),
            ),
          ],
        ),
      ],
      bouton: FilledButton(
        onPressed: () async {
          final m = _entier(_montant.text);
          if (c == null || m == null || m <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez un chauffeur et un montant.')));
            return;
          }
          await store.enregistrerVersement(c, m, _mode);
          if (!context.mounted) return;
          Navigator.pop(context);
          messageSucces(context, '${fcfa(m)} enregistrés pour ${c.nom}. Reçu envoyé par SMS.');
        },
        child: const Text('Enregistrer le dépôt'),
      ),
    );
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

// ---------------- Dépense ----------------

class NouvelleDepense extends StatefulWidget {
  final String? tricycleId;
  const NouvelleDepense({super.key, this.tricycleId});

  @override
  State<NouvelleDepense> createState() => _NouvelleDepenseState();
}

class _NouvelleDepenseState extends State<NouvelleDepense> {
  String? _tricycle;
  CategorieDepense _cat = CategorieDepense.reparation;
  final _montant = TextEditingController();
  final _desc = TextEditingController();
  bool _recu = false;

  @override
  void initState() {
    super.initState();
    _tricycle = widget.tricycleId;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final m = _entier(_montant.text) ?? 0;
    final validation = store.role != Role.admin && (m > store.parametres.seuilDepense || !_recu);
    return _Page(
      titre: 'Nouvelle dépense',
      enfants: [
        _ChoixTricycle(valeur: _tricycle, onChanged: (v) => setState(() => _tricycle = v)),
        const SizedBox(height: 14),
        const Text('Type de dépense', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in CategorieDepense.values)
              ChoiceChip(
                label: Text(c.libelle),
                selected: _cat == c,
                showCheckmark: false,
                selectedColor: SperoColors.vert,
                labelStyle: TextStyle(color: _cat == c ? Colors.white : null, fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() => _cat = c),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _montant,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: _champ(
            'Montant',
            suffixe: const Padding(padding: EdgeInsets.all(14), child: Text('FCFA')),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _desc,
          decoration: _champ('Description', aide: 'Ex. Remplacement plaquettes de frein'),
        ),
        const SizedBox(height: 14),
        Card(
          child: SwitchListTile(
            value: _recu,
            onChanged: (v) => setState(() => _recu = v),
            secondary: const Icon(Icons.photo_camera_outlined),
            title: const Text('Photo du reçu prise'),
            subtitle: const Text('La prise de photo sera active sur la version installée'),
          ),
        ),
        if (validation) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: SperoColors.jauneClair, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: SperoColors.surJaune),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    !_recu
                        ? 'Sans reçu, cette dépense devra être validée par le propriétaire.'
                        : 'Au-dessus de ${fcfa(store.parametres.seuilDepense)}, cette dépense devra être validée par le propriétaire.',
                    style: const TextStyle(color: SperoColors.surJaune),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
      bouton: FilledButton(
        onPressed: () async {
          if (_tricycle == null || m <= 0 || _desc.text.trim().isEmpty) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Remplissez le tricycle, le montant et la description.')));
            return;
          }
          await store.ajouterDepense(tricycleId: _tricycle!, categorie: _cat, montant: m, description: _desc.text.trim(), avecRecu: _recu);
          if (!context.mounted) return;
          Navigator.pop(context);
          messageSucces(context, validation ? 'Dépense envoyée au propriétaire pour validation.' : 'Dépense enregistrée.');
        },
        child: const Text('Enregistrer la dépense'),
      ),
    );
  }
}

// ---------------- Incident ----------------

class NouvelIncident extends StatefulWidget {
  final String? tricycleId;
  const NouvelIncident({super.key, this.tricycleId});

  @override
  State<NouvelIncident> createState() => _NouvelIncidentState();
}

class _NouvelIncidentState extends State<NouvelIncident> {
  String? _tricycle;
  String _type = 'Panne';
  final _desc = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tricycle = widget.tricycleId;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<SperoStore>();
    return _Page(
      titre: 'Déclarer un incident',
      enfants: [
        _ChoixTricycle(valeur: _tricycle, onChanged: (v) => setState(() => _tricycle = v)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in ['Panne', 'Accident', 'Vol', 'Police / fourrière', 'Chauffeur injoignable', 'Autre'])
              ChoiceChip(
                label: Text(t),
                selected: _type == t,
                showCheckmark: false,
                selectedColor: SperoColors.rouge,
                labelStyle: TextStyle(color: _type == t ? Colors.white : null, fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(controller: _desc, maxLines: 4, decoration: _champ('Ce qui s\'est passé')),
      ],
      bouton: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: SperoColors.rouge),
        onPressed: () async {
          if (_tricycle == null || _desc.text.trim().isEmpty) return;
          await store.declarerIncident(_tricycle!, _type, _desc.text.trim());
          if (!context.mounted) return;
          Navigator.pop(context);
          messageSucces(context, 'Incident déclaré. Le propriétaire est prévenu.');
        },
        child: const Text('Déclarer l\'incident'),
      ),
    );
  }
}

// ---------------- Inspection ----------------

class NouvelleInspection extends StatefulWidget {
  final String? tricycleId;
  const NouvelleInspection({super.key, this.tricycleId});

  @override
  State<NouvelleInspection> createState() => _NouvelleInspectionState();
}

class _NouvelleInspectionState extends State<NouvelleInspection> {
  String? _tricycle;
  final Map<String, bool> _points = {for (final p in pointsInspection) p: true};
  final _moteur = TextEditingController();
  final _comm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tricycle = widget.tricycleId;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<SperoStore>();
    final dernier = store.inspections.where((i) => i.tricycleId == _tricycle).toList()..sort((a, b) => b.date.compareTo(a.date));
    final ancienMoteur = dernier.isEmpty ? null : dernier.first.numeroMoteur;
    final moteurChange = ancienMoteur != null && _moteur.text.isNotEmpty && _moteur.text.trim() != ancienMoteur;
    return _Page(
      titre: 'Inspection',
      enfants: [
        _ChoixTricycle(valeur: _tricycle, onChanged: (v) => setState(() => _tricycle = v)),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              for (final p in pointsInspection)
                CheckboxListTile(
                  value: _points[p],
                  onChanged: (v) => setState(() => _points[p] = v ?? false),
                  title: Text(p),
                  subtitle: _points[p]! ? null : const Text('Non conforme', style: TextStyle(color: SperoColors.rouge)),
                  activeColor: SperoColors.vert,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _moteur,
          onChanged: (_) => setState(() {}),
          decoration: _champ(
            'Numéro du moteur',
            aide: ancienMoteur == null ? 'Relevé sur le bloc moteur' : 'Dernier relevé : $ancienMoteur',
          ),
        ),
        if (moteurChange)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Attention : le numéro ne correspond pas au dernier relevé. Le moteur a peut-être été échangé.',
              style: TextStyle(color: SperoColors.rouge, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 14),
        TextField(controller: _comm, maxLines: 3, decoration: _champ('Commentaire')),
      ],
      bouton: FilledButton(
        onPressed: () async {
          if (_tricycle == null || _moteur.text.trim().isEmpty) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Choisissez le tricycle et relevez le numéro du moteur.')));
            return;
          }
          await store.ajouterInspection(
            _tricycle!,
            Map.of(_points),
            _moteur.text.trim(),
            _comm.text.trim().isEmpty ? 'RAS' : _comm.text.trim(),
          );
          if (moteurChange) {
            await store.declarerIncident(_tricycle!, 'Numéro moteur différent', 'Relevé ${_moteur.text.trim()} au lieu de $ancienMoteur');
          }
          if (!context.mounted) return;
          Navigator.pop(context);
          messageSucces(context, 'Inspection enregistrée.');
        },
        child: const Text('Enregistrer l\'inspection'),
      ),
    );
  }
}

// ---------------- Chauffeur / contrat ----------------

class FormulaireChauffeur extends StatefulWidget {
  final String? chauffeurId;
  const FormulaireChauffeur({super.key, this.chauffeurId});

  @override
  State<FormulaireChauffeur> createState() => _FormulaireChauffeurState();
}

class _FormulaireChauffeurState extends State<FormulaireChauffeur> {
  late final Chauffeur _c;
  late final bool _nouveau;
  final _nom = TextEditingController();
  final _tel = TextEditingController();
  final _piece = TextEditingController();
  final _garant = TextEditingController();
  final _telGarant = TextEditingController();
  final _montant = TextEditingController();
  final _caution = TextEditingController();
  final _salaire = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = context.read<SperoStore>();
    final existant = store.chauffeur(widget.chauffeurId);
    _nouveau = existant == null;
    _c =
        existant ??
        Chauffeur(
          id: 'CH-${DateTime.now().millisecondsSinceEpoch}',
          nom: '',
          telephone: '+229 01 ',
          pieceIdentite: '',
          garant: '',
          telephoneGarant: '+229 01 ',
          tricycleId: store.tricycles.where((t) => store.chauffeurDe(t.id) == null).firstOrNull?.id,
          montantJournalier: 5000,
          caution: 50000,
          debutContrat: SperoStore.jour(DateTime.now()),
        );
    _nom.text = _c.nom;
    _tel.text = _c.telephone;
    _piece.text = _c.pieceIdentite;
    _garant.text = _c.garant;
    _telGarant.text = _c.telephoneGarant;
    _montant.text = _c.montantJournalier.toString();
    _caution.text = _c.caution.toString();
    _salaire.text = _c.salaireMensuel.toString();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<SperoStore>();
    return _Page(
      titre: _nouveau ? 'Nouveau contrat' : 'Modifier le contrat',
      enfants: [
        const TitreSection('Chauffeur'),
        TextField(controller: _nom, decoration: _champ('Nom complet')),
        const SizedBox(height: 12),
        TextField(controller: _tel, keyboardType: TextInputType.phone, decoration: _champ('Téléphone')),
        const SizedBox(height: 12),
        TextField(
          controller: _piece,
          decoration: _champ('Pièce d\'identité', aide: 'CIP, CNI ou passeport'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _garant, decoration: _champ('Garant')),
        const SizedBox(height: 12),
        TextField(controller: _telGarant, keyboardType: TextInputType.phone, decoration: _champ('Téléphone du garant')),
        const TitreSection('Contrat de location'),
        _ChoixTricycle(valeur: _c.tricycleId, vide: true, onChanged: (v) => setState(() => _c.tricycleId = v)),
        const SizedBox(height: 12),
        TextField(
          controller: _montant,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _champ(
            'Versement journalier',
            suffixe: const Padding(padding: EdgeInsets.all(14), child: Text('FCFA')),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _salaire,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _champ(
            'Salaire mensuel',
            suffixe: const Padding(padding: EdgeInsets.all(14), child: Text('FCFA')),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _caution,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _champ(
            'Caution versée',
            suffixe: const Padding(padding: EdgeInsets.all(14), child: Text('FCFA')),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.event_rounded),
                title: const Text('Début du contrat'),
                subtitle: Text(DateFormatSimple.dateLongue(_c.debutContrat)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _c.debutContrat,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (d != null) setState(() => _c.debutContrat = d);
                },
              ),
              SwitchListTile(
                value: _c.reposDimanche,
                onChanged: (v) => setState(() => _c.reposDimanche = v),
                secondary: const Icon(Icons.weekend_outlined),
                title: const Text('Repos le dimanche'),
                subtitle: const Text('Pas de versement dû le dimanche'),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Horaires autorisés'),
                subtitle: Text('De ${_c.heureDebut} h à ${_c.heureFin} h'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<int>(
                      value: _c.heureDebut,
                      items: [for (var h = 4; h <= 9; h++) DropdownMenuItem(value: h, child: Text('$h h'))],
                      onChanged: (v) => setState(() => _c.heureDebut = v!),
                    ),
                    const Text(' → '),
                    DropdownButton<int>(
                      value: _c.heureFin,
                      items: [for (var h = 19; h <= 24; h++) DropdownMenuItem(value: h, child: Text('$h h'))],
                      onChanged: (v) => setState(() => _c.heureFin = v!),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ModePaiement>(
          initialValue: _c.modeHabituel,
          decoration: _champ('Mode de paiement habituel'),
          items: [for (final m in ModePaiement.values) DropdownMenuItem(value: m, child: Text(m.libelle))],
          onChanged: (v) => setState(() => _c.modeHabituel = v!),
        ),
        if (!_nouveau) ...[
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: _c.actif,
              onChanged: (v) => setState(() => _c.actif = v),
              title: const Text('Contrat actif'),
              subtitle: const Text('Désactiver met fin au contrat et libère le tricycle'),
            ),
          ),
        ],
      ],
      bouton: FilledButton(
        onPressed: () async {
          final montant = _entier(_montant.text);
          if (_nom.text.trim().isEmpty || montant == null || montant <= 0) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Le nom et le versement journalier sont obligatoires.')));
            return;
          }
          _c
            ..nom = _nom.text.trim()
            ..telephone = _tel.text.trim()
            ..pieceIdentite = _piece.text.trim()
            ..garant = _garant.text.trim()
            ..telephoneGarant = _telGarant.text.trim()
            ..montantJournalier = montant
            ..caution = _entier(_caution.text) ?? 0
            ..salaireMensuel = _entier(_salaire.text) ?? 0;
          if (!_c.actif) _c.tricycleId = null;
          await store.enregistrerChauffeur(_c, nouveau: _nouveau);
          if (!context.mounted) return;
          Navigator.pop(context);
          messageSucces(context, _nouveau ? 'Contrat de ${_c.nom} créé.' : 'Contrat enregistré.');
        },
        child: Text(_nouveau ? 'Créer le contrat' : 'Enregistrer'),
      ),
    );
  }
}

// ---------------- Tricycle ----------------

class FormulaireTricycle extends StatefulWidget {
  const FormulaireTricycle({super.key});

  @override
  State<FormulaireTricycle> createState() => _FormulaireTricycleState();
}

class _FormulaireTricycleState extends State<FormulaireTricycle> {
  final _immat = TextEditingController();
  final _imei = TextEditingController();
  final _cout = TextEditingController(text: '1450000');
  final _km = TextEditingController(text: '0');

  @override
  Widget build(BuildContext context) {
    final store = context.read<SperoStore>();
    final prochain = 'TC-${(store.tricycles.length + 1).toString().padLeft(2, '0')}';
    return _Page(
      titre: 'Nouveau tricycle · $prochain',
      enfants: [
        TextField(controller: _immat, decoration: _champ('Immatriculation')),
        const SizedBox(height: 12),
        TextField(
          controller: _imei,
          keyboardType: TextInputType.number,
          decoration: _champ('IMEI du traceur GPS', aide: 'Inscrit sur le boîtier du traceur'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cout,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _champ(
            'Coût d\'achat',
            suffixe: const Padding(padding: EdgeInsets.all(14), child: Text('FCFA')),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _km,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _champ(
            'Kilométrage actuel',
            suffixe: const Padding(padding: EdgeInsets.all(14), child: Text('km')),
          ),
        ),
      ],
      bouton: FilledButton(
        onPressed: () async {
          if (_immat.text.trim().isEmpty) return;
          final km = _entier(_km.text) ?? 0;
          await store.enregistrerTricycle(
            Tricycle(
              id: prochain,
              immatriculation: _immat.text.trim(),
              imeiTraceur: _imei.text.trim(),
              coutAchat: _entier(_cout.text) ?? 0,
              dateAchat: DateTime.now(),
              kilometrage: km.toDouble(),
              kmDerniereVidange: km,
            ),
            nouveau: true,
          );
          if (!context.mounted) return;
          Navigator.pop(context);
          messageSucces(context, 'Tricycle $prochain ajouté.');
        },
        child: const Text('Ajouter le tricycle'),
      ),
    );
  }
}
