---
title: Migrate Discourse theme settings
short_title: Migrate settings
id: migrate-settings
---

### Introduction

As of Discourse version 3.2.0.beta3, Discourse themes/components can leverage a migrations feature to evolve and alter their settings seamlessly. This feature ensures that updates to themes do not disrupt existing installations by handling changes to settings in a controlled manner.

### When to Use Migrations

Common scenarios where migrations are particularly useful:

- Changing the type of a setting (e.g., from a comma-separated string to a list).
- Renaming a setting.
- Modifying the structure or format of the data stored in a setting.

In these scenarios, if the setting type or name is changed in the `settings.yml` file without an accompanying migration, existing installations where the setting has been changed from the default value, they will lose the change they've made to the setting and potentially break when the theme is updated.

To ensure smooth transition when updating a theme setting, theme developers should ship a migration that instructs Discourse core how to migrate existing state that conforms to the old version of the `settings.yml` to the new version.

### Migration Files

Migrations are JavaScript files located in the `migrations/settings` directory of the theme, following the naming convention `XXXX-migration-name.js`. The `XXXX` prefix is a version number, starting from `0001` and incrementing sequentially, which dictates the order of execution.

The name should be a concise description of the migration's purpose, limited to alphanumeric characters, hyphens, and under 150 characters in length. Migrations are executed in ascending order based on the numerical value of their versions.

We recommend that you start with `0001` for the first migration and `0002` for the second migration etc. Note that if a migration's version is below 1000, then the version must be padded with leading zeros to make it 4 digits long since migration filename must start with 4 digits. For the same reason, it's not currently possible to have more than 9999 migrations in a theme, but we may change that in the future.

### Migration Function

Standard JavaScript [features](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference) such as classes, functions, arrays, maps etc. are all available for migrations to use. The only expectation from Discourse core is that each migration file must export a default function that serves as the entry point. This function receives a [`Map`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Map) object representing modified theme settings and returns a `Map` object reflecting the desired final state of all settings.

### Examples

Rename a theme setting:

```js
// filename: 0001-rename-old-setting.js

export default function migrate(settings) {
  if (settings.has("old_setting_name")) {
    settings.set("new_setting_name", settings.get("old_setting_name"));
    settings.delete("old_setting_name");
  }
  return settings;
}
```

This migration should be accompanied with the setting rename in the `settings.yml` file.

---

Convert a comma-separated string setting to a proper list:

```js
// filename: 0001-convert-string-setting-to-list.js

export default function migrate(settings) {
  if (settings.has("list_setting")) {
    const list = settings.get("list_setting").split(",");
    settings.set("list_setting", list.join("|"));
  }
  return settings;
}
```

Similar to the previous example, this migration should be accompanied with changing the setting type from `string` to `list` in the `settings.yml` file.

---

Rename a choice of an enum setting:

```js
// filename: 0001-rename-enum-choice.js

export default function migrate(settings) {
  if (settings.get("enum_setting") === "old_option") {
    settings.set("enum_setting", "new_option");
  }
  return settings;
}
```

---

Add a new item to a list setting:

```js
// filename: 0001-add-item-to-list.js

export default function migrate(settings) {
  if (settings.has("list_setting")) {
    const list = settings.get("list_setting").split("|");
    list.push("new_item");
    settings.set("list_setting", list.join("|"));
  } else {
    settings.set("list_setting", "new_item");
  }
  return settings;
}
```

### Execution and Error Handling

Migrations run automatically during theme installation and updates. They execute only once; if a migration is altered after successful execution, it will not run again. If a migration fails, the update process stops, and an error message of what went wrong is provided.

If a migration has a bug that results in corrupt state for a setting, then the correct way to fix the problem is to create a new migration that corrects the corrupt state instead of modifying the original migration.
