---
name: discourse-content-localization
description: Use when adding, modifying, or reviewing Discourse content localization for core models or plugin models. Covers Localizable models, localization tables, source locale handling, hot-route serializer preloading, fallback behavior, manual editing UI, discourse-ai backfill/detection boundaries, plugin dependency constraints, and tests.
---

# Discourse Content Localization

Use this before localizing dynamic Discourse content such as Sidebar sections, Groups, Docs, Events, or other models listed in content-localization status trackers.

## First Decisions

- Core models: put the data model, serializers, Guardian checks, API behavior, and edit UI in core. Put automatic AI detection/backfill/localizer jobs in `plugins/discourse-ai`.
- Plugin models: do not create plugin-to-plugin dependencies casually. Create proper plugin APIs and plugin outlets / hooks.
- Manual editing localizations UI is part of calling a model “localizable”. Flag it upfront. Pick either an existing edit page/modal or a new route before implementing the backend.
- Hot-route safety is mandatory, e.g. on any discovery routes. Any serializer that may call `get_localization` must receive records with `:localizations` preloaded.

## Core Model Pattern

- Add `include Localizable` to the source model and a nullable `locale` column with limit 20.
- Add `<Model>Localization` with `include LocaleMatchable`, `belongs_to :model`, a `locale` string limit 20, translated fields with source-model length limits, and a unique `(model_id, locale)` index.
- Use `get_localization` for exact, normalized, and optional default-locale fallback behavior. Do not reimplement locale fallback in serializers.
- Add `ContentLocalization.show_translated_<model>?` using `SiteSetting.content_localization_enabled`, source `locale.present?`, and `!model.in_user_locale?`. Match Post/Topic only when show-original behavior is relevant.
- Preload in every list, boot, site JSON, admin list, and controller path that serializes localized fields. Use `includes(:localizations)` or `includes(:localizations, children: :localizations)` as needed.
- Serializer methods should return `localization.field.presence || original_field` and expose localization rows only to users who can edit them.

## Editing UI And API

- Reuse an existing edit surface when it is the natural place users already manage the content. Otherwise add a dedicated route.
- Only users passing a Guardian localization check can edit localizations. For admin-owned/global content, prefer admin-only checks unless product intent says otherwise.
- Server-side params must accept localization rows and enforce the same max lengths as the model. UI validation is not sufficient.
- Existing source fields should remain editable independently from translations. Destroying a source record must destroy its localizations.
- Edit/settings surfaces must load source/default values, not localized display values. For example, a Japanese admin opening the "Support" category settings should see source name "Support", not its localized name "サポート".
- Preserve existing API response shape where possible; add `localizations` arrays only for authorized editors.

## discourse-ai Backfill Pattern

- Add model-specific `Candidate`, `Localizer`, regular localize job, and scheduled backfill jobs in discourse-ai only.
- Candidate scopes should include only content intended for automatic translation. For global/admin content, avoid user-private rows unless explicitly requested.
- Localize only records with source `locale` present. Delete localizations whose locale matches the source locale. Skip target locales that normalize to the source locale.
  - an "en" post does not need "en" translation nor "en_GB" translation
- Respect `DiscourseAi::Translation.enabled?`, `backfill_enabled?`, configured agents, hourly rate, credits, and error logging patterns used by existing tag/category jobs.

## Tests

- Model specs: validations, uniqueness, dependency cleanup, fallback via `get_localization`.
- Serializer/request specs: localized value when enabled, original value when disabled/source locale missing/same locale, editor-only `localizations`, and no N+1 on hot routes.
- UI/system or QUnit specs: authorized editor can view/add/remove localization rows on the chosen edit surface; unauthorized users cannot.
- discourse-ai specs: detector text, localizer writes, scheduled job enqueue/credit gates, regular job limits/skips/errors, and candidate completion if the model appears in translation-progress UI.

## Checklist

- [ ] Localization model has `include LocaleMatchable`, field length limits matching the source, and a unique `(model_id, locale)` index.
- [ ] Serializers preload localizations on hot/list path and fall back to source values without N+1s.
- [ ] Regular presentation payloads do not include localization rows for admins or non-admins.
- [ ] Admins can edit localizations for the model via a UI
- [ ] Edit/localization payloads give authorized admins default values plus localization rows. A Japanese admin opening the "Support" category settings should see source name "Support", not its localized name "サポート".
- [ ] Manual editing UI, API params, and tests cover adding, updating, and removing localization rows. Do not accept empty strings for fields, use frontend validations.
- [ ] Localization editing is authorized server-side, with admin-only checks for admin-owned/global content.
- [ ] discourse-ai detection/backfill stays in `plugins/discourse-ai` for core models and skips source-locale/self translations.
- [ ] Turning off the feature via `SiteSetting.content_localization_enabled` disables all localization behavior, including backfill and detection
