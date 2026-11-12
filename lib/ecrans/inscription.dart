import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Inscription d'un chauffeur depuis l'application, en 4 étapes.
/// Le compte reste « en attente » tant que le propriétaire ne l'a pas validé.
class Inscription extends StatefulWidget {
  const Inscription({super.key});

  @override
  State<Inscription> createState() => _InscriptionState();
}

class _InscriptionState extends State<Inscription> {
  int _etape = 0;
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _tel = TextEditingController(text: '+229 01 ');
  final _email = TextEditingController();
  final _cip = TextEditingController();
  final _ifu = TextEditingController();
  final _mdp = TextEditingController();
  final _mdp2 = TextEditingController();
  String? _photoCip;
  String? _photoVisage;
  bool _consentement = false;
  bool _envoi = false;
  String? _erreur;

  static const _titres = ['Identité', 'Pièce d\'identité', 'Photo du visage', 'Mot de passe'];

  String? _verifier() {
    switch (_etape) {
      case 0:
        if (_prenom.text.trim().isEmpty || _nom.text.trim().isEmpty) return 'Indiquez votre prénom et votre nom.';
        if (_tel.text.replaceAll(RegExp(r'\D'), '').length < 11) return 'Indiquez un numéro de téléphone complet.';
        final e = _email.text.trim();
        if (e.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'L\'adresse e-mail n\'est pas valide.';
        if (_cip.text.trim().isEmpty) return 'Indiquez le numéro de votre CIP.';
      case 1:
        if (_photoCip == null) return 'Prenez une photo de votre CIP.';
      case 2:
        if (_photoVisage == null) return 'Prenez une photo de votre visage.';
      case 3:
        if (_mdp.text.length < 6) return 'Le mot de passe doit faire au moins 6 caractères.';
        if (_mdp.text != _mdp2.text) return 'Les deux mots de passe ne sont pas identiques.';
        if (!_consentement) return 'Cochez la case pour accepter l\'utilisation de vos données.';
    }
    return null;
  }

  Future<void> _suivant() async {
    final err = _verifier();
    setState(() => _erreur = err);
    if (err != null) return;
    if (_etape == 0) {
      setState(() => _envoi = true);
      final pris = await context.read<SperoStore>().identifiantDejaPris(_tel.text, _email.text.trim());
      if (!mounted) return;
      setState(() => _envoi = false);
      if (pris) {
        setState(() => _erreur = 'Ce téléphone ou cet e-mail a déjà un compte. Connectez-vous.');
        return;
      }
    }
    if (_etape < 3) {
      setState(() => _etape++);
      return;
    }
    setState(() => _envoi = true);
    final nav = Navigator.of(context);
    final store = context.read<SperoStore>();
    try {
      await store.inscrire(
        prenom: _prenom.text,
        nom: _nom.text,
        telephone: _tel.text,
        email: _email.text,
        cip: _cip.text,
        ifu: _ifu.text,
        photoCip: _photoCip!,
        photoVisage: _photoVisage!,
        motDePasse: _mdp.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _envoi = false;
          _erreur = e.toString().replaceFirst('Exception: ', '').contains('already registered')
              ? 'Ce numéro a déjà un compte. Connectez-vous.'
              : 'L\'inscription n\'a pas pu être envoyée : ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
      return;
    }
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer mon compte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _etape == 0 ? Navigator.pop(context) : setState(() => _etape--),
        ),
      ),
      body: Largeur(
        max: 560,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= _etape ? SperoColors.vert : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text('Étape ${_etape + 1} sur 4', style: TextStyle(color: couleurGris(context))),
            const SizedBox(height: 2),
            Text(_titres[_etape], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            ...switch (_etape) {
              0 => _identite(),
              1 => _piece(),
              2 => _visage(),
              _ => _motDePasse(),
            },
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  _erreur!,
                  style: const TextStyle(color: SperoColors.rouge, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _envoi ? null : _suivant, child: Text(_etape < 3 ? 'Continuer' : 'Envoyer mon inscription')),
          ],
        ),
      ),
    );
  }

  List<Widget> _identite() => [
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _prenom,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Prénom'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _nom,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _tel,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'E-mail (facultatif)', prefixIcon: Icon(Icons.alternate_email)),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _cip,
      decoration: const InputDecoration(labelText: 'Numéro de la CIP', prefixIcon: Icon(Icons.badge_outlined)),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _ifu,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'IFU (facultatif)',
        helperText: 'Identifiant fiscal unique, si vous en avez un',
        prefixIcon: Icon(Icons.receipt_outlined),
      ),
    ),
  ];

  List<Widget> _piece() => [
    Text(
      'Photographiez le recto de votre CIP, posée à plat, bien éclairée. Les informations doivent être lisibles.',
      style: TextStyle(color: couleurGris(context)),
    ),
    const SizedBox(height: 16),
    PhotoBase64(_photoCip, hauteur: 210, vide: 'Aucune photo pour l\'instant'),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () async {
        final p = await prendrePhoto(context);
        if (p != null) setState(() => _photoCip = p);
      },
      icon: const Icon(Icons.photo_camera_outlined),
      label: Text(_photoCip == null ? 'Photographier ma CIP' : 'Reprendre la photo'),
    ),
  ];

  List<Widget> _visage() => [
    Text(
      'Cette photo reste sur votre profil. Elle permet au propriétaire de vérifier que vous êtes bien la personne de la CIP.',
      style: TextStyle(color: couleurGris(context)),
    ),
    const SizedBox(height: 12),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in [
              'Visage bien en face, regard vers la caméra',
              'Endroit éclairé, pas de contre-jour',
              'Sans lunettes de soleil, casque ni casquette',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: SperoColors.vert),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 16),
    Center(child: PhotoBase64(_photoVisage, hauteur: 180, rond: true, vide: 'Aucun selfie')),
    const SizedBox(height: 16),
    OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () async {
        final p = await prendrePhoto(context, selfie: true);
        if (p != null) setState(() => _photoVisage = p);
      },
      icon: const Icon(Icons.face_retouching_natural),
      label: Text(_photoVisage == null ? 'Prendre mon selfie' : 'Reprendre le selfie'),
    ),
  ];

  List<Widget> _motDePasse() => [
    TextField(
      controller: _mdp,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: 'Mot de passe',
        helperText: 'Au moins 6 caractères',
        prefixIcon: Icon(Icons.lock_outline),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _mdp2,
      obscureText: true,
      decoration: const InputDecoration(labelText: 'Confirmer le mot de passe', prefixIcon: Icon(Icons.lock_outline)),
    ),
    const SizedBox(height: 16),
    Card(
      child: CheckboxListTile(
        value: _consentement,
        onChanged: (v) => setState(() => _consentement = v ?? false),
        activeColor: SperoColors.vert,
        title: const Text(
          'J\'accepte que mon identité, mes photos et ma position pendant le service soient utilisées pour gérer mon contrat.',
        ),
      ),
    ),
  ];
}
