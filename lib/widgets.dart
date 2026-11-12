import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

bool estSombre(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

Color couleurGris(BuildContext context) => estSombre(context) ? const Color(0xFF9AA89E) : SperoColors.gris;

/// Pastille d'état (Payé, Retard 1 j, Critique…).
class Pastille extends StatelessWidget {
  final String texte;
  final Niveau niveau;
  final bool neutre;
  const Pastille(this.texte, this.niveau, {super.key, this.neutre = false});

  factory Pastille.situation(Situation s) => Pastille(s.libelle, s.niveau, neutre: s.libelle == 'À déposer' || s.libelle == 'Repos');

  @override
  Widget build(BuildContext context) {
    final fond = neutre ? Theme.of(context).colorScheme.surfaceContainerHighest : niveau.couleur;
    final texteCouleur = neutre ? Theme.of(context).colorScheme.onSurface : niveau.surCouleur;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(99)),
      child: Text(
        texte,
        style: TextStyle(color: texteCouleur, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class TitreSection extends StatelessWidget {
  final String titre;
  final Widget? action;
  const TitreSection(this.titre, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          ?action,
        ],
      ),
    );
  }
}

class Indicateur extends StatelessWidget {
  final String valeur;
  final String libelle;
  final IconData icone;
  final Color? couleur;
  const Indicateur({super.key, required this.valeur, required this.libelle, required this.icone, this.couleur});

  @override
  Widget build(BuildContext context) {
    final c = couleur ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: c, size: 22),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                valeur,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            const SizedBox(height: 2),
            Text(libelle, style: TextStyle(fontSize: 12.5, color: couleurGris(context))),
          ],
        ),
      ),
    );
  }
}

/// Grande tuile d'action rapide, façon application de services.
class TuileAction extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final Color couleur;
  final Color fond;
  final VoidCallback onTap;
  const TuileAction({
    super.key,
    required this.icone,
    required this.libelle,
    required this.couleur,
    required this.fond,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: estSombre(context) ? couleur.withValues(alpha: 0.18) : fond,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icone, color: couleur == SperoColors.jaune ? const Color(0xFFB08F00) : couleur, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              libelle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class CarteAlerte extends StatelessWidget {
  final Alerte alerte;
  final VoidCallback? onTap;
  const CarteAlerte(this.alerte, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final icone = switch (alerte.niveau) {
      Niveau.critique => Icons.error_rounded,
      Niveau.attention => Icons.warning_amber_rounded,
      Niveau.ok => Icons.info_outline_rounded,
    };
    final c = alerte.niveau == Niveau.attention ? const Color(0xFFC9A400) : alerte.niveau.couleur;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: alerte.niveau.couleur),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    children: [
                      Icon(icone, color: c),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(alerte.titre, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(alerte.detail, style: TextStyle(fontSize: 13, color: couleurGris(context))),
                          ],
                        ),
                      ),
                      if (onTap != null) Icon(Icons.chevron_right, color: couleurGris(context)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Initiales extends StatelessWidget {
  final String nom;
  final Color? couleur;
  final double taille;
  const Initiales(this.nom, {super.key, this.couleur, this.taille = 42});

  @override
  Widget build(BuildContext context) {
    final p = nom.trim().split(RegExp(r'\s+'));
    final ini = p.take(2).map((e) => e.isEmpty ? '' : e[0]).join().toUpperCase();
    final c = couleur ?? SperoColors.vert;
    return CircleAvatar(
      radius: taille / 2,
      backgroundColor: c.withValues(alpha: 0.14),
      child: Text(
        ini,
        style: TextStyle(color: c == SperoColors.jaune ? const Color(0xFF8A7000) : c, fontWeight: FontWeight.w800, fontSize: taille * 0.34),
      ),
    );
  }
}

class Vide extends StatelessWidget {
  final IconData icone;
  final String texte;
  const Vide(this.icone, this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icone, size: 44, color: couleurGris(context)),
          const SizedBox(height: 10),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: TextStyle(color: couleurGris(context)),
          ),
        ],
      ),
    );
  }
}

/// Bande tricolore du drapeau.
class BandeDrapeau extends StatelessWidget {
  final double hauteur;
  const BandeDrapeau({super.key, this.hauteur = 6});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hauteur,
      child: Row(
        children: [
          Expanded(flex: 2, child: Container(color: SperoColors.vert)),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(child: Container(color: SperoColors.jaune)),
                Expanded(child: Container(color: SperoColors.rouge)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo de l'application : un tricycle stylisé dans un carré vert.
class Logo extends StatelessWidget {
  final double taille;
  const Logo({super.key, this.taille = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(color: SperoColors.vert, borderRadius: BorderRadius.circular(taille * 0.28)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.electric_rickshaw_rounded, color: Colors.white, size: taille * 0.56),
          Positioned(
            right: taille * 0.14,
            top: taille * 0.14,
            child: Container(
              width: taille * 0.14,
              height: taille * 0.14,
              decoration: const BoxDecoration(color: SperoColors.jaune, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

/// Limite la largeur du contenu sur grand écran (PC).
class Largeur extends StatelessWidget {
  final Widget child;
  final double max;
  const Largeur({super.key, required this.child, this.max = 900});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }
}

void messageSucces(BuildContext context, String texte) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(texte)),
        ],
      ),
      backgroundColor: SperoColors.vertFonce,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Demande un commentaire ou un motif dans une boîte de dialogue.
Future<String?> demanderTexte(BuildContext context, {required String titre, required String libelle, required String bouton}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: libelle),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            if (ctrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, ctrl.text.trim());
          },
          child: Text(bouton),
        ),
      ],
    ),
  );
}

