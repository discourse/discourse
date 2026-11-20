# Appearance changes and Horizon copies

Appearance changes save a previewable draft before activation. Palette-only
changes continue to target the existing theme. Styled themes use typed data
validated by `AppearanceStyles::Policy`, not arbitrary CSS from the author.

## Choosing a base

`AppearanceChange::DraftTheme` accepts `base_theme_id: Theme::CORE_THEMES["horizon"]`
for a standalone Horizon copy. The source must be the current Horizon theme or
an unchanged synced copy. Revisions inherit the replaced copy's Horizon base.
Without an explicit base or a Horizon revision, drafts retain the existing
Foundation behavior. Authoring tools include the selected base in their signed
draft so approval does not silently change it to another design.

A copy imports all of bundled Horizon, including its JavaScript, settings,
translations, assets and modifiers. The policy-generated common SCSS is composed
with the imported common SCSS. Previewing selects the copy's theme ID and does not
mutate the live theme.

## Settings and components

A draft snapshots the source's supported theme settings and theme site settings.
Subsequent source imports run setting migrations and preserve each copy's local
configuration. Changes to the source theme's settings after drafting do not
silently change existing copies.

Components attached to the source are attached to the draft as the **same
component records**. Components are never duplicated. Updating one of those
components affects every theme using it, including Horizon and its copies.
Discarding a draft removes its relationships, not those shared components.
The author must have permission to edit the source and all attached components.

## Updates and ownership

`themes.appearance_sync` holds the source identity, typed overlay, generated CSS
and a fingerprint of the imported files, settings, translation overrides,
modifiers and component relationships. It belongs to the theme, not only to its
appearance record, so a retained theme can keep receiving updates after its
appearance record is discarded.

`SystemThemesManager.sync_theme!("horizon")` resyncs all unchanged linked copies,
including drafts, live themes and previous versions. It preserves names, selected
palettes and copy configuration. Imported bundled palettes are not accumulated
per version. Each copy updates transactionally and is checked for compilation
errors. A failed copy keeps its last-known-good files and does not prevent other
copies updating; failures are logged with the copy's ID.

Switching back undoes the customization, not Horizon's release. Both the current
and previous versions keep receiving bundled updates.

Admins explicitly detach a copy from Horizon updates before editing its files,
settings or component relationships through the theme editor. Detachment is
one-way. A detached copy becomes an ordinary theme and no longer qualifies for
assistant-managed activation, revisions or disposal. Unexpected changes through
other write paths invalidate the fingerprint: resync skips the copy and the
assistant treats it as a changed theme rather than overwriting it.

The system importer is the update boundary. The development file watcher's
single-file hot reload is not a full resync of linked copies; run the system-theme
sync path when developing bundled updates that need testing across copies.

## Initial style policy

Horizon copies support non-color styles only. Color and background declarations,
color-bearing variables, border shorthands, shadows and opacity are refused with
a checker error until Horizon-aware contrast checking is available. Sizes,
spacing, corner radii and supported typography remain available. Palettes handle
colors separately; colors-only authoring requests keep the current theme.

This deliberately does not claim that Foundation's contrast checks validate
Horizon's surfaces, important declarations or relative-color expressions.

## Regression coverage

- `spec/requests/appearance_horizon_sync_spec.rb`: ownership, settings, shared
  components, versions, cleanup, update rollback, detachment and permissions.
- `spec/lib/appearance_styles/policy_spec.rb`: the non-color subset.
- `spec/system/appearance_horizon_copies_spec.rb`: rendered Horizon preview,
  JavaScript topic cards, overlay cascade, preview isolation and explicit detach.
- Appearance-authoring tool specs: signed bases, approval text, revisions,
  palette-only requests, checker repair and activation after resync or hand edits.
