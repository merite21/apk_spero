import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'accueil.dart';
import 'carte.dart';
import 'flotte.dart';
import 'rapports.dart';
import 'versements.dart';

/// Navigation principale : barre du bas sur téléphone, rail latéral sur PC.
class Coque extends StatefulWidget {
  const Coque({super.key});

  @override
  State<Coque> createState() => _CoqueState();
}

class _CoqueState extends State<Coque> {
  int _index = 0;

  void allerA(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SperoStore>();
    final admin = store.role == Role.admin;
    final nbAlertes = store.alertesOuvertes().where((a) => a.niveau == Niveau.critique).length;

    final pages = <Widget>[Accueil(allerA: allerA), const CarteDirect(), const Versements(), const Flotte(), if (admin) const Rapports()];
    final destinations = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, 'Accueil'),
      (Icons.map_outlined, Icons.map_rounded, 'Carte'),
      (Icons.payments_outlined, Icons.payments_rounded, 'Dépôts'),
      (Icons.electric_rickshaw_outlined, Icons.electric_rickshaw_rounded, 'Flotte'),
      if (admin) (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Rapports'),
    ];
    if (_index >= pages.length) _index = 0;

    final large = MediaQuery.sizeOf(context).width >= 900;

    Widget icone(IconData i, int idx) {
      if (idx != 0 || nbAlertes == 0) return Icon(i);
      return Badge(label: Text('$nbAlertes'), backgroundColor: SperoColors.rouge, child: Icon(i));
    }

    final corps = IndexedStack(index: _index, children: pages);

    if (large) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: allerA,
              labelType: NavigationRailLabelType.all,
              indicatorColor: estSombreCtx(context) ? const Color(0xFF1F3A2B) : SperoColors.vertClair,
              leading: const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: _LogoRail()),
              destinations: [
                for (var i = 0; i < destinations.length; i++)
                  NavigationRailDestination(
                    icon: icone(destinations[i].$1, i),
                    selectedIcon: icone(destinations[i].$2, i),
                    label: Text(destinations[i].$3),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: corps),
          ],
        ),
      );
    }

    return Scaffold(
      body: corps,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: allerA,
        destinations: [
          for (var i = 0; i < destinations.length; i++)
            NavigationDestination(
              icon: icone(destinations[i].$1, i),
              selectedIcon: icone(destinations[i].$2, i),
              label: destinations[i].$3,
            ),
        ],
      ),
    );
  }
}

bool estSombreCtx(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

class _LogoRail extends StatelessWidget {
  const _LogoRail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: SperoColors.vert, borderRadius: BorderRadius.circular(13)),
      child: const Icon(Icons.electric_rickshaw_rounded, color: Colors.white),
    );
  }
}
