# CSS variable migration

These tools rename core's CSS variables in one change. People review the mapping and the tools. The codemod makes the code changes, and the checks review the result. Nobody edits the generated changes by hand.

This folder is temporary. Remove it when the migration is complete.

The naming scheme, its word lists and the full draft mapping are in the [CSS variables repo](https://github.com/nolosb/discourse-CSS-variables).

## Files

| File                        | Purpose                                                                                        |
| --------------------------- | ---------------------------------------------------------------------------------------------- |
| `mapping.json`              | Each old variable and its new name, grouped by type                                            |
| `definitions.json`          | Values for new variables, or new values for existing ones                                      |
| `apply.mjs`                 | The codemod. It applies both files to core, bundled plugins and themes                         |
| `check.mjs`                 | Confirms that the working tree matches the mapping                                             |
| `compile.rb`, `compare.mjs` | Compile the stylesheets on `main` and on the branch, and list the computed values that differ |
| `mapping.mjs`               | Code that the scripts share                                                                    |

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

An entry is the new name, or an object with the new name in `to` and a `note` for reviewers.

- `rename`: the new name keeps the old value, so nothing looks different.
- `merge`: the old variable takes the value of its new name. The codemod removes the old definition from `:root` in core, so another entry must give the new name its value: a `rename` into the same name, or an entry in `definitions.json`.
- `rgb`: an `-rgb` twin, such as `--primary-rgb`, with its color variable as the new name. The codemod rewrites reads to `color-mix()`. The twin stays defined for themes.

The draft mapping has other types (`split`, `drop`, `base`, `open`). The codemod does not support them yet, and stops if it finds one.

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

- It replaces every old name in stylesheets, JS, templates, Ruby, SVG and Markdown.
- It writes `app/assets/stylesheets/variable-renames.json`. The renamer uses it to keep old names working for themes and plugins, and the `discourse/no-renamed-variables` lint rule uses it to find them.
- It writes `app/assets/stylesheets/variable-rgb-twins.json` for the `discourse/no-deprecated-rgb-variables` lint rule.
- It removes declarations that refer to themselves, and the earlier declaration when a rule sets a variable twice. Both happen when two old names share one new name.
- It rewraps lines with Prettier in files that were formatted before.

The codemod cannot see names that JS builds at runtime, or that SCSS builds with `#{}`. `check.mjs` lists the SCSS ones and the `-rgb` reads it could not rewrite. These need a hand edit.

## Branch layout

The branch has two kinds of commits:

- **Written commits**: framework changes, tools, mapping entries and hand edits.
- **Generated commits**: `DEV: Apply the CSS variable mapping`. These hold only the output of `apply.mjs`. Never change them by hand.

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

5. Read the compare report. Every difference must be one the mapping intends. If not, fix the mapping or the tools, and go back to step 1.
6. Push with `git push --force-with-lease`.

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
