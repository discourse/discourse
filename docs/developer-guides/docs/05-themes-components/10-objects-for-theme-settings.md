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

- `string`: Value of property is stored as a string. Set `textarea: true` to use an expanding text area:

  ```yaml
  description:
    type: string
    textarea: true
    validations:
      max_length: 500
  ```

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

When updating an objects theme setting through the API, `tags` arrays can contain source tag names, integer tag IDs, or both. IDs are resolved to source names before validation and storage. Themes still receive arrays of source names. Numeric strings are treated as names, not IDs, and defaults must use names.

The default frontend tag renderer includes `data-tag-id` for tag objects with an ID, or for tag names rendered with the `tagId` option. The existing `data-tag-name` attribute is unchanged. The ID stays the same across locales even when the displayed name changes. Name-only rendering calls without an ID omit `data-tag-id`.

Objects with direct `tags` properties automatically receive an accompanying `tag_objects` array in the frontend settings:

```js
{
  tags: ["support"],
  tag_objects: [
    { id: 42, name: "support" }
  ]
}
```

The existing tag-name arrays are unchanged. Each companion object contains the tag ID and the exact original source-name string from the setting, including its casing. It does not substitute a translated display name. Components can use the IDs to reference the selected tags, for example when targeting `data-tag-id` in CSS. Core does not render the companion array as UI or add an admin setting for it.

The companion combines the object's direct `tags` selections in their original order, preserving repeated selections. Nested objects get their own companions. Only tags visible to the visitor are included; missing, deleted or hidden selections are omitted. The companion is still present as `[]` when no tags resolve. Do not assume its indexes match the original string array.

No opt-in or extra browser API request is needed. An author-defined schema property named `tag_objects` takes precedence: core preserves that field and does not generate a companion at that level. Declare any existing custom field with this name; undeclared `tag_objects` values are treated as generated metadata and stripped. Objects without direct `tags` properties and legacy top-level tag-list settings are unchanged.

The companion is generated only for the frontend page data. Stored settings and admin editing values keep their existing shape; generated metadata submitted back through the settings API is discarded. Components supporting contexts or older Discourse versions without this data can check `Array.isArray(style.tag_objects)` and fall back to their existing name-based behavior when it is unavailable.

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

All properties defined are optional by default. To mark a property as required, simply annotate the property with `required: true`. A property can also be marked as optional by annotating the property with `required: false`.

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

Blank `string`, `datetime` and `icon` values and empty `categories`, `groups` and `tags` lists count as missing: required properties reject them and optional properties skip their validations. `false` counts as set.

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
          min_length: 1
          max_length: 2048
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
ancestor object keys and collection property names are included in each nested key. For example, a section with
key `getting_started` containing a link with key `guidelines` produces
`theme_translations.<theme_id>.resource_sections.getting_started.links.guidelines.label`
for the `resource_sections` setting.

Schemas with translatable fields, including their ancestor object schemas, must
declare `translation_key` with `type: string` and `required: true`. Schema validation
checks this even when the default object list is empty. The separate
`schema.identifier: label` option chooses the editor’s display label; it does not
select the translation identifier.

Use stable, manually assigned identifiers beginning with a lowercase letter and
containing only lowercase letters, digits, and underscores. Identifiers must be
at most 80 characters long and unique within each collection. Translatable setting names,
field names, and nested collection names also start with a lowercase letter and contain
only lowercase letters, digits, and underscores. Reordering preserves translations. Renaming an identifier
creates new translation keys; duplicating an object requires a different key.
Separate component installations have independent namespaces.

When adding translatable fields to an existing component, provide a settings migration
that adds valid `translation_key` values to customized objects. Component updates
validate the final object translation keys and rebuild their translations after
settings migrations finish. Invalid final keys roll back the update. Ordinary
object-editor saves validate immediately. If saved object identifiers are invalid,
read paths omit object defaults so locale-file translations and assets remain available;
saving object settings and applying migrations still validate strictly.

Only string fields marked `translatable: true` participate. Unmarked fields and fields
with `translatable: false` are excluded. Empty optional fields retain their keys and
existing translations. Clearing default text does not delete translations.
Nested collections include their property name in the key, so separate collections
can reuse the same object identifiers.
Defaults include theme defaults and imported settings. Changing default text
marks translations outdated. Defaults remain in the object setting; translations
use the existing `ThemeTranslationOverride` model, just like locale-file fields.
There is no separate text registry.

Removing an object, a translatable field declaration, or a locale-file key does not
delete its saved translation overrides. Overrides without a current source have a
`deprecated` status and are retained through settings saves, migrations, and component
updates. Restoring the same translation key reuses the saved customization, including
after a component rollback. This preserves existing locale-file translation behavior
for components that do not opt into object translations. Removed keys are not listed
in Site texts until their source declarations return.
If schema changes make a retained key conflict with a current key's nested structure,
the current declaration determines the runtime shape. Both saved overrides remain
available for restoration if the schema is rolled back.

Explicitly reverting a translation still removes that override and restores the
shipped default for the selected locale. Deleting the component removes all of its
translation overrides.

Site texts shows the default text and its language alongside the editable
translation. Both object-editor fields and strings shipped in locale files use
`js.theme_translations.<theme_id>.<key>` in Site texts. Translations saved before
default tracking was available have an unknown baseline and are excluded from the
outdated filter. Acknowledging the current default establishes a baseline without
changing the translation. Object-field interpolation placeholders are checked against
the declared source text, not custom source overrides. Plural forms can use placeholders
declared by their sibling `other` form. Locale-file overrides retain their existing
unrestricted placeholder behavior because the component can supply runtime arguments
that its shipped text does not use. Site texts does not mark these arguments invalid.

Default tracking uses the saved object field or the shipped English text, falling back
to the selected locale's shipped text when no English key exists. Source-locale overrides
do not replace this baseline. The default's language is shown explicitly; reverting a
locale-file override still restores the text shipped for the selected locale.

The setting name reserves a namespace within the theme. A locale file cannot also
define that setting's root key: saving the object setting or updating the theme
rejects the conflict. Text is delivered through the existing cached theme translation
assets only for the active theme and its components, including previews.