/// Grille dont la hauteur des lignes suit le contenu (pas de débordement
/// quand le texte passe sur deux lignes ou que la police est agrandie).
class Grille extends StatelessWidget {
  final List<Widget> enfants;
  final int colonnes;
  final int colonnesLarge;
  final double ecart;
  final double seuilLarge;
  const Grille({super.key, required this.enfants, this.colonnes = 2, this.colonnesLarge = 4, this.ecart = 10, this.seuilLarge = 560});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final n = c.maxWidth > seuilLarge ? colonnesLarge : colonnes;
        final lignes = <Widget>[];
        for (var i = 0; i < enfants.length; i += n) {
          final ligne = enfants.sublist(i, (i + n).clamp(0, enfants.length));
          lignes.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < n; j++) ...[
                    if (j > 0) SizedBox(width: ecart),
                    Expanded(child: j < ligne.length ? ligne[j] : const SizedBox()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < lignes.length; i++) ...[if (i > 0) SizedBox(height: ecart), lignes[i]],
          ],
        );
      },
    );
  }
}

/// Affiche une photo enregistrée en base64 (CIP, visage).
class PhotoBase64 extends StatelessWidget {
  final String? donnees;
  final double hauteur;
  final double? largeur;
  final String vide;
  final bool rond;
  const PhotoBase64(this.donnees, {super.key, this.hauteur = 160, this.largeur, this.vide = 'Pas de photo', this.rond = false});

  @override
  Widget build(BuildContext context) {
    final fond = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget contenu;
    if (donnees == null || donnees!.isEmpty) {
      contenu = Container(
        color: fond,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: hauteur < 90 || vide.isEmpty
            ? Icon(rond ? Icons.person_rounded : Icons.image_not_supported_outlined, color: couleurGris(context))
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: couleurGris(context)),
                    const SizedBox(height: 4),
                    Text(
                      vide,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: couleurGris(context)),
                    ),
                  ],
                ),
              ),
      );
    } else if (donnees!.startsWith('stockage:')) {
      // Photo rangée sur le serveur : lien temporaire sécurisé.
      final distant = context.read<SperoStore>().distant;
      contenu = distant == null
          ? Container(color: fond)
          : FutureBuilder<String>(
              future: distant.urlPhoto(donnees!),
              builder: (context, snap) => snap.hasData
                  ? Image.network(snap.data!, fit: BoxFit.cover, gaplessPlayback: true)
                  : Container(color: fond, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)),
            );
    } else {
      contenu = Image.memory(base64Decode(donnees!), fit: BoxFit.cover, gaplessPlayback: true);
    }
    return SizedBox(
      height: hauteur,
      width: largeur ?? (rond ? hauteur : null),
      child: rond ? ClipOval(child: contenu) : ClipRRect(borderRadius: BorderRadius.circular(14), child: contenu),
    );
  }
}

/// Prend une photo (caméra si disponible, sinon choix d'un fichier) et la renvoie en base64.
Future<String?> prendrePhoto(BuildContext context, {bool selfie = false}) async {
  final picker = ImagePicker();
  final camera = picker.supportsImageSource(ImageSource.camera);
  ImageSource? source = ImageSource.gallery;
  if (camera) {
    source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(selfie ? 'Prendre un selfie' : 'Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (!selfie)
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir dans la galerie'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;
  }
  try {
    final f = await picker.pickImage(
      source: source,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
      maxWidth: 900,
      imageQuality: 70,
    );
    if (f == null) return null;
    return base64Encode(await f.readAsBytes());
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir la caméra. Autorisez l\'accès dans les réglages.')));
    }
    return null;
  }
}

/// Bandeau rouge quand la synchronisation avec le serveur a échoué.
class BandeauErreur extends StatelessWidget {
  const BandeauErreur({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    if (store.erreur == null) return const SizedBox.shrink();
    return Material(
      color: SperoColors.rouge,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  store.erreur!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              if (store.surServeur)
                TextButton(
                  onPressed: store.chargerDistant,
                  child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                ),
              IconButton(
                onPressed: store.effacerErreur,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
