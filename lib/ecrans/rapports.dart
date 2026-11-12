import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fiche_chauffeur.dart';
import 'fiche_tricycle.dart';

class Rapports extends StatefulWidget {
  const Rapports({super.key});

  @override
  State<Rapports> createState() => _RapportsState();
}

class _RapportsState extends State<Rapports> {
  late DateTime _mois;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _mois = DateTime(n.year, n.month);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final now = DateTime.now();
    final debut = _mois;
    final finMois = DateTime(_mois.year, _mois.month + 1);
    final fin = finMois.isAfter(now) ? SperoStore.jour(now).add(const Duration(days: 1)) : finMois;
    final encaisse = store.encaisseEntre(debut, fin);
    final depenses = store.depensesEntre(debut, fin);
    final salaires = store.salairesEntre(debut, fin);
    final resultat = encaisse - depenses - salaires;

    var attendu = 0;
    for (final c in store.chauffeursActifs) {
      final d = c.debutContrat.isAfter(debut) ? c.debutContrat : debut;
      if (!d.isBefore(fin)) continue;
      attendu += store.joursTravailles(c, d, fin.subtract(const Duration(days: 1))) * c.montantJournalier;
    }
    final recouvrement = attendu == 0 ? 1.0 : encaisse / attendu;
    final moisCourant = _mois.year == now.year && _mois.month == now.month;

    final nbJours = fin.difference(debut).inDays;
    final jours = List.generate(nbJours, (i) => debut.add(Duration(days: i)));

    final parCategorie = <CategorieDepense, int>{};
    for (final d in store.depenses.where((d) => !d.date.isBefore(debut) && d.date.isBefore(fin) && d.statut != StatutDepense.refusee)) {
      parCategorie[d.categorie] = (parCategorie[d.categorie] ?? 0) + d.montant;
    }
    final maxCat = parCategorie.values.fold(0, max);

