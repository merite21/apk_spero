import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fiche_chauffeur.dart';
import 'formulaires.dart';

class FicheTricycle extends StatefulWidget {
  final String tricycleId;
  const FicheTricycle({super.key, required this.tricycleId});

  @override
  State<FicheTricycle> createState() => _FicheTricycleState();
}

class _FicheTricycleState extends State<FicheTricycle> {
  bool _hier = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final t = store.tricycle(widget.tricycleId);
    if (t == null) return const Scaffold(body: Vide(Icons.search_off, 'Tricycle introuvable'));
    final c = store.chauffeurDe(t.id);
    final e = store.traceurs[t.id]!;
    final admin = store.role == Role.admin;
    final aujourdhui = SperoStore.jour(DateTime.now());
    final debut = _hier ? aujourdhui.subtract(const Duration(days: 1)) : aujourdhui;
    final fin = _hier ? aujourdhui : DateTime.now().add(const Duration(minutes: 1));
    final pts = (store.historique[t.id] ?? []).where((p) => !p.date.isBefore(debut) && p.date.isBefore(fin)).toList();
    final horsHoraires = c == null ? <PointGps>[] : pts.where((p) => store.estHorsHoraires(c, p.date)).toList();
    final recettes = store.recettesTricycle(t.id);
    final depenses = store.depensesEntre(DateTime(2000), DateTime.now().add(const Duration(days: 1)), tricycleId: t.id);
    final net = recettes - depenses;
    final roi = t.coutAchat == 0 ? 0.0 : net / t.coutAchat;
    final bloque = store.moteursBloques.contains(t.id);
    final roule = e.moteur && e.vitesse > 0;
    final mesDepenses = store.depenses.where((d) => d.tricycleId == t.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    final mesInspections = store.inspections.where((i) => i.tricycleId == t.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    final mesIncidents = store.incidents.where((i) => i.tricycleId == t.id).toList()..sort((a, b) => b.date.compareTo(a.date));

    void ouvrir(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: AppBar(title: Text('${t.id} · ${t.immatriculation}')),
      body: Largeur(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SizedBox(
                    height: 260,
                    child: FlutterMap(
                      key: ValueKey('${t.id}-$_hier'),
                      options: MapOptions(initialCenter: pts.isNotEmpty ? pts.last.position : e.position, initialZoom: 12.5),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.spero.spero'),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: SperoStore.centreZone,
                              radius: store.parametres.rayonZoneKm * 1000,
                              useRadiusInMeter: true,
                              color: Colors.transparent,
                              borderColor: SperoColors.vert,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(points: pts.map((p) => p.position).toList(), color: SperoColors.vert, strokeWidth: 4),
                            if (horsHoraires.length > 1)
                              Polyline(points: horsHoraires.map((p) => p.position).toList(), color: SperoColors.rouge, strokeWidth: 4),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            if (pts.isNotEmpty) Marker(point: pts.first.position, width: 18, height: 18, child: _point(SperoColors.jaune)),
                            Marker(
                              point: _hier && pts.isNotEmpty ? pts.last.position : e.position,
                              width: 30,
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: store.traceurCoupe(t.id) ? SperoColors.rouge : SperoColors.vert,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: const Icon(Icons.electric_rickshaw_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text('Aujourd\'hui')),
                              ButtonSegment(value: true, label: Text('Hier')),
                            ],
                            selected: {_hier},
                            onSelectionChanged: (v) => setState(() => _hier = v.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(
                      children: [
                        _mini(context, '${store.kmEntre(t.id, debut, fin).round()} km', 'parcourus'),
                        _mini(
                          context,
                          pts.isEmpty ? '-' : '${DateFormatSimple.heure(pts.first.date)} → ${DateFormatSimple.heure(pts.last.date)}',
                          'activité',
                        ),
                        _mini(context, '${store.moyenneKm[t.id]?.round() ?? 0} km', 'moyenne / jour'),
                      ],
                    ),
                  ),
                  if (horsHoraires.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: SperoColors.rougeClair,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'En rouge : ${horsHoraires.length * 5} min de circulation hors horaires (${DateFormatSimple.heure(horsHoraires.first.date)} → ${DateFormatSimple.heure(horsHoraires.last.date)})',
                        style: const TextStyle(color: Color(0xFF8A0A1B), fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Initiales(c?.nom ?? '?'),
                    title: Text(c?.nom ?? 'Aucun chauffeur', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      c == null ? 'Tricycle disponible à la location' : 'Contrat depuis le ${DateFormatSimple.date(c.debutContrat)}',
                    ),
                    trailing: c == null ? null : Pastille.situation(store.situation(c)),
                    onTap: c == null ? null : () => ouvrir(FicheChauffeur(chauffeurId: c.id)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      store.traceurCoupe(t.id) ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
                      color: store.traceurCoupe(t.id) ? SperoColors.rouge : SperoColors.vert,
                    ),
                    title: Text(
                      store.traceurCoupe(t.id) ? 'Traceur sans signal' : (roule ? 'En route · ${e.vitesse.round()} km/h' : 'À l\'arrêt'),
                    ),
                    subtitle: Text('Dernier signal ${DateFormatSimple.relative(e.dernierSignal)} · IMEI ${t.imeiTraceur}'),
                  ),
                  if (admin) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        bloque ? Icons.lock_rounded : Icons.power_settings_new_rounded,
                        color: bloque ? SperoColors.rouge : null,
                      ),
                      title: Text(bloque ? 'Moteur coupé à distance' : 'Coupe-moteur à distance'),
                      subtitle: Text(
                        bloque
                            ? 'Le tricycle ne peut pas démarrer'
                            : (roule ? 'Possible uniquement à l\'arrêt, par sécurité' : 'Empêche le démarrage du tricycle'),
                      ),
                      trailing: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          backgroundColor: bloque ? SperoColors.vert : SperoColors.rouge,
                        ),
                        onPressed: !bloque && roule ? null : () => _confirmerMoteur(context, store, t.id, bloque),
                        child: Text(bloque ? 'Réactiver' : 'Couper'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (admin) ...[
              const TitreSection('Rentabilité'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ligne('Coût d\'achat', fcfa(t.coutAchat)),
                      _ligne('Recettes encaissées', fcfa(recettes)),
                      _ligne('Dépenses', fcfa(-depenses), couleur: SperoColors.rouge),
                      const Divider(),
                      _ligne('Résultat net', fcfa(net), gras: true),
                      const SizedBox(height: 12),
                      Text(
                        'Investissement remboursé à ${(roi * 100).clamp(0, 999).toStringAsFixed(0)} %',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: roi.clamp(0.0, 1.0),
                          minHeight: 10,
                          color: SperoColors.vert,
                          backgroundColor: SperoColors.vertClair,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const TitreSection('Actions'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TuileAction(
                        icone: Icons.receipt_long_rounded,
                        libelle: 'Dépense',
                        couleur: SperoColors.jaune,
                        fond: SperoColors.jauneClair,
                        onTap: () => ouvrir(NouvelleDepense(tricycleId: t.id)),
                      ),
                    ),
                    Expanded(
                      child: TuileAction(
                        icone: Icons.fact_check_rounded,
                        libelle: 'Inspection',
                        couleur: SperoColors.vert,
                        fond: SperoColors.vertClair,
                        onTap: () => ouvrir(NouvelleInspection(tricycleId: t.id)),
                      ),
                    ),
                    Expanded(
                      child: TuileAction(
                        icone: Icons.car_crash_rounded,
                        libelle: 'Incident',
                        couleur: SperoColors.rouge,
                        fond: SperoColors.rougeClair,
                        onTap: () => ouvrir(NouvelIncident(tricycleId: t.id)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const TitreSection('Entretien'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ligne('Kilométrage', '${t.kilometrage.round()} km'),
                    _ligne('Depuis la dernière vidange', '${(t.kilometrage - t.kmDerniereVidange).round()} km'),
                    _ligne('Prochaine vidange', '${(t.kmDerniereVidange + store.parametres.kmVidange)} km'),
                  ],
                ),
              ),
            ),
            if (mesIncidents.isNotEmpty) ...[
              const TitreSection('Incidents'),
              Card(
                child: Column(
                  children: [
                    for (final i in mesIncidents)
                      ListTile(
                        leading: Icon(
                          i.resolu ? Icons.check_circle : Icons.report_rounded,
                          color: i.resolu ? SperoColors.vert : SperoColors.rouge,
                        ),
                        title: Text(i.type, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${DateFormatSimple.relative(i.date)} · ${i.description}'),
                        trailing: i.resolu ? null : TextButton(onPressed: () => store.resoudreIncident(i), child: const Text('Résolu')),
                      ),
                  ],
                ),
              ),
            ],
            const TitreSection('Dépenses'),
            Card(
              child: mesDepenses.isEmpty
                  ? const Vide(Icons.receipt_long_outlined, 'Aucune dépense')
                  : Column(
                      children: [
                        for (final d in mesDepenses.take(15))
                          ListTile(
                            dense: true,
                            title: Text('${d.categorie.libelle} · ${d.description}'),
                            subtitle: Text('${DateFormatSimple.relative(d.date)} · ${d.saisiPar}${d.avecRecu ? '' : ' · sans reçu'}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(fcfa(d.montant), style: const TextStyle(fontWeight: FontWeight.w800)),
                                if (d.statut != StatutDepense.validee)
                                  Text(
                                    d.statut == StatutDepense.enAttente ? 'À valider' : 'Refusée',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: d.statut == StatutDepense.enAttente ? const Color(0xFF9A7D00) : SperoColors.rouge,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const TitreSection('Inspections'),
            Card(
              child: mesInspections.isEmpty
                  ? const Vide(Icons.fact_check_outlined, 'Aucune inspection')
                  : Column(
                      children: [
                        for (final i in mesInspections)
                          ListTile(
                            leading: Icon(
                              i.conforme ? Icons.verified_rounded : Icons.warning_amber_rounded,
                              color: i.conforme ? SperoColors.vert : const Color(0xFFC9A400),
                            ),
                            title: Text(
                              i.conforme
                                  ? 'Conforme'
                                  : 'Non conforme : ${i.points.entries.where((e) => !e.value).map((e) => e.key).join(', ')}',
                            ),
                            subtitle: Text('${DateFormatSimple.relative(i.date)} · moteur ${i.numeroMoteur} · ${i.commentaire}'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmerMoteur(BuildContext context, SperoStore store, String id, bool bloque) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(bloque ? 'Réactiver le moteur ?' : 'Couper le moteur ?'),
        content: Text(
          bloque
              ? 'Le chauffeur pourra de nouveau démarrer $id.'
              : 'Le tricycle $id ne pourra plus démarrer jusqu\'à sa réactivation. Le chauffeur sera prévenu par SMS.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: bloque ? SperoColors.vert : SperoColors.rouge),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(bloque ? 'Réactiver' : 'Couper le moteur'),
          ),
        ],
      ),
    );
    if (ok == true) await store.basculerMoteur(id);
  }

  Widget _point(Color c) => Container(
    decoration: BoxDecoration(
      color: c,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
  );

  Widget _mini(BuildContext context, String v, String l) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        Text(l, style: TextStyle(fontSize: 12, color: couleurGris(context))),
      ],
    ),
  );

  Widget _ligne(String a, String b, {Color? couleur, bool gras = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(a, style: TextStyle(fontWeight: gras ? FontWeight.w800 : FontWeight.w500)),
        ),
        Text(
          b,
          style: TextStyle(fontWeight: FontWeight.w800, color: couleur, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    ),
  );
}
