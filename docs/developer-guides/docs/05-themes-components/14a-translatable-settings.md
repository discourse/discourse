---
title: Translatable theme settings
short_title: Translatable settings
id: translatable-settings
---

Text that admins enter in an [objects setting](10-objects-for-theme-settings.md), such as card titles or link labels, can be translated. Each translatable field becomes a theme translation, next to the strings from the theme's locale files. Admins translate and customize it in the admin UI, and your code reads it with `themePrefix` and `i18n`.

For locale files, reading translations in code, and managing translations in the admin UI, see [localizable strings](14-localizable-strings.md).

## Make a setting translatable

In the schema:

1. Declare a property named `translation_key` with `type: string` and `required: true`.
2. Add `translatable: true` to each string property that holds text.

```yaml
links:
  type: objects
  default:
    - translation_key: guidelines
      label: Community guidelines
      url: /guidelines
  schema:
    name: link
    identifier: label
    properties:
      translation_key:
        type: string
        required: true
      label:
        type: string
        translatable: true
      url:
        type: string
```

Core reads the text from the saved setting and adds it to the theme's translations. The component needs no backend code and no `locales` entry for these keys.

Only string fields with `translatable: true` get keys. Fields without the option, or with `translatable: false`, are left out. An empty optional field still gets its key, and any translations saved for it are kept.

## Generated keys

Each translatable field gets a key in the form `<setting>.<translation_key>.<field>`. The example above produces `links.guidelines.label`. In Site texts, it appears as `js.theme_translations.<theme_id>.links.guidelines.label`, with “Community guidelines” as its default text.

## Read the text in code

Build the key from the object's `translation_key`, and pass the saved value as `defaultValue`. Unlike locale-file strings, object text has no shipped fallback: `defaultValue` keeps it visible on Discourse versions without translatable settings, and when invalid keys leave the text out of the translations.

```gjs
import { i18n } from "discourse-i18n";
import { themePrefix } from "virtual:theme";

function linkLabel(link) {
  return i18n(themePrefix(`links.${link.translation_key}.label`), {
    defaultValue: link.label,
  });
}

<template>
  {{#each settings.links as |link|}}
    <a href={{link.url}}>{{linkLabel link}}</a>
  {{/each}}
</template>
```

`i18n()` treats `%{name}` as an interpolation placeholder, and admins can type `%{` in their text. To show such text as typed, read the translation without interpolation:

```js
import I18n from "discourse-i18n";
import { themePrefix } from "virtual:theme";

const text =
  I18n.findTranslationWithFallback(
    themePrefix(`links.${link.translation_key}.label`),
    {}
  ) ?? link.label;
```

## Nested objects

In nested schemas, each object schema that contains a translatable field, or contains a collection that does, needs its own required `translation_key` property. Keys include the `translation_key` of every ancestor object and the name of each nested collection:

```yaml
resource_sections:
  type: objects
  schema:
    name: section
    properties:
      translation_key:
        type: string
        required: true
      title:
        type: string
        translatable: true
      links:
        type: objects
        schema:
          name: link
          properties:
            translation_key:
              type: string
              required: true
            label:
              type: string
              translatable: true
```

A section with the key `getting_started` that contains a link with the key `guidelines` produces:

- `resource_sections.getting_started.title`
- `resource_sections.getting_started.links.guidelines.label`

Because collection names are part of the key, separate collections can reuse the same `translation_key` values.

Schema validation checks for the `translation_key` property even when the setting's default list is empty.

## Rules for keys and names

A `translation_key` value must:

- start with a lowercase letter
- contain only lowercase letters, digits and underscores
- be at most 80 characters long
- be unique within its collection

The same character rules apply to the setting name, translatable field names and nested collection names. A full key can be at most 400 bytes.

Treat `translation_key` values as stable IDs:

- Reordering objects keeps their translations.
- Renaming a key creates new translation keys. The old translations stay saved under the old key.
- A duplicated object needs a different key.

The schema's `identifier` option only sets the label shown for each object in the editor. It doesn't affect the translation key.

## Default text language

The default text is assumed to be English. To use another language, set `translations.default_locale` on the root schema. The value must be a locale that Discourse supports:

```yaml
links:
  type: objects
  schema:
    name: link
    translations:
      default_locale: fr
    properties:
      # ...
```

No other `translations` options exist.

## Reserved namespace

A translatable setting reserves its name as a namespace in the theme's translations. A locale file can't define that setting's root key. For example, if `links` is a translatable setting, `locales/en.yml` can't contain `en.links`. Saving the setting or updating the theme fails with an error until you rename the setting or move the locale-file keys.

## When keys are validated

- Saving in the object editor validates the keys right away.
- Theme updates validate the final keys after [settings migrations](11-migrate-settings.md) run. Invalid keys roll back the update.
- If saved keys are invalid anyway, for example after a schema change, Discourse leaves out all object-setting text for the theme when it builds translations. Locale-file translations keep working, and your `defaultValue` keeps the text visible.

## Manage translations in the admin UI

1. Open the setting in the object editor. Under **Translation keys**, the editor lists the keys for the selected object, relative to the theme, as you would pass them to `themePrefix`.
2. Save your changes.
3. Select **Manage translations** at the top of the editor to open Site texts filtered to the component.

The keys also appear in **Theme translations** on the component's page. The default text is the value saved in the object setting. Outdated translations, removed keys and automatic translation work as for locale-file strings; see [localizable strings](14-localizable-strings.md). On top of that:

- **Placeholders are checked.** A translation can only use `%{…}` placeholders that the default text contains.
- **Removing an object or a translatable field keeps its translations.** They're kept as deprecated through settings saves, migrations and theme updates, hidden from the admin UI, and used again if the same key comes back.
- **Clearing the default text** in the object editor doesn't delete translations.
- **The current schema wins.** If a schema change makes a kept key clash with the structure of a current key, the current schema's key is used. Both sets of translations stay saved in case the schema is rolled back.

## Update existing components

### Add keys to saved objects

When you add translatable fields to an existing component, objects that admins already saved have no `translation_key`. Add a [settings migration](11-migrate-settings.md) that assigns one. Otherwise the update fails validation and is rolled back.

```js
// filename: migrations/settings/0001-add-link-translation-keys.js
function addKeys(objects = []) {
  const used = new Set(objects.map((object) => object.translation_key));
  let next = 1;

  return objects.map((object) => {
    if (object.translation_key) {
      return object;
    }

    while (used.has(`link_${next}`)) {
      next++;
    }
    const translation_key = `link_${next}`;
    used.add(translation_key);

    return { ...object, translation_key };
  });
}

export default function migrate(settings) {
  if (settings.has("links")) {
    settings.set("links", addKeys(settings.get("links")));
  }
  return settings;
}
```

Nested collections need keys too, so extend the migration to every level that has translatable fields. Discourse validates the final keys after all migrations run.

### Pin older Discourse versions

Translatable settings need Discourse `2026.11.0-latest.2` or later, or the stable `2026.11.0` release. Pin older sites to the last commit that works without them in `.discourse-compatibility`:

```yaml
< 2026.11.0-latest.2: <commit>
```

See [version compatibility](../03-code-internals/06-version-compatibility.md) for how pins work, including `d-compat` branches.

## Example

For a complete component that uses both locale files and translatable settings, see [discourse-theme-component-i18n-test](https://github.com/nattsw/discourse-theme-component-i18n-test).
