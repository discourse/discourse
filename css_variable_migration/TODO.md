# CSS variable migration: what is left

The counts come from the run on 2026-11-25, on `main` at `bce3afde1ff`. They change with each rebase. To get the current list, run the codemod and then `pnpm lint:css`. The [README](README.md) explains how to read the output.

## Before the first merge

- [ ] **Design sign-off on the compare report.** About 1,500 to 1,800 declarations change per profile. The largest changes come from the token values in the semantic layer:
  - Text: `#222` to `#434343` (657 declarations in Foundation light)
  - Faint text: `#909090` to `#bdbdbd` (154)
  - Icons: `#646464` to `#a7a7a7` (123)
  - Accent borders: `#0088cc` to `#afe4ff` (108)
- [ ] **Decisions for Manuel.** The mapping has a choice for each of these, and each one needs his confirmation:
  - Bold is 700.
  - The footer navigation shadow becomes the hairline shadow.
  - The composer shadows.
  - The semantic text colors.
  - Names for the nine light/dark choosers, such as `--primary-med-or-secondary-med`. They stay as base variables for now.
  - `--d-hover` keeps its value under its new name, and the hovered surface merges into it.
- [ ] **Hand edits that the codemod cannot make:**
  - `app/assets/stylesheets/common/foundation/mixins.scss`: two reads of `--primary-rgb` and `--secondary-rgb` with a Sass `$amt` alpha
  - `plugins/discourse-data-explorer/assets/javascripts/discourse/components/data-explorer-chart.gjs`: reads `--tertiary-rgb` at runtime
  - `app/assets/stylesheets/common/components/theme-card.scss`: builds names with `--#{$color}`
- [ ] **Review of "Teach the appearance style checks the new CSS variable names"** by the owner of `lib/appearance_styles/`. That commit changes the feature and three of its specs.
- [ ] **Full CI passes.** Only the stylesheet, asset processor and appearance specs have run locally.
- [ ] **Visual check.** Take screenshots of Foundation and Horizon in light and dark mode. The compare report does not cover values that JS sets at runtime, RTL stylesheets, or overrides on ancestor elements.
- [ ] **Decide what the naming rule does at merge.** `pnpm lint:css` fails until the list below is empty. Either finish the list, or make `discourse/css-variable-names` a warning until it is empty.
- [ ] **Decide how the branch lands:** one squashed commit, or the written commits and the generated commit.
- [ ] **Tell theme authors.** Old names keep working through the renamer, so this is a deprecation notice, not a breaking change.
- [ ] **Rebase and regenerate as the last step**, as the README describes.

## The naming todo list

489 names do not follow the naming scheme (749 lint errors), and 427 reads of split variables are undecided.

### Decisions that make the list shorter

- [ ] **Internal variables.** Under Manuel's `D-scope-internal` decision, variables used only inside their own file are out of scope. 409 of the 489 names are set in only one file. If the naming rule skips internal variables, most of the list goes away.
- [ ] **Third-party names.** Give names that come from libraries an allowlist.

### Names without a mapping entry

Each name needs an entry in `mapping.json`.

- [ ] Core (377 names). The largest families:
  - `--d-sidebar-*`: 37
  - `--d-post-*`: 22
  - `--d-topic-*`: 17
  - `--space-*`: 14. The spacing scale needs names in the vocabulary.
  - `--d-nav-*`: 9
  - `--d-welcome-*`: 8
  - `--d-skeleton-*` and `--d-input-*`: 7 each
- [ ] Horizon (45 names)
- [ ] Plugins:
  - discourse-events: 33
  - discourse-ai: 27
  - discourse-workflows and chat: 16 each
  - blog: 13
  - discourse-solved and boards: 9 each
  - live: 5
  - 8 other plugins: 2 or fewer each

### Undecided split reads

Each read needs a role in its split entry, or an override in `overrides.json`. The codemod writes the full list to `tmp/css_variable_migration/undecided.json`.

- [ ] `--tertiary`: 99
- [ ] `--primary-low-mid`: 79
- [ ] `--primary-medium`: 67
- [ ] `--primary`: 58
- [ ] `--secondary`: 55
- [ ] `--primary-med-or-secondary-med`: 43
- [ ] `--primary-low`: 30
- [ ] 21 other variables: 16 or fewer each

## After the migration

- [ ] Remove `css_variable_migration/`.
- [ ] Remove `postcss` and `postcss-scss` from the root `package.json` if nothing else uses them. The renamer, the lint rules and the JSON files in `app/assets/stylesheets/` stay, because themes and plugins depend on them.
