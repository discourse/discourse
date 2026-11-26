# CSS variable migration: what is left

The counts in "Before the first merge" come from the run on 2026-11-25, on `main` at `bce3afde1ff`. They change with each rebase. The naming todo list has no counts of its own. Its current state is in the generated tables in [`review/`](review/README.md), which the [README](README.md) explains.

## Before the first merge

- [ ] **Design sign-off on the compare report.** About 1,500 to 1,800 declarations change per profile. The largest changes come from the token values in the semantic layer:
  - Text: `#222` to `#434343` (657 declarations in Foundation light)
  - Faint text: `#909090` to `#bdbdbd` (154)
  - Icons: `#646464` to `#a7a7a7` (123)
  - Accent borders: `#0088cc` to `#afe4ff` (108)
- [ ] **Decisions for Manuel.** The mapping has a choice for each of these, and each one needs his confirmation:
  - The entries with an `open` question in `mapping.json`. [review/todo.md](review/todo.md) lists them under "Open decisions". Remove the `open` key when the question is answered.
  - The semantic text colors. No single entry holds this question.
  - Names for the nine light/dark choosers, such as `--primary-med-or-secondary-med`. They stay as base variables for now.
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

Two generated tables hold the list. Regenerate them to see the current state:

- [review/unmapped.md](review/unmapped.md): the names that do not follow the naming scheme. Each needs an entry in `mapping.json`. The table groups them by owner and shows how many files use each name.
- [review/todo.md](review/todo.md): the reads of split variables that are undecided. Each needs a role in its split entry, or an override in `overrides.json`.

On 2026-11-26 the tables listed 602 names and 554 undecided reads.

### Decisions that make the list shorter

- [ ] **Internal variables.** Under Manuel's `D-scope-internal` decision, variables used only inside their own file are out of scope. 298 of the 602 names are used in only one file: 55 in core components, 106 in bundled plugins, 132 in core's other stylesheets and 5 in Horizon. If the naming rule skips internal variables, about half of the list goes away. The other option is to drop the decision for core components and bundled plugins and migrate all of their variables, which covers 258 names.
- [ ] **Scope for core's other stylesheets.** 332 names are declared outside `common/components` and `common/ui-kit`, such as the `--d-sidebar-*`, `--d-post-*` and `--d-topic-*` families. Decide which of them a component owns.
- [ ] **The spacing scale.** The `--space-*` names need words in the vocabulary.
- [ ] **Third-party names.** Give names that come from libraries an allowlist.

## Exploration notes

- **Foundation dark button contrast.** With the compiled CSS in Chromium, primary and success button labels changed from `#222` to `#ddd` while their backgrounds stayed the same. Contrast fell from 5.16:1 to 2.27:1 for primary and from 4.96:1 to 2.36:1 for success. To reproduce, load the Foundation dark palette and common stylesheet in Chromium with dark mode enabled, then inspect `.btn-primary` and `.btn-success` on the base and migration commits. Both variants now use `--d-sys-color-text-inverse`.
- **Saved appearance drafts.** Activation revalidates the stored styles against the current variable registry before the CSS renamer runs. On the migration branch, pass `{"variables" => {"--d-border-radius" => "12px"}}` to `AppearanceStyles::Policy.call` to reproduce the unknown-variable error for a previously valid draft. Explore normalizing legacy names before revalidation.
- **Legacy border overrides.** Run the PostCSS renamer with the shipped border mapping. A theme declaration of `--d-button-border: 2px dashed red` produces a solid border. A declaration of `--d-button-border: var(--my-border)` survives, but consumers read the new width and color properties, so the override has no effect. Explore which legacy shorthand forms the compatibility pass should preserve.

## After the migration

- [ ] Remove `css_variable_migration/`.
- [ ] Remove `postcss` and `postcss-scss` from the root `package.json` if nothing else uses them. The renamer, the lint rules and the JSON files in `app/assets/stylesheets/` stay, because themes and plugins depend on them.
