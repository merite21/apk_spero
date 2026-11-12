-- =====================================================================
-- Spero : base de données Supabase
-- À exécuter une seule fois dans Supabase > SQL Editor > New query.
--
-- Rôles : proprietaire (voit tout, décide), gestionnaire (terrain, droits
-- limités), chauffeur (ne voit que ses propres données).
-- Les droits sont appliqués par la base elle-même (Row Level Security) :
-- même un chauffeur qui bricolerait l'application ne peut pas lire les
-- données des autres ni modifier son contrat.
--
-- Codes des listes (identiques à l'application) :
--   statut chauffeur : 0 en attente, 1 validé, 2 refusé
--   statut versement : 0 confirmé, 1 à confirmer, 2 rejeté
--   mode paiement    : 0 espèces, 1 MTN MoMo, 2 Moov Money
--   mode salaire     : 0 MTN MoMo, 1 Moov Money, 2 virement, 3 espèces
--   statut dépense   : 0 en attente, 1 validée, 2 refusée
-- =====================================================================

-- ---------- Profils (un par compte) ----------
create table if not exists public.profils (
  id uuid primary key references auth.users on delete cascade,
  role text not null default 'chauffeur' check (role in ('proprietaire', 'gestionnaire', 'chauffeur')),
  nom text not null default '',
  telephone text not null default '',
  email_auth text not null default ''
);

create or replace function public.mon_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profils where id = auth.uid()
$$;

create or replace function public.est_proprio() returns boolean
language sql stable as $$ select coalesce(public.mon_role() = 'proprietaire', false) $$;

create or replace function public.est_staff() returns boolean
language sql stable as $$ select coalesce(public.mon_role() in ('proprietaire', 'gestionnaire'), false) $$;

-- Chaque nouveau compte devient « chauffeur ». Les comptes propriétaire et
-- gestionnaire sont promus à la main avec definir_role() (voir README).
create or replace function public.nouveau_compte() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profils (id, role, nom, telephone, email_auth)
  values (new.id, 'chauffeur',
          coalesce(new.raw_user_meta_data->>'nom', ''),
          coalesce(new.raw_user_meta_data->>'telephone', ''),
          coalesce(new.email, ''));
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.nouveau_compte();

-- ---------- Tables métier ----------
create table if not exists public.tricycles (
  id text primary key,
  immatriculation text not null,
  imei_traceur text not null default '',
  cout_achat integer not null default 0,
  date_achat timestamptz not null default now(),
  kilometrage double precision not null default 0,
  km_derniere_vidange integer not null default 0
);

create table if not exists public.chauffeurs (
  id text primary key, -- = identifiant du compte (auth.users.id)
  nom text not null,
  telephone text not null,
  email text,
  piece_identite text not null default '',
  ifu text,
  photo_cip text,     -- chemin dans le stockage « dossiers »
  photo_visage text,
  statut smallint not null default 0,
  date_inscription timestamptz not null default now(),
  date_validation timestamptz,
  motif_refus text,
  contrat_accepte_le timestamptz,
  signature text,
  garant text not null default '',
  telephone_garant text not null default '',
  tricycle_id text references public.tricycles(id),
  montant_journalier integer not null default 10000,
  salaire_mensuel integer not null default 75000,
  caution integer not null default 50000,
  debut_contrat timestamptz not null default now(),
  repos_dimanche boolean not null default true,
  heure_debut smallint not null default 6,
  heure_fin smallint not null default 22,
  mode_habituel smallint not null default 1,
  actif boolean not null default false
);

create table if not exists public.versements (
  id text primary key,
  chauffeur_id text not null references public.chauffeurs(id),
  montant integer not null,
  mode smallint not null,
  date timestamptz not null default now(),
  saisi_par text not null,
  annule_id text,
  motif text,
  statut smallint not null default 0,
  auteur uuid default auth.uid()
);

create table if not exists public.depenses (
  id text primary key,
  tricycle_id text not null references public.tricycles(id),
  categorie smallint not null,
  montant integer not null,
  description text not null,
  date timestamptz not null default now(),
  saisi_par text not null,
  avec_recu boolean not null default false,
  statut smallint not null default 0
);

create table if not exists public.incidents (
  id text primary key,
  tricycle_id text not null references public.tricycles(id),
  type text not null,
  description text not null,
  date timestamptz not null default now(),
  saisi_par text not null,
  resolu boolean not null default false
);

create table if not exists public.inspections (
  id text primary key,
  tricycle_id text not null references public.tricycles(id),
  date timestamptz not null default now(),
  saisi_par text not null,
  points jsonb not null,
  numero_moteur text not null,
  commentaire text not null default ''
);

create table if not exists public.salaires (
  id text primary key,
  chauffeur_id text not null references public.chauffeurs(id),
  montant integer not null,
  mode smallint not null,
  periode text not null,
  date timestamptz not null default now()
);

create table if not exists public.journal (
  id bigserial primary key,
  date timestamptz not null default now(),
  auteur text not null,
  action text not null
);

create table if not exists public.alertes_traitees (
  id text primary key,
  commentaire text not null
);

create table if not exists public.moteurs_bloques (
  tricycle_id text primary key references public.tricycles(id)
);

create table if not exists public.parametres (
  id smallint primary key default 1 check (id = 1),
  heure_limite smallint not null default 20,
  seuil_depense integer not null default 25000,
  facteur_km double precision not null default 1.5,
  rayon_zone_km double precision not null default 8,
  minutes_sans_signal integer not null default 30,
  km_vidange integer not null default 3000
);
insert into public.parametres (id) values (1) on conflict do nothing;

-- ---------- Accès de l'application (fonctionne même si « exposer automatiquement les tables » est décoché) ----------
grant usage on schema public to anon, authenticated;
revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage on all sequences in schema public to authenticated;

-- ---------- Sécurité : activer RLS partout ----------
alter table public.profils enable row level security;
alter table public.tricycles enable row level security;
alter table public.chauffeurs enable row level security;
alter table public.versements enable row level security;
alter table public.depenses enable row level security;
alter table public.incidents enable row level security;
alter table public.inspections enable row level security;
alter table public.salaires enable row level security;
alter table public.journal enable row level security;
alter table public.alertes_traitees enable row level security;
alter table public.moteurs_bloques enable row level security;
alter table public.parametres enable row level security;

-- Profils
drop policy if exists profils_lecture on public.profils;
create policy profils_lecture on public.profils for select using (id = auth.uid() or public.est_staff());

-- Tricycles : le staff voit tout ; un chauffeur voit le sien ; le propriétaire modifie.
drop policy if exists tricycles_lecture on public.tricycles;
create policy tricycles_lecture on public.tricycles for select using (
  public.est_staff() or id in (select tricycle_id from public.chauffeurs where id = auth.uid()::text));
drop policy if exists tricycles_ecriture on public.tricycles;
create policy tricycles_ecriture on public.tricycles for insert with check (public.est_proprio());
drop policy if exists tricycles_maj on public.tricycles;
create policy tricycles_maj on public.tricycles for update using (public.est_staff());

-- Chauffeurs : chacun voit sa fiche ; le staff voit tout ; seul le propriétaire modifie.
-- (L'inscription et l'acceptation du contrat passent par des fonctions dédiées plus bas.)
drop policy if exists chauffeurs_lecture on public.chauffeurs;
create policy chauffeurs_lecture on public.chauffeurs for select using (id = auth.uid()::text or public.est_staff());
drop policy if exists chauffeurs_maj on public.chauffeurs;
create policy chauffeurs_maj on public.chauffeurs for update using (public.est_proprio());

-- Versements
drop policy if exists versements_lecture on public.versements;
create policy versements_lecture on public.versements for select using (chauffeur_id = auth.uid()::text or public.est_staff());
drop policy if exists versements_chauffeur on public.versements;
create policy versements_chauffeur on public.versements for insert with check (
  public.mon_role() = 'chauffeur' and chauffeur_id = auth.uid()::text
  and statut = 1 and montant > 0 and annule_id is null);           -- toujours « à confirmer »
drop policy if exists versements_gestionnaire on public.versements;
create policy versements_gestionnaire on public.versements for insert with check (
  public.mon_role() = 'gestionnaire' and montant > 0 and annule_id is null);
drop policy if exists versements_proprio on public.versements;
create policy versements_proprio on public.versements for insert with check (public.est_proprio());
drop policy if exists versements_confirmation on public.versements;
create policy versements_confirmation on public.versements for update using (public.est_staff());

-- Dépenses, incidents, inspections : réservés au staff.
drop policy if exists depenses_lecture on public.depenses;
create policy depenses_lecture on public.depenses for select using (public.est_staff());
drop policy if exists depenses_ajout on public.depenses;
create policy depenses_ajout on public.depenses for insert with check (public.est_staff() and (public.est_proprio() or statut <> 2));
drop policy if exists depenses_decision on public.depenses;
create policy depenses_decision on public.depenses for update using (public.est_proprio());

drop policy if exists incidents_lecture on public.incidents;
create policy incidents_lecture on public.incidents for select using (public.est_staff());
drop policy if exists incidents_ajout on public.incidents;
create policy incidents_ajout on public.incidents for insert with check (public.est_staff());
drop policy if exists incidents_maj on public.incidents;
create policy incidents_maj on public.incidents for update using (public.est_staff());

drop policy if exists inspections_lecture on public.inspections;
create policy inspections_lecture on public.inspections for select using (public.est_staff());
drop policy if exists inspections_ajout on public.inspections;
create policy inspections_ajout on public.inspections for insert with check (public.est_staff());

-- Salaires : le propriétaire paie ; chaque chauffeur voit les siens. Le gestionnaire ne les voit pas.
drop policy if exists salaires_lecture on public.salaires;
create policy salaires_lecture on public.salaires for select using (public.est_proprio() or chauffeur_id = auth.uid()::text);
drop policy if exists salaires_ajout on public.salaires;
create policy salaires_ajout on public.salaires for insert with check (public.est_proprio());

-- Journal : tout le monde y écrit, seul le propriétaire le lit.
drop policy if exists journal_lecture on public.journal;
create policy journal_lecture on public.journal for select using (public.est_proprio());
drop policy if exists journal_ajout on public.journal;
create policy journal_ajout on public.journal for insert with check (auth.uid() is not null);

drop policy if exists alertes_lecture on public.alertes_traitees;
create policy alertes_lecture on public.alertes_traitees for select using (public.est_staff());
drop policy if exists alertes_ajout on public.alertes_traitees;
create policy alertes_ajout on public.alertes_traitees for insert with check (public.est_staff());
drop policy if exists alertes_maj on public.alertes_traitees;
create policy alertes_maj on public.alertes_traitees for update using (public.est_staff());

drop policy if exists moteurs_lecture on public.moteurs_bloques;
create policy moteurs_lecture on public.moteurs_bloques for select using (
  public.est_staff() or tricycle_id in (select tricycle_id from public.chauffeurs where id = auth.uid()::text));
drop policy if exists moteurs_ajout on public.moteurs_bloques;
create policy moteurs_ajout on public.moteurs_bloques for insert with check (public.est_proprio());
drop policy if exists moteurs_retrait on public.moteurs_bloques;
create policy moteurs_retrait on public.moteurs_bloques for delete using (public.est_proprio());

drop policy if exists parametres_lecture on public.parametres;
create policy parametres_lecture on public.parametres for select using (auth.uid() is not null);
drop policy if exists parametres_maj on public.parametres;
create policy parametres_maj on public.parametres for update using (public.est_proprio());

-- ---------- Garde-fous supplémentaires ----------

-- Dépôts et journal : la date et l'auteur sont fixés par le serveur (pas d'antidatage).
create or replace function public.horodater() returns trigger
language plpgsql as $$
begin
  new.date := now();
  if tg_table_name = 'versements' then
    new.auteur := auth.uid();
    if public.mon_role() = 'chauffeur' then new.saisi_par := 'Chauffeur (application)'; end if;
  end if;
  return new;
