import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Adresse et clé publique du projet Supabase, passées au lancement :
///   flutter run --dart-define-from-file=config.json
/// Sans elles, l'application tourne en mode démonstration (données locales).
class Config {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const cle = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get serveur => url.isNotEmpty && cle.isNotEmpty;
}

/// Une écriture à envoyer au serveur.
sealed class Operation {
  const Operation();
}

class Ajout extends Operation {
  final String table;
  final Map<String, dynamic> ligne;
  const Ajout(this.table, this.ligne);
}

class MiseAJour extends Operation {
  final String table;
  final String id;
  final Map<String, dynamic> ligne;
  final String colonne;
  const MiseAJour(this.table, this.id, this.ligne, {this.colonne = 'id'});
}

class Suppression extends Operation {
  final String table;
  final String colonne;
  final String valeur;
  const Suppression(this.table, this.colonne, this.valeur);
}

/// Accès au serveur Supabase : comptes, tables, photos, temps réel.
class Distant {
  final SupabaseClient client;
  Distant(this.client);

  static const _datesCles = {'date', 'dateAchat', 'dateInscription', 'dateValidation', 'contratAccepteLe', 'debutContrat'};
  static const _horsBase = {'motDePasse'};

  static String _versSnake(String k) => k.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
  static String _versCamel(String k) => k.replaceAllMapped(RegExp(r'_([a-z])'), (m) => m[1]!.toUpperCase());

  /// Modèle de l'application → ligne de la base (noms en snake_case, dates en UTC).
  static Map<String, dynamic> versBase(Map<String, dynamic> j) => {
    for (final e in j.entries)
      if (!_horsBase.contains(e.key))
        _versSnake(e.key): (_datesCles.contains(e.key) && e.value is String)
            ? DateTime.parse(e.value as String).toUtc().toIso8601String()
            : e.value,
  };

  /// Ligne de la base → modèle de l'application (noms en camelCase, dates locales).
  static Map<String, dynamic> depuisBase(Map<String, dynamic> j) {
    final r = <String, dynamic>{};
    for (final e in j.entries) {
      final k = _versCamel(e.key);
      r[k] = (_datesCles.contains(k) && e.value is String) ? DateTime.parse(e.value as String).toLocal().toIso8601String() : e.value;
    }
    return r;
  }

  // ---------- Comptes ----------

  Session? get session => client.auth.currentSession;
  String? get uid => client.auth.currentUser?.id;

  /// Adresse de connexion technique d'un compte créé avec un numéro de téléphone.
  static String emailTechnique(String telephone) => '${telephone.replaceAll(RegExp(r'\D'), '')}@tel.spero.app';

  Future<String?> emailDeConnexion(String identifiant) async {
    final r = await client.rpc('email_connexion', params: {'p_identifiant': identifiant.trim()});
    return r as String?;
  }

  Future<void> seConnecter(String email, String motDePasse) => client.auth.signInWithPassword(email: email, password: motDePasse);

  Future<void> seDeconnecter() => client.auth.signOut();

  Future<String?> monRole() async {
    final r = await client.from('profils').select('role').eq('id', uid!).maybeSingle();
    return r?['role'] as String?;
  }

  Future<void> creerCompte({required String email, required String motDePasse, required String nom, required String telephone}) async {
    final r = await client.auth.signUp(email: email, password: motDePasse, data: {'nom': nom, 'telephone': telephone});
    if (r.session == null) {
      throw Exception(
        'Le compte a été créé mais la confirmation par e-mail est activée sur le serveur. Désactivez-la dans Supabase (Authentication > Sign In / Providers > Email).',
      );
    }
  }

  // ---------- Photos ----------

  Future<String> envoyerPhoto(String nom, Uint8List octets) async {
    final chemin = '$uid/$nom';
    await client.storage
        .from('dossiers')
        .uploadBinary(chemin, octets, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    return 'stockage:$chemin';
  }

  final _urls = <String, String>{};

  Future<String> urlPhoto(String reference) async {
    final chemin = reference.replaceFirst('stockage:', '');
    return _urls[chemin] ??= await client.storage.from('dossiers').createSignedUrl(chemin, 3600);
  }

  // ---------- Données ----------

  Future<List<Map<String, dynamic>>> lire(String table, {String? ordre}) async {
    final q = client.from(table).select();
    final List<dynamic> lignes = ordre == null ? await q : await q.order(ordre, ascending: false).limit(500);
    return [for (final l in lignes) depuisBase(Map<String, dynamic>.from(l as Map))];
  }

  Future<void> executer(Operation op) async {
    switch (op) {
      case Ajout(:final table, :final ligne):
        await client.from(table).insert(versBase(ligne));
      case MiseAJour(:final table, :final id, :final ligne, :final colonne):
        final l = versBase(ligne)..remove('id');
        await client.from(table).update(l).eq(colonne, id);
      case Suppression(:final table, :final colonne, :final valeur):
        await client.from(table).delete().eq(colonne, valeur);
    }
  }

  Future<void> rpc(String fonction, Map<String, dynamic> params) => client.rpc(fonction, params: params);

  RealtimeChannel? _canal;

  /// Prévient à chaque changement dans la base (les droits RLS s'appliquent).
  void ecouter(void Function() surChangement) {
    _canal?.unsubscribe();
    _canal = client
        .channel('spero')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', callback: (_) => surChangement())
        .subscribe();
  }

  void arreterEcoute() {
    _canal?.unsubscribe();
    _canal = null;
  }
}
