# Phase 4 — Bespoke dropdowns + test infrastructure

**Goal:** the remaining non-select dropdowns move to `DMenu`, and the `.select-kit-*`
test infrastructure gains new-component support.

See RFC: *Roadmap › Phase 4*, *Migration strategy*. (Maps to dev topic P3 + P10.)

## Tasks

- ☐ **Bespoke dropdowns → `DMenu`/`DDropdownMenu`** (action menus, not value selects):
  the notifications-button family and the remaining `dropdown-select-box` variants
  (categories-admin, bulk-select-bookmarks, user-notifications). (composer-actions is
  excluded — replaced independently by `composer-actions-new`.)
- ☐ **Test infra rewrite** (do BEFORE the bulk migration so each component migration
  doesn't churn dozens of specs): the JS helper `tests/helpers/select-kit-helper.js`
  (~54 acceptance files) and the Ruby page object
  `spec/system/page_objects/components/select_kit.rb` (~67 specs) to the new BEM/roles,
  supporting BOTH old and new pickers; prove it on the first high-traffic picker.

## Exit criteria

- Core + bundled plugins fully off select-kit for these surfaces.
- Test infra migrated; system specs re-verified green.