end $$;
drop trigger if exists horodater_versements on public.versements;
create trigger horodater_versements before insert on public.versements for each row execute function public.horodater();
drop trigger if exists horodater_journal on public.journal;
create trigger horodater_journal before insert on public.journal for each row execute function public.horodater();

-- Un dépôt ne se modifie jamais : on ne peut changer que son statut (confirmer / rejeter) et le motif.
revoke update on public.versements from anon, authenticated;
grant update (statut, motif) on public.versements to authenticated;
-- Un incident : seulement le marquer comme résolu.
revoke update on public.incidents from anon, authenticated;
grant update (resolu) on public.incidents to authenticated;

-- Tricycles : le gestionnaire ne peut mettre à jour que le kilométrage (vidange).
create or replace function public.garde_tricycles() returns trigger
language plpgsql as $$
begin
  if not public.est_proprio() and (
    new.id is distinct from old.id or new.immatriculation is distinct from old.immatriculation
    or new.imei_traceur is distinct from old.imei_traceur or new.cout_achat is distinct from old.cout_achat
    or new.date_achat is distinct from old.date_achat) then
    raise exception 'Seul le propriétaire peut modifier la fiche d''un tricycle';
  end if;
  return new;
end $$;
drop trigger if exists garde_tricycles on public.tricycles;
create trigger garde_tricycles before update on public.tricycles for each row execute function public.garde_tricycles();