    final chauffeurs = [...store.chauffeursActifs]..sort((a, b) => regularite(store, b).compareTo(regularite(store, a)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports'),
        actions: [
          IconButton(onPressed: () => setState(() => _mois = DateTime(_mois.year, _mois.month - 1)), icon: const Icon(Icons.chevron_left)),
          Center(
            child: Text(DateFormatSimple.moisAnnee(_mois), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            onPressed: moisCourant ? null : () => setState(() => _mois = DateTime(_mois.year, _mois.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: Largeur(
        max: 1000,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Grille(
              enfants: [
                Indicateur(valeur: nombre(encaisse), libelle: 'Encaissé (FCFA)', icone: Icons.south_west_rounded),
                Indicateur(
                  valeur: nombre(depenses),
                  libelle: 'Dépenses (FCFA)',
                  icone: Icons.north_east_rounded,
                  couleur: SperoColors.rouge,
                ),
                Indicateur(
                  valeur: nombre(salaires),
                  libelle: 'Salaires (FCFA)',
                  icone: Icons.groups_rounded,
                  couleur: const Color(0xFFC9A400),
                ),
                Indicateur(
                  valeur: nombre(store.arrieresTotaux),
                  libelle: 'Arriérés aujourd\'hui (FCFA)',
                  icone: Icons.hourglass_bottom_rounded,
                  couleur: store.arrieresTotaux > 0 ? SperoColors.rouge : SperoColors.vert,
                ),
                Indicateur(
                  valeur: nombre(resultat),
                  libelle: 'Résultat après salaires (FCFA)',
                  icone: Icons.account_balance_wallet_rounded,
                  couleur: resultat >= 0 ? SperoColors.vert : SperoColors.rouge,
                ),
                Indicateur(
                  valeur: '${(recouvrement * 100).round()} %',
                  libelle: 'Recouvrement (encaissé / dû)',
                  icone: Icons.pie_chart_rounded,
                  couleur: recouvrement >= 0.95 ? SperoColors.vert : const Color(0xFFC9A400),
                ),
              ],
            ),
            const TitreSection('Encaissements et dépenses par jour'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 16, 8),
                child: Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: _Graphique(jours: jours, store: store),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 16, children: [_legende(SperoColors.vert, 'Encaissé'), _legende(SperoColors.rouge, 'Dépenses')]),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            const TitreSection('Par tricycle'),
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 22,
                  headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: couleurGris(context), fontSize: 12.5),
                  columns: const [
                    DataColumn(label: Text('Tricycle')),
                    DataColumn(label: Text('Recettes'), numeric: true),
                    DataColumn(label: Text('Dépenses'), numeric: true),
                    DataColumn(label: Text('Net'), numeric: true),
                    DataColumn(label: Text('Remboursé'), numeric: true),
                  ],
                  rows: [
                    for (final t in store.tricycles)
                      () {
                        final r =
                            store.recettesTricycle(t.id, depuis: debut) -
                            store.chauffeurs
                                .where((c) => c.tricycleId == t.id)
                                .expand((c) => store.versementsDe(c.id))
                                .where((v) => !v.date.isBefore(fin))
                                .fold<int>(0, (s, v) => s + v.montant);
                        final d = store.depensesEntre(debut, fin, tricycleId: t.id);
                        final total = store.recettesTricycle(t.id) - store.depensesEntre(DateTime(2000), fin, tricycleId: t.id);
                        return DataRow(
                          onSelectChanged: (_) =>
                              Navigator.push(context, MaterialPageRoute(builder: (_) => FicheTricycle(tricycleId: t.id))),
                          cells: [
                            DataCell(Text(t.id, style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(nombre(r))),
                            DataCell(Text(nombre(d))),
                            DataCell(
                              Text(
                                nombre(r - d),
                                style: TextStyle(fontWeight: FontWeight.w700, color: r - d < 0 ? SperoColors.rouge : null),
                              ),
                            ),
                            DataCell(Text('${(t.coutAchat == 0 ? 0 : total / t.coutAchat * 100).clamp(0, 999).round()} %')),
                          ],
                        );
                      }(),
                  ],
                ),
              ),
            ),
            const TitreSection('Chauffeurs'),
            Card(
              child: Column(
                children: [
                  for (final c in chauffeurs)
                    ListTile(
                      leading: Initiales(c.nom, couleur: store.situation(c).niveau.couleur),
                      title: Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        'Dépôt complet le jour même ${(regularite(store, c) * 100).round()} % · arriérés ${fcfa(store.situation(c).arrieres)}',
                      ),
                      trailing: SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: regularite(store, c),
                            minHeight: 8,
                            color: regularite(store, c) >= 0.9
                                ? SperoColors.vert
                                : (regularite(store, c) >= 0.75 ? SperoColors.jaune : SperoColors.rouge),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FicheChauffeur(chauffeurId: c.id))),
                    ),
                ],
              ),
            ),
            const TitreSection('Dépenses par type'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: parCategorie.isEmpty
                    ? const Vide(Icons.receipt_long_outlined, 'Aucune dépense ce mois-ci')
                    : Column(
                        children: [
                          for (final e in (parCategorie.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  SizedBox(width: 96, child: Text(e.key.libelle)),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (_, c) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          height: 14,
                                          width: c.maxWidth * e.value / maxCat,
                                          decoration: BoxDecoration(color: SperoColors.jaune, borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 92,
                                    child: Text(
                                      fcfa(e.value),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
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
      Text(t, style: const TextStyle(fontSize: 12.5)),
    ],
  );
}

class _Graphique extends StatelessWidget {
  final List<DateTime> jours;
  final SperoStore store;
  const _Graphique({required this.jours, required this.store});

  @override
  Widget build(BuildContext context) {
    final enc = [for (final d in jours) store.encaisseLe(d).toDouble()];
    final dep = [for (final d in jours) store.depensesLe(d).toDouble()];
    final maxY = [...enc, ...dep, 1.0].reduce(max);
    final pas = _pasAxe(maxY);
    final gris = couleurGris(context);
    return BarChart(
      BarChartData(
        maxY: (maxY / pas).ceil() * pas,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, _, rod, i) => BarTooltipItem(
              '${DateFormatSimple.date(jours[g.x])}\n${i == 0 ? 'Encaissé' : 'Dépenses'} : ${fcfa(rod.toY.round())}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: pas,
          getDrawingHorizontalLine: (_) => FlLine(color: gris.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: pas,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(v >= 1000 ? '${(v / 1000).round()}k' : '${v.round()}', style: TextStyle(fontSize: 11, color: gris)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                final montrer = i == 0 || i == jours.length - 1 || (i + 1) % 5 == 0;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(montrer ? '${jours[i].day}' : '', style: TextStyle(fontSize: 11, color: gris)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < jours.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 1.5,
              barRods: [
                BarChartRodData(
                  toY: enc[i],
                  color: SperoColors.vert,
                  width: jours.length > 20 ? 4.5 : 8,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: dep[i],
                  color: SperoColors.rouge,
                  width: jours.length > 20 ? 4.5 : 8,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }

  double _pasAxe(double maxY) {
    for (final p in [5000.0, 10000.0, 20000.0, 25000.0, 50000.0, 100000.0]) {
      if (maxY / p <= 5) return p;
    }
    return 200000;
  }
}
