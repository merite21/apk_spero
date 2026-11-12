import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'inscription.dart';

/// Codes de démonstration. Ils seront remplacés par de vrais comptes
/// (numéro de téléphone + code reçu par SMS) quand le serveur sera branché.
const _codes = {Role.admin: '1234', Role.gestionnaire: '0000'};

class Connexion extends StatefulWidget {
  const Connexion({super.key});

  @override
  State<Connexion> createState() => _ConnexionState();
}

class _ConnexionState extends State<Connexion> {
  Role? _role;
  String _code = '';
  bool _erreur = false;
  final _identifiant = TextEditingController();
  final _mdp = TextEditingController();
  String? _erreurChauffeur;
  bool _voirMdp = false;

  void _touche(String t) {
    setState(() {
      _erreur = false;
      if (t == '<') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
      } else if (_code.length < 4) {
        _code += t;
      }
    });
    if (_code.length == 4) {
      if (_code == _codes[_role]) {
        context.read<SperoStore>().connecter(_role!);
      } else {
        setState(() {
          _erreur = true;
          _code = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serveur = context.watch<SperoStore>().surServeur;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: switch (_role) {
                _ when serveur => _connexionChauffeur(serveur: true),
                null => _choixProfil(),
                Role.chauffeur => _connexionChauffeur(),
                _ => _clavier(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _choixProfil() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Logo(),
        const SizedBox(height: 24),
        const Text('Spero', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text('Gestion de vos tricycles en location', style: TextStyle(fontSize: 16, color: couleurGris(context))),
        const SizedBox(height: 14),
        const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: SizedBox(width: 90, child: BandeDrapeau()),
        ),
        const SizedBox(height: 36),
        const Text('Qui se connecte ?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _profil(Role.admin, Icons.admin_panel_settings_rounded, 'Propriétaire', 'Voir tout, valider, décider', SperoColors.vert),
        const SizedBox(height: 12),
        _profil(
          Role.gestionnaire,
          Icons.badge_rounded,
          'Gestionnaire',
          'Dépôts en espèces, dépenses, inspections',
          const Color(0xFFB08F00),
        ),
        const SizedBox(height: 12),
        _profil(
          Role.chauffeur,
          Icons.electric_rickshaw_rounded,
          'Chauffeur',
          'Mon dépôt du jour, mon contrat, mon salaire',
          SperoColors.rouge,
        ),
        const SizedBox(height: 24),
        Text(
          'Démonstration : propriétaire 1234 · gestionnaire 0000 · chauffeur 01 97 00 00 01, mot de passe 1234',
          style: TextStyle(fontSize: 12.5, color: couleurGris(context)),
        ),
      ],
    );
  }

  Widget _profil(Role r, IconData icone, String titre, String sous, Color c) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() {
          _role = r;
          _code = '';
        }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(16)),
                child: Icon(icone, color: c, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(sous, style: TextStyle(color: couleurGris(context))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }

  bool _attente = false;

  Widget _connexionChauffeur({bool serveur = false}) {
    Future<void> valider() async {
      setState(() {
        _attente = true;
        _erreurChauffeur = null;
      });
      final err = await context.read<SperoStore>().seConnecter(_identifiant.text, _mdp.text);
      if (mounted) {
        setState(() {
          _attente = false;
          _erreurChauffeur = err;
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!serveur)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(onPressed: () => setState(() => _role = null), icon: const Icon(Icons.arrow_back)),
          ),
        Center(child: Logo(taille: serveur ? 72 : 56)),
        const SizedBox(height: 18),
        Text(
          serveur ? 'Spero' : 'Espace chauffeur',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Connectez-vous avec votre téléphone ou votre e-mail',
          textAlign: TextAlign.center,
          style: TextStyle(color: couleurGris(context)),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _identifiant,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Téléphone ou e-mail', prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _mdp,
          obscureText: !_voirMdp,
          onSubmitted: (_) => valider(),
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _voirMdp = !_voirMdp),
              icon: Icon(_voirMdp ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
          ),
        ),
        if (_erreurChauffeur != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _erreurChauffeur!,
              style: const TextStyle(color: SperoColors.rouge, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _attente ? null : valider,
          child: _attente
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Se connecter'),
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouveau chauffeur ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  'Créez votre compte : identité, photo de votre CIP et photo de votre visage. Le propriétaire validera votre inscription.',
                  style: TextStyle(color: couleurGris(context)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Inscription())),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Créer mon compte chauffeur'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _clavier() {
    final touches = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(onPressed: () => setState(() => _role = null), icon: const Icon(Icons.arrow_back)),
        ),
        const Logo(taille: 56),
        const SizedBox(height: 18),
        Text(_role == Role.admin ? 'Propriétaire' : 'Gestionnaire', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Entrez votre code à 4 chiffres', style: TextStyle(color: couleurGris(context))),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final rempli = i < _code.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _erreur ? SperoColors.rouge : (rempli ? SperoColors.vert : Colors.transparent),
                border: Border.all(color: _erreur ? SperoColors.rouge : SperoColors.vert, width: 2),
              ),
            );
          }),
        ),
        SizedBox(
          height: 30,
          child: _erreur
              ? const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Code incorrect, réessayez',
                    style: TextStyle(color: SperoColors.rouge, fontWeight: FontWeight.w600),
                  ),
                )
              : null,
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            for (final t in touches)
              t.isEmpty
                  ? const SizedBox()
                  : Material(
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: estSombre(context) ? const Color(0xFF2A352D) : SperoColors.ligne),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _touche(t),
                        child: Center(
                          child: t == '<'
                              ? const Icon(Icons.backspace_outlined)
                              : Text(t, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
          ],
        ),
      ],
    );
  }
}