-- ---------- Fonctions appelées par l'application ----------

-- Fin d'inscription d'un chauffeur : crée sa fiche « en attente ».
-- Les champs du contrat ne peuvent pas être choisis par le chauffeur.
create or replace function public.completer_inscription(
  p_nom text, p_telephone text, p_email text, p_cip text, p_ifu text,
  p_photo_cip text, p_photo_visage text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  insert into public.chauffeurs (id, nom, telephone, email, piece_identite, ifu, photo_cip, photo_visage, statut, actif)
  values (auth.uid()::text, p_nom, p_telephone, nullif(p_email, ''), p_cip, nullif(p_ifu, ''), p_photo_cip, p_photo_visage, 0, false)
  on conflict (id) do nothing;
  update public.profils set nom = p_nom, telephone = p_telephone where id = auth.uid();
  insert into public.journal (auteur, action) values ('Chauffeur ' || p_nom, 'Nouvelle inscription : ' || p_nom || ' (' || p_telephone || ')');
end $$;

-- Acceptation du contrat par le chauffeur lui-même.
create or replace function public.accepter_contrat(p_signature text) returns void
language plpgsql security definer set search_path = public as $$
declare v_nom text;
begin
  update public.chauffeurs set contrat_accepte_le = now(), signature = p_signature
  where id = auth.uid()::text and statut = 1 and contrat_accepte_le is null
  returning nom into v_nom;
  if v_nom is not null then
    insert into public.journal (auteur, action) values ('Chauffeur ' || v_nom, 'Contrat accepté par ' || v_nom);
  end if;
end $$;

-- Connexion avec un téléphone ou un e-mail : renvoie l'adresse de connexion du compte.
create or replace function public.email_connexion(p_identifiant text) returns text
language sql stable security definer set search_path = public as $$
  select p.email_auth from public.profils p
  left join public.chauffeurs c on c.id = p.id::text
  where (position('@' in p_identifiant) > 0 and (lower(c.email) = lower(p_identifiant) or lower(p.email_auth) = lower(p_identifiant)))
     or (position('@' in p_identifiant) = 0 and length(regexp_replace(p_identifiant, '\D', '', 'g')) >= 8
         and regexp_replace(p.telephone, '\D', '', 'g') like '%' || right(regexp_replace(p_identifiant, '\D', '', 'g'), 8))
  limit 1
$$;

-- Promotion d'un compte en propriétaire ou gestionnaire (à lancer dans le SQL Editor).
create or replace function public.definir_role(p_email text, p_role text, p_nom text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.profils set role = p_role, nom = coalesce(p_nom, nom)
  where id = (select id from auth.users where lower(email) = lower(p_email));
  if not found then raise exception 'Aucun compte avec l''e-mail %', p_email; end if;
end $$;
revoke execute on function public.definir_role(text, text, text) from public, anon, authenticated;

-- ---------- Stockage des photos (CIP, selfie) ----------
insert into storage.buckets (id, name, public) values ('dossiers', 'dossiers', false) on conflict do nothing;

drop policy if exists dossiers_depot on storage.objects;
create policy dossiers_depot on storage.objects for insert to authenticated
  with check (bucket_id = 'dossiers' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists dossiers_lecture on storage.objects;
create policy dossiers_lecture on storage.objects for select to authenticated
  using (bucket_id = 'dossiers' and ((storage.foldername(name))[1] = auth.uid()::text or public.est_staff()));

-- ---------- Temps réel ----------
do $$
declare t text;
begin
  foreach t in array array['tricycles','chauffeurs','versements','depenses','incidents','inspections','salaires','journal','alertes_traitees','moteurs_bloques','parametres']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
