#!/usr/bin/env python3
"""Installe Spero sur un compte Supabase, de bout en bout.

    SUPABASE_TOKEN=sbp_... python3 supabase/installer.py \
        --email proprio@exemple.com --nom "Nom" [--mdp ...] \
        [--gest-email ... --gest-nom ... --gest-mdp ...]

Crée (ou reprend) le projet « spero », installe schema.sql, désactive la
confirmation par e-mail, crée les comptes propriétaire / gestionnaire et écrit
config.json. Peut être relancé sans risque.
"""
import argparse, json, os, secrets, string, sys, time, urllib.error, urllib.request
from pathlib import Path

API = 'https://api.supabase.com/v1'
RACINE = Path(__file__).resolve().parent.parent


def appel(methode, url, jeton, corps=None, attendu=(200, 201)):
    donnees = json.dumps(corps).encode() if corps is not None else None
    req = urllib.request.Request(url, data=donnees, method=methode)
    req.add_header('Authorization', f'Bearer {jeton}')
    req.add_header('Content-Type', 'application/json')
    req.add_header('User-Agent', 'spero-installer')
    if '/auth/v1/' in url:
        req.add_header('apikey', jeton)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            texte = r.read().decode()
            return json.loads(texte) if texte else None
    except urllib.error.HTTPError as e:
        msg = e.read().decode()
        raise RuntimeError(f'{methode} {url} → {e.code} : {msg}') from None


def mdp_aleatoire(n=14):
    a = string.ascii_letters + string.digits
    return ''.join(secrets.choice(a) for _ in range(n))


def sql(ref, jeton, requete):
    return appel('POST', f'{API}/projects/{ref}/database/query', jeton, {'query': requete})


def creer_compte(ref, service, email, mdp, nom, role):
    url = f'https://{ref}.supabase.co/auth/v1/admin/users'
    try:
        appel('POST', url, service, {'email': email, 'password': mdp, 'email_confirm': True, 'user_metadata': {'nom': nom}})
        print(f'  compte {role} créé : {email}')
    except RuntimeError as e:
        if 'already' in str(e).lower() or '422' in str(e):
            print(f'  compte {email} déjà existant, conservé')
        else:
            raise


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--email')
    p.add_argument('--nom', default='')
    p.add_argument('--ref')
    p.add_argument('--mdp')
    p.add_argument('--gest-email')
    p.add_argument('--gest-nom')
    p.add_argument('--gest-mdp')
    p.add_argument('--region', default='eu-west-3')
    a = p.parse_args()
    jeton = os.environ.get('SUPABASE_TOKEN') or sys.exit('SUPABASE_TOKEN manquant')

    if a.ref:
        ref = a.ref
        print(f'1-2. Projet indiqué : {ref}')
    else:
        print('1. Organisation')
        orgs = appel('GET', f'{API}/organizations', jeton)
        if not orgs:
            sys.exit('Aucune organisation sur ce compte : ouvrez une fois supabase.com/dashboard pour en créer une.')
        org = orgs[0]['id']
        print('2. Projet')
        projets = [x for x in appel('GET', f'{API}/projects', jeton) if x['name'] == 'spero']
        if projets:
            ref = projets[0]['id']
            print(f'  projet existant : {ref}')
        else:
            mdp_base = mdp_aleatoire(24)
            pr = appel('POST', f'{API}/projects', jeton,
                       {'name': 'spero', 'organization_id': org, 'db_pass': mdp_base, 'region': a.region})
            ref = pr['id']
            (RACINE / 'supabase' / '.mot_de_passe_base').write_text(mdp_base + '\n')
            print(f'  projet créé : {ref} (mot de passe de la base dans supabase/.mot_de_passe_base)')

    print('3. Démarrage du serveur', end='', flush=True)
    for _ in range(90):
        etat = appel('GET', f'{API}/projects/{ref}', jeton).get('status')
        if etat == 'ACTIVE_HEALTHY':
            break
        print('.', end='', flush=True)
        time.sleep(10)
    else:
        sys.exit(f'\n  le projet n\'est pas prêt (état {etat}), relancez plus tard')
    print(' prêt')

    print('4. Base de données et sécurité')
    for essai in range(6):
        try:
            sql(ref, jeton, (RACINE / 'supabase' / 'schema.sql').read_text())
            break
        except RuntimeError:
            if essai == 5:
                raise
            time.sleep(15)

    print('5. Inscription sans confirmation par e-mail')
    appel('PATCH', f'{API}/projects/{ref}/config/auth', jeton, {'mailer_autoconfirm': True})

    print('6. Clés')
    cles = appel('GET', f'{API}/projects/{ref}/api-keys?reveal=true', jeton)
    anon = next(k['api_key'] for k in cles if k['name'] == 'anon')
    service = next(k['api_key'] for k in cles if k['name'] == 'service_role')

    print('7. Comptes')
    mdp = a.mdp or mdp_aleatoire(10)
    if a.email:
      creer_compte(ref, service, a.email, mdp, a.nom, 'propriétaire')
      sql(ref, jeton, f"select definir_role('{a.email.replace(chr(39), '')}', 'proprietaire', '{a.nom.replace(chr(39), chr(39) * 2)}');")
    gest_mdp = None
    if a.gest_email:
        gest_mdp = a.gest_mdp or mdp_aleatoire(10)
        creer_compte(ref, service, a.gest_email, gest_mdp, a.gest_nom or '', 'gestionnaire')
        sql(ref, jeton, f"select definir_role('{a.gest_email.replace(chr(39), '')}', 'gestionnaire', '{(a.gest_nom or '').replace(chr(39), chr(39) * 2)}');")

    print('8. config.json')
    (RACINE / 'config.json').write_text(json.dumps(
        {'SUPABASE_URL': f'https://{ref}.supabase.co', 'SUPABASE_ANON_KEY': anon}, indent=2) + '\n')

    print('\nTerminé.')
    if a.email:
      print(f'  Propriétaire : {a.email} / {mdp if not a.mdp else "(mot de passe choisi)"}')
    if gest_mdp:
        print(f'  Gestionnaire : {a.gest_email} / {gest_mdp if not a.gest_mdp else "(mot de passe choisi)"}')


if __name__ == '__main__':
    main()
