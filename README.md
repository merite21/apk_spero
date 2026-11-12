# Spero

Application Flutter de gestion de tricycles en location (versement journalier fixe).
Téléphone (Android, iOS) et ordinateur (Web, Windows, macOS).

## Lancer l'application

```bash
flutter pub get
flutter run -d chrome      # navigateur
flutter run -d macos       # Mac
flutter run                # téléphone branché
```

Comptes de démonstration :
- **Propriétaire** : code 1234
- **Gestionnaire** : code 0000
- **Chauffeur** : téléphone `01 97 00 00 01` à `01 97 00 00 09`, mot de passe `1234`
- Un chauffeur (Gildas Hounkpè) a une inscription en attente de validation.

## Fonctionnement

- Le chauffeur crée son compte lui-même (identité, photo de la CIP, IFU facultatif, selfie, mot de passe).
- Le propriétaire reçoit une alerte, vérifie le dossier, attribue un tricycle et fixe le début du contrat, le dépôt journalier et le salaire.
- Le chauffeur lit et accepte son contrat (case à cocher et signature par son nom).
- Chaque jour, le chauffeur fait son dépôt depuis l'application (MTN MoMo ou Moov Money, simulé pour l'instant). L'application calcule ce qui manque pour le jour. Un dépôt en trop rembourse d'abord les jours incomplets les plus anciens.
- Le propriétaire paie les salaires depuis la fiche du chauffeur.

## Mettre en ligne avec Supabase (données partagées entre tous les téléphones)

Sans configuration, l'application tourne en **démonstration** : les données restent sur l'appareil.
Pour que le propriétaire, le gestionnaire et les chauffeurs partagent les mêmes données :

1. **Créer le projet** : compte gratuit sur https://supabase.com, puis « New project ». Notez le mot de passe de la base.
2. **Créer la base** : menu *SQL Editor* → *New query* → collez tout le fichier `supabase/schema.sql` → *Run*.
   Le script peut être relancé sans risque.
3. **Désactiver la confirmation par e-mail** : *Authentication* → *Sign In / Providers* → *Email* → décochez *Confirm email*.
   (Les chauffeurs s'inscrivent avec leur numéro de téléphone, sans boîte e-mail.)
4. **Créer le compte du propriétaire** : *Authentication* → *Users* → *Add user* → e-mail + mot de passe, cochez *Auto Confirm User*.
   Puis dans *SQL Editor* :
   ```sql
   select definir_role('votre-email@exemple.com', 'proprietaire', 'Votre nom');
   ```
   Même chose pour le gestionnaire, avec `'gestionnaire'`.
5. **Relier l'application** : *Project Settings* → *API* : copiez l'URL du projet et la clé publique (*anon* / *publishable*).
   Copiez `config.example.json` en `config.json` et remplissez les deux valeurs. Ce fichier n'est pas à partager.
6. **Lancer** :
   ```bash
   flutter run -d chrome --dart-define-from-file=config.json
   flutter build web --dart-define-from-file=config.json      # version web
   flutter build apk --dart-define-from-file=config.json      # Android
   ```

Ensuite, tout le monde se connecte avec un seul écran : téléphone ou e-mail + mot de passe. L'application ouvre le bon espace selon le rôle.

### Sécurité appliquée par la base (et pas seulement par l'application)

- Un chauffeur ne voit que sa fiche, ses dépôts, ses salaires et son tricycle. Il ne peut pas modifier son contrat ni ses montants.
- Les dépôts faits par un chauffeur sont toujours **« à confirmer »**. Ils ne comptent qu'une fois confirmés par le propriétaire ou le gestionnaire (en attendant le branchement Mobile Money).
- La date d'un dépôt est fixée par le serveur : impossible d'antidater.
- Un dépôt ne se modifie ni ne se supprime : on peut seulement le confirmer, le rejeter ou l'annuler par une contre-écriture.
- Le gestionnaire ne voit pas les salaires, ne valide pas les dépenses et ne modifie pas les contrats.
- Les photos de CIP et de visage sont privées : seul le chauffeur concerné et le staff peuvent les voir.

Ces règles ont été testées sur une base PostgreSQL locale qui imite Supabase.

## Mode démonstration

- Les données sont enregistrées **sur l'appareil** (`shared_preferences`), avec des exemples créés au premier lancement.
  Paramètres → « Réinitialiser la démonstration » recrée les exemples.
- Les positions GPS sont **simulées**, à vitesse accélérée pour qu'on voie les tricycles bouger.
- Les SMS de reçu et le coupe-moteur sont **simulés** : ils apparaissent dans le journal d'activité.

## Organisation du code

| Fichier | Rôle |
|---|---|
| `lib/theme.dart` | Couleurs du Bénin (vert, jaune, rouge) et code d'état |
| `lib/models.dart` | Tricycle, chauffeur et contrat, versement, dépense, incident, inspection |
| `lib/distant.dart` | Lien avec Supabase : comptes, tables, photos, temps réel |
| `supabase/schema.sql` | Base de données et règles de sécurité par rôle |
| `lib/store.dart` | Données, calcul des arriérés, règles d'alerte, simulation GPS |
| `lib/ecrans/` | Écrans : accueil, carte, versements, flotte, fiches, rapports, alertes, paramètres |

Toutes les lectures et écritures passent par `SperoStore`. Pour brancher le serveur, il suffit de changer `charger()`, `enregistrer()` et les méthodes d'action : les écrans ne changent pas.

## Prochaines étapes

1. **Serveur Supabase** : fait (voir plus haut). Reste à créer le projet et à le relier.
2. **Traceurs GPS** : serveur Traccar, puis remplacer `_genererHistorique()` et `_tick()` par les positions réelles.
3. **Mobile Money** : FedaPay ou KKiaPay, pour les dépôts des chauffeurs et le paiement des salaires.
4. **Vérification du visage** : comparer automatiquement le selfie à la photo de la CIP (service KYC, par exemple Smile ID).
5. **SMS** : fournisseur d'envoi pour les reçus et les alertes critiques.
6. **Photos** : brancher `image_picker` aussi sur les reçus de dépense et les inspections.
7. **Fond de carte** : les tuiles OpenStreetMap publiques conviennent pour tester, mais pas pour une application en production. Il faudra un fournisseur (MapTiler, Stadia ou Google Maps).

## Tests

```bash
flutter test
```

Ils vérifient le calcul des arriérés, le repos du dimanche et l'annulation d'un versement. Ils ouvrent aussi chaque écran, en taille téléphone et PC, pour les deux profils.
