# CSS variable migration

These tools rename core's CSS variables in one change. People review the mapping and the tools. The codemod makes the code changes, and the checks review the result. Nobody edits the generated changes by hand.

This folder is temporary. Remove it when the migration is complete.

The naming scheme, its word lists and the full draft mapping are in the [CSS variables repo](https://github.com/nolosb/discourse-CSS-variables).

## Files

The JSON files are the source of truth. For review, [`review/`](review/README.md) holds generated Markdown tables. There is one table each for system, component, plugin and base palette tokens, plus open items, names that still break the naming scheme, the mapping by kind, and the definitions. Never edit `review/` by hand. Regenerate the tables from the repository root after you run the codemod:

```sh
node css_variable_migration/render-review-tables.mjs
```

The tables read the stylesheets in the working tree, and `review/todo.md` reads the undecided uses that the codemod writes to `tmp/`. Run the codemod first, or the tables describe an older state.

| File                        | Purpose                                                                                        |
| --------------------------- | ---------------------------------------------------------------------------------------------- |
| `mapping.json`              | Each old variable and its new name, grouped by type                                            |
| `definitions.json`          | Values for new variables, or new values for existing ones                                      |
| `apply.mjs`                 | The codemod. It applies both files to core, bundled plugins and themes                         |
| `check.mjs`                 | Confirms that the working tree matches the mapping                                             |
| `compile.rb`, `compare.mjs` | Compile the stylesheets on `main` and on the branch, and list the computed values that differ |
| `mapping.mjs`               | Code that the scripts share                                                                    |
| `render-review-tables.mjs`  | Writes the review tables in `review/`                                                          |

### `mapping.json`

```json
{
  "rename": {
    "--d-button-transition": "--d-comp-DButton-motion-transition",
    "--d-border-radius": {
      "to": "--d-sys-border-radius-md",
      "note": "The theme knob; sm and lg derive from it."
    }
  },
  "merge": {
    "--title-color": {
      "to": "--d-sys-color-text-default",
      "note": "var(--primary), while --d-sys-color-text-default comes from --token-color-text-default (var(--primary-900)); 1 use."
    }
  },
  "rgb": {
    "--primary-rgb": "--primary"
  }
}
```

An entry is the new name, or an object with the new name in `to` and a `note` for reviewers. Add `open` with a question when the entry needs a decision. The review tables list it in `review/todo.md` until someone removes it.

- `rename`: the new name keeps the old value, so nothing looks different.
- `merge`: the old variable takes the value of its new name. The codemod removes the old definition from `:root` in core, so another entry must give the new name its value: a `rename` into the same name, or an entry in `definitions.json`.
- `rgb`: an `-rgb` twin, such as `--primary-rgb`, with its color variable as the new name, or a plain color such as `black` when there is no variable. The codemod rewrites reads to `color-mix()`. The twin stays defined for themes.
- `base`: stays in the base layer, and its uses stay too. The entry is a note. `check.mjs` warns if core stops defining it.
- `border`: a variable that held a whole `border` shorthand, split into the `width` and `color` variables the entry names. Reads become `var(width) solid var(color)`, or the entry's `style` instead of `solid`. Setters become declarations of the two variables, and a shorthand that draws nothing sets the width to 0. The renamer does the same for themes and plugins, using `variable-border-splits.json`.
- `drop`: removed. The entry is a note, or an object with a successor in `to`. The codemod removes the definition from `:root` in core and moves reads to the successor. Setters stay as they are, so a theme that sets the old name cannot restyle what the successor controls. `check.mjs` fails if anything still reads a dropped variable.

- `split`: a base variable with several jobs, such as `--primary-high`. It stays defined, and each use moves to the token for its job. The entry maps roles to tokens, and a role can name a state:

  ```json
  "--primary-low": {
    "border": "--d-sys-color-border-default",
    "background": "--d-sys-color-background-neutral",
    "background:pressed": "--d-sys-color-background-default-pressed"
  }
  ```

  The roles are `text`, `icon`, `background`, `border`, `outline` and `shadow`, and the states are `hovered`, `pressed`, `focused` and `disabled`. A use gets its role from the CSS property, or `icon` when its selectors include `.d-icon`, `.fa`, `.svg-icon` or `svg`, and its state from pseudo-classes in its selectors. A component token, such as `--d-comp-DButton-color-icon-default`, gets its role and state from its own name. `"keep"` leaves a role on the base variable. A rule that sets a split variable inside a selector keeps that value, and also sets the variable's targets from it, because the targets are computed on `:root`.

The draft mapping also has an `open` kind, which the codemod does not support. It is not the `open` key of an entry.

### `overrides.json`

Decisions for single uses that a split's roles cannot make, or make wrong. Uses are found by file, the chain of selectors and at-rules around them joined with ` >> `, and the property:

```json
{
  "plugins/styleguide/assets/stylesheets/colors.scss": {
    ".color-example >> .header_primary": { "background-color": "keep" }
  }
}
```

A decision is a token, `"keep"`, or an object from each split variable in the value to a token or `"keep"`. `apply.mjs` reports overrides that match no use.

### Undecided uses

A split use with no role in its entry and no override stays on the base variable, which keeps working. `apply.mjs` counts them per variable and writes them to `tmp/css_variable_migration/undecided.json`, in the same shape as `overrides.json`. To decide them, add a role to the split, or copy entries to `overrides.json`.

### `definitions.json`

```json
{
  "--d-sys-border-radius-sm": {
    "value": "calc(var(--d-sys-border-radius-md) / 2)",
    "file": "app/assets/stylesheets/common/foundation/base.scss",
    "after": "--d-sys-border-radius-md"
  }
}
```

The codemod sets the value in the first `:root` rule of `file`. If the variable is not there, it adds it after `after`, or at the end of the rule.

## What the codemod changes

- It replaces every old name in stylesheets, JS, templates, Ruby, YAML, SVG and Markdown. Translated locale files are left to the translators.
- It writes `app/assets/stylesheets/variable-renames.json`. The renamer uses it to keep old names working for themes and plugins, and the `discourse/no-renamed-variables` lint rule uses it to find them.
- It writes `app/assets/stylesheets/variable-rgb-twins.json` for the `discourse/no-deprecated-rgb-variables` lint rule.
- It removes declarations that refer to themselves, and the earlier declaration when a rule sets a variable twice. Both happen when two old names share one new name.
- It rewraps lines with Prettier, or with syntax_tree for Ruby, in files that were formatted before.

The codemod cannot see names that JS builds at runtime, or that SCSS builds with `#{}`. `check.mjs` lists the SCSS ones and the `-rgb` reads it could not rewrite. These need a hand edit.

## The todo list

The `discourse/css-variable-names` lint rule checks every custom property against the naming scheme in `app/assets/stylesheets/variable-vocabulary.json`. On this branch, its errors are the work that is left:

- `"--x" does not follow the CSS variable naming scheme` means a stylesheet sets a variable that the mapping does not cover yet. Give it an entry in `mapping.json`. The message says which slot breaks the scheme.
- `"--x" is a base variable with several jobs` means a use of a split variable is still undecided. Add a role to the split, or an override.

Base variables, split variables and `-rgb` twins may be set, and only split variables are checked where they are read. The codemod writes their names to `app/assets/stylesheets/variable-base-layer.json`. The whole list is in [review/unmapped.md](review/unmapped.md) and [review/todo.md](review/todo.md). The first uses the same grammar as the lint rule, and the second comes from the codemod.

`pnpm lint:css` shows the same errors, but it misses some plugin stylesheets. The command passes the plugin patterns to the shell without quotes, and the shell expands `**` as one folder level. Stylesheets at the top of a plugin's stylesheet folder, or more than one folder down, are not linted. On 2026-11-26 this left out 50 of the 602 names.

[TODO.md](TODO.md) holds the decisions and the other work before the migration can merge. Update it when you finish an item.

## Branch layout

The branch has two kinds of commits:

- **Written commits**: framework changes, tools, mapping entries and hand edits.
- **Generated commits**: `DEV: Apply the CSS variable mapping`. These hold only the output of `apply.mjs`. Never change them by hand.

The review tables in `review/` are generated too, but they get their own commit after the generated one. If that commit conflicts during a rebase, take either side and regenerate the tables.

Never rebase or merge a generated commit. Drop it, rebase the written commits, and generate the output again.

## How to iterate

Make every change in `mapping.json`, `definitions.json` or the tools, never in the generated output.

1. Commit your change.
2. Drop the generated commits and rebase on `main`:

   ```sh
   git fetch origin
   GIT_SEQUENCE_EDITOR="sed -i '/DEV: Apply the CSS variable mapping$/d'" git rebase -i origin/main
   ```

   `compare.mjs` compiles through Rails, so bring dependencies and the database up to date after the rebase:

   ```sh
   pnpm install
   bundle install
   bin/rake db:migrate
   ```

3. Run the codemod and commit its output:

   ```sh
   node css_variable_migration/apply.mjs
   git add -A
   git commit -m "DEV: Apply the CSS variable mapping" -m "Generated by \`node css_variable_migration/apply.mjs\`."
   ```

4. Check the result:

   ```sh
   node css_variable_migration/check.mjs
   node css_variable_migration/compare.mjs
   bin/lint $(git diff --name-only --diff-filter=AM origin/main)
   ```

   Until the migration is complete, `discourse/css-variable-names` errors are expected. They are the todo list. Every other lint error needs a fix.

   The appearance style checks read core's variables from the compiled CSS and cache the list in `tmp/appearance_styles`. In development the cache does not change when the stylesheets change, so remove it before you run their specs:

   ```sh
   rm -rf tmp/appearance_styles
   bin/rspec spec/lib/appearance_styles spec/models/appearance_change_spec.rb spec/services/appearance_change
   ```

5. Read the compare report. Every difference must be one the mapping intends. If not, fix the mapping or the tools, and go back to step 1.
6. Regenerate the review tables and commit them on their own:

   ```sh
   node css_variable_migration/render-review-tables.mjs
   git add css_variable_migration/review
   git commit -m "DEV: Update the CSS variable migration review tables"
   ```

7. Push with `git push --force-with-lease`.

For a quick look between steps, you can run the codemod on its own output and commit that as another generated commit. The result is the same as a fresh run, and step 2 drops these commits again.

### Rules

- Fix the mapping or the tools, not the output. If lint fails on generated output, fix the codemod.
- Keep hand edits small, in their own commits, and on lines the codemod does not change. If a hand edit conflicts during the rebase, make it again on the new base.
- Add an entry only when a rule or a decision settles it. Leave the rest out and list it as a question.
- A `merge` changes what people see. Describe the value change in its `note`, and confirm it in the compare report.

## Reading the compare report

`compare.mjs` compiles both sides twice, which takes about a minute. It needs a clean working tree outside this folder, a migrated development database, and Chromium (`pnpm playwright-install`). It writes the full report to `tmp/css_variable_migration/report.json`.

- There is one section for each profile: Foundation and Horizon, light and dark.
- Each line is a change in computed value, with the number of declarations and up to three examples.
- `var old → new: before → after` is the computed value of a `:root` variable.
- `ignored as random` counts declarations in rules that differ between two compiles of the same side, such as rules that use Sass `random()`.
- `<set in a scope: --name>` means the variable is set only in some selector, so its value depends on where the element is. Check these by hand.
- `<invalid>` means the declaration has no value. Usually a `merge` whose new name has no definition.

It does not cover overrides on ancestor elements, values that JS sets at runtime, or RTL stylesheets.
