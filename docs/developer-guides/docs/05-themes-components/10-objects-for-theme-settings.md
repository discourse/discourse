---
title: Objects type for theme setting
short_title: Objects for theme settings
id: objects-for-theme-settings
---

We are introducing a new `type: objects` to [the supported types for theme settings](https://meta.discourse.org/t/add-settings-to-your-discourse-theme/82557#symbols-supported-types-2) which can be used to replace the existing `json_schema` type which we intend to deprecate soon.

### Defining an objects type theme setting

To create an objects type theme setting, first define a top level key just like any theme setting which will be used as the setting's name.

```yaml
links: ...
```

Next add the `type`, `default` and `schema` keywords to the setting.

```yaml
links:
  type: objects
  default: []
  schema: ...
```

`type: objects` indicates that this will be an objects type setting while the `default: []` annotation sets the default value of the setting to an empty array. Note that the default value can also be set to an array of objects which we will demonstrate once the `schema` has been defined.

To define the schema, first define the `name` of the schema like so:

```yaml
links:
  type: objects
  default: []
  schema:
    name: link
```

Next, we will add the `properties` keyword to the schema which will allow us to define and validate how each object should look like.

```yaml
links:
  type: objects
  default: []
  schema:
    name: link
    properties:
      name: ...
```

In the example above, we are stating that the `link` object has a `name` property. To define the type of data that is expected, each property needs to define the `type` keyword.

```yaml
links:
  type: objects
  default: []
  schema:
    name: link
    properties:
      name:
        type: string
```

The above schema definition states that the `link` object has a `name` property of type `string` which means that only string values will be accepted for the property. Currently the following types are supported:

- `string`: Value of property is stored as a string.
- `integer`: Value of property is stored as an integer.
- `float`: Value of property is stored as a float.
- `boolean`: Value of property is `true` or `false`.
- `upload`: Value of property is the attachment URL
- `enum`: Value of property must be one of the values defined in the `choices` keyword.
  ```yaml
  links:
    type: objects
    default: []
    schema:
      name: link
      properties:
        name:
          type: enum
          choices:
            - name 1
            - name 2
            - name 3
  ```
- `categories`: Value of property is an array of valid category ids.
- `groups`: Value of property is an array of valid group ids.
- `tags`: Value of property is an array of valid tag names.
- `icon`: Value of property is the name of a single icon from the Discourse icon set. Selected icons are automatically added to the sprite sheet, so they can be rendered without being registered separately.

With the schema defined, the default value of the setting can now be set by defining a array in yaml like so:

```yaml
links:
  type: objects
  default:
    - name: link 1
      title: link 1 title
    - name: link 2
      title: link 2 title
  schema:
    name: link
    properties:
      name:
        type: string
      title:
        type: string
```

#### Required properties

All properties defined are optional by default. To mark a property as required, simply annotate the property with `required: true. A property can also be marked as optional by annotating the property with `required: false`.

```yaml
links:
  type: objects
  default: []
  schema:
    name: link
    properties:
      name:
        type: string
        required: true
      title:
        type: string
        required: false
```

#### Custom Validations

For certain property types, there are built in support for custom validations which can be declared by annotating the property with the `validations` keyword.

```yaml
links:
  type: objects
  default: []
  schema:
    name: link
    properties:
      name:
        type: string
        required: true
        validations:
          min: 1
          max: 2048
          url: true
```

#### Validations for `string` types

- `min_length`: Minimum length of the property. Value of the keyword has to be an integer.
- `max_length`: Maximum length of the property Value of the keyword has to be an integer.
- `url`: Validates that the property is a valid URL. Value of the keyword can be `true/false`.

#### Validations for `integer` and `float` types

- `min`: Minimum value of the property. Value of the keyword has to be an integer.
- `max`: Maximum value of the property. Value of the keyword has to be an integer.

#### Validations for `tags`, `groups` and `categories` types

- `min`: Minimum number of records for the property. Value of the keyword has to be an integer.
- `max`: Maximum number of records for the property. Value of the keyword has to be an integer.

#### Resolving group membership

Object settings can resolve `type: groups` properties to a boolean for the current user. This is useful when theme code only needs to know whether the current user is in one of the configured groups, because `currentUser.groups` only includes groups that are visible to the user.

Add `resolve_group_membership: true` to the `groups` property:

```yaml
menu_sections:
  type: objects
  default:
    - name: section 1
      groups:
        - 1
        - 3
  schema:
    name: menu section
    properties:
      name:
        type: string
      groups:
        type: groups
        resolve_group_membership: true
```

The admin UI and stored setting value still use the original `groups` array. In the frontend runtime `settings` object, Discourse removes the group IDs from each object and adds a boolean with the same property name prefixed by `user_in_`:

```gjs
for (const section of settings.menu_sections) {
  if (section.user_in_groups) {
    // User is in at least one selected group for this section.
  }
}
```

This option is only valid on object schema properties with `type: groups`. It also works on nested object schemas and with automatic groups such as `logged_in_users` and `anonymous_users`.

#### Nested objects structure

An object can also have a property which contains an array of objects. In order to create a nested objects structure, a property can also be annotated with `type: objects` and the associated `schema` definition.

```yaml
sections:
  type: objects
  default:
    - name: section 1
      links:
        - name: link 1
          url: /some/url
        - name: link 2
          url: /some/other/url
  schema:
    name: section
    properties:
      name:
        type: string
        required: true
      links:
        type: objects
        schema:
          name: link
          properties:
            name:
              type: string
            url:
              type: string
```

### Setting description and localization

To add a description for the setting in the `en` locale, create a file `locales/en.yml` with the following format given the following objects type theme setting.

```yaml
sections:
  type: objects
  default:
    - name: section 1
      links:
        - name: link 1
          url: /some/url
        - name: link 2
          url: /some/other/url
  schema:
    name: section
    properties:
      name:
        type: string
        required: true
      links:
        type: objects
        schema:
          name: link
          properties:
            name:
              type: string
            url:
              type: string
```

```yaml
en:
  theme_metadata:
    settings:
      sections:
        description: This is a description for the sections theme setting
        schema:
          properties:
            name:
              label: Name
              description: The description for the property
            links:
              name:
                label: Name
                description: The description for the property
              url:
                label: URL
                description: The description for the property
```

### Translatable object text

Declare a required string property named `translation_key` and mark text properties with
`translatable: true` to expose them in **Site texts**. Core reads the defaults from the saved object settings and includes
them in the normal theme translation assets. Theme components need no backend code.

```yaml
links:
  type: objects
  default:
    - translation_key: guidelines
      label: Community guidelines
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
```

This exposes `js.theme_translations.<theme_id>.links.guidelines.label` with default text
“Community guidelines” and default text language `en`. The frontend continues to
use ``i18n(themePrefix(`links.${link.translation_key}.label`), { defaultValue: link.label })``
for each link in the setting.
The editor previews relative keys to pass to `themePrefix` and links to
Site texts filtered to the component. Save changes before managing translations.

Core scopes keys to the installed theme ID and object setting name. The default text language is `en`; optionally set
`translations: { default_locale: fr }` on the root schema to change it. No
`translations` block is otherwise needed. Nested schemas declare their own required
string `translation_key` property and mark their translatable properties;
ancestor object keys are included in each nested key. For example, a section with
key `getting_started` containing a link with key `guidelines` produces
`theme_translations.<theme_id>.resource_sections.getting_started.guidelines.label`
for the `resource_sections` setting.

Schemas with translatable fields, including their ancestor object schemas, must
declare `translation_key` with `type: string` and `required: true`. Schema validation
checks this even when the default object list is empty. The separate
`schema.identifier: label` option chooses the editor’s display label; it does not
select the translation identifier.

Use stable, manually assigned identifiers beginning with a lowercase letter and
containing only lowercase letters, digits, and underscores. Identifiers must be
unique among siblings. Reordering preserves translations. Renaming an identifier
creates new translation keys; duplicating an object requires a different key.
Separate component installations have independent namespaces.

Only string fields marked `translatable: true` participate. Unmarked fields and fields
with `translatable: false` are excluded. Empty optional fields retain their keys and
existing translations. Clearing default text does not delete translations; removing
the object or field declaration does.
Nested object identifiers cannot collide with translated fields on their ancestors;
the editor rejects these conflicts when saving.
Defaults include theme defaults and imported settings. Changing default text
marks translations outdated. Removing fields, objects, or the component removes
the associated theme translation overrides. Defaults remain in the object setting;
translations use the existing `ThemeTranslationOverride` model, just like locale-file
fields. There is no separate text registry.

Site texts shows the default text and its language alongside the editable
translation. Both object-editor fields and strings shipped in locale files use
`js.theme_translations.<theme_id>.<key>` in Site texts. Translations saved before
default tracking was available are flagged as outdated because their earlier
default text is unknown. Dismissing the warning records the current default without
changing the translation.

The setting name reserves a namespace within the theme. A locale file cannot also
define that setting's root key: saving the object setting or updating the theme
rejects the conflict. Text is delivered through the existing cached theme translation
assets only for the active theme and its components, including previews.
