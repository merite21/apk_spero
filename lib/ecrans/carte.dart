import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fiche_tricycle.dart';

/// Niveau d'un tricycle sur la carte, selon les alertes ouvertes qui le concernent.
Niveau? niveauTricycle(SperoStore store, String id, List<Alerte> alertes) {
  final a = alertes.where((x) => x.tricycleId == id && x.niveau != Niveau.ok);
  if (a.any((x) => x.niveau == Niveau.critique)) return Niveau.critique;
  if (a.isNotEmpty) return Niveau.attention;
  return null;
}

class CarteDirect extends StatefulWidget {
  const CarteDirect({super.key});

  @override
  State<CarteDirect> createState() => _CarteDirectState();
}

class _CarteDirectState extends State<CarteDirect> {
  final _ctrl = MapController();
  String? _selection;
  String _filtre = 'Tous';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final alertes = store.alertesOuvertes();
    final ids = store.tricycles.map((t) => t.id).where((id) {
      final e = store.traceurs[id]!;
      return switch (_filtre) {
        'En route' => e.moteur && e.vitesse > 0,
        'À l\'arrêt' => !(e.moteur && e.vitesse > 0),
        'Alertes' => niveauTricycle(store, id, alertes) != null,
        _ => true,
      };
    }).toList();
    final sel = _selection == null ? null : store.tricycle(_selection);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _ctrl,
            options: MapOptions(initialCenter: SperoStore.centreZone, initialZoom: 12, onTap: (_, _) => setState(() => _selection = null)),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.spero.spero'),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: SperoStore.centreZone,
                    radius: store.parametres.rayonZoneKm * 1000,
                    useRadiusInMeter: true,
                    color: SperoColors.vert.withValues(alpha: 0.06),
                    borderColor: SperoColors.vert,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              if (sel != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: store.historique[sel.id]!
                          .where((p) => !p.date.isBefore(SperoStore.jour(DateTime.now())))
                          .map((p) => p.position)
                          .toList(),
                      color: SperoColors.vert.withValues(alpha: 0.8),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final id in ids)
                    Marker(
                      point: store.traceurs[id]!.position,
                      width: 74,
                      height: 58,
                      child: _Repere(
                        id: id,
                        etat: store.traceurs[id]!,
                        niveau: store.traceurCoupe(id) ? Niveau.critique : niveauTricycle(store, id, alertes),
                        choisi: id == _selection,
                        bloque: store.moteursBloques.contains(id),
                        onTap: () => setState(() => _selection = id),
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.sensors_rounded, color: SperoColors.vert),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Carte en direct', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                Text(
                                  'Positions simulées · zone autorisée en vert',
                                  style: TextStyle(fontSize: 12, color: couleurGris(context)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Recentrer',
                            onPressed: () => _ctrl.move(SperoStore.centreZone, 12),
                            icon: const Icon(Icons.my_location_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in ['Tous', 'En route', 'À l\'arrêt', 'Alertes'])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: _filtre == f,
                              onSelected: (_) => setState(() => _filtre = f),
                              selectedColor: SperoColors.vert,
                              labelStyle: TextStyle(color: _filtre == f ? Colors.white : null, fontWeight: FontWeight.w600),
                              showCheckmark: false,
                              backgroundColor: Theme.of(context).colorScheme.surface,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (sel != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Largeur(
                max: 520,
                child: _Panneau(tricycle: sel, alertes: alertes),
              ),
            ),
        ],
      ),
    );
  }
}

class _Repere extends StatelessWidget {
  final String id;
  final EtatTraceur etat;
  final Niveau? niveau;
  final bool choisi;
  final bool bloque;
  final VoidCallback onTap;
  const _Repere({
    required this.id,
    required this.etat,
    required this.niveau,
    required this.choisi,
    required this.bloque,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final roule = etat.moteur && etat.vitesse > 0;
    final c = niveau?.couleur ?? (roule ? SperoColors.vert : SperoColors.gris);
    final surC = niveau == Niveau.attention ? SperoColors.surJaune : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white, width: choisi ? 3 : 2),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26, offset: Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(bloque ? Icons.lock_rounded : Icons.electric_rickshaw_rounded, size: 15, color: surC),
                const SizedBox(width: 3),
                Text(
                  id.replaceAll('TC-', ''),
                  style: TextStyle(color: surC, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: pi / 4,
            child: Container(width: 9, height: 9, color: c, margin: const EdgeInsets.only(top: 0)),
          ),
        ],
      ),
    );
  }
}

class _Panneau extends StatelessWidget {
  final Tricycle tricycle;
  final List<Alerte> alertes;
  const _Panneau({required this.tricycle, required this.alertes});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final e = store.traceurs[tricycle.id]!;
    final c = store.chauffeurDe(tricycle.id);
    final mes = alertes.where((a) => a.tricycleId == tricycle.id && a.niveau != Niveau.ok).toList();
    final coupe = store.traceurCoupe(tricycle.id);
    return Card(
      elevation: 6,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Initiales(c?.nom ?? '?', couleur: SperoColors.vert),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tricycle.id} · ${c?.nom ?? 'Sans chauffeur'}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        coupe
                            ? 'Signal perdu depuis ${DateFormatSimple.heure(e.dernierSignal)}'
                            : '${e.moteur && e.vitesse > 0 ? '${e.vitesse.round()} km/h · moteur allumé' : 'À l\'arrêt'} · ${store.kmAujourdhui(tricycle.id).round()} km aujourd\'hui',
                        style: TextStyle(color: couleurGris(context), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (mes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final a in mes) Pastille(a.titre.split(' · ').first, a.niveau)]),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FicheTricycle(tricycleId: tricycle.id))),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Voir la fiche et les trajets'),
            ),
          ],
        ),
      ),
    );
  }
}
