---
title: Objects type for theme settings
short_title: Objects for theme settings
id: objects-for-theme-settings
---

The `objects` type lets a [theme setting](09-theme-settings.md) hold a list of objects with a structure you define, such as links with a name and URL, or sections that each contain links. Admins edit the list in an object editor, and Discourse validates each object against your schema. It replaces the older `json_schema` type.

## Define an objects setting

Add `type: objects`, a `default` and a `schema` to the setting:

```yaml
links:
  type: objects
  default: []
  schema:
    name: link
    identifier: name
    properties:
      name:
        type: string
      url:
        type: string
```

- `default` is the setting's initial value: an empty list, or a list of objects that match the schema.
- `schema.name` names a single object. The editor labels objects with it, for example “link 1”.
- `schema.identifier` is optional. It names a property whose value labels each object in the editor instead, such as the link's name.
- `schema.properties` lists the properties each object can have. Every property needs a `type`.

## Property types

- `string`: Text. Set `textarea: true` to use an expanding text area:

  ```yaml
  description:
    type: string
    textarea: true
    validations:
      max_length: 500
  ```

- `integer`: A whole number.
- `float`: A number that can have decimals.
- `boolean`: `true` or `false`.
- `enum`: One of the values listed in `choices`:

  ```yaml
  size:
    type: enum
    choices:
      - small
      - medium
      - large
  ```

- `datetime`: A date and time in ISO 8601 format with a timezone, such as `2026-01-01T10:00:00Z`.
- `upload`: An uploaded file. Theme code receives its URL.
- `icon`: The name of an icon from the Discourse icon set. Selected icons are added to the sprite sheet automatically, so you don't need to register them.
- `categories`: A list of category IDs.
- `groups`: A list of group IDs.
- `tags`: A list of tag names.
- `objects`: A nested list of objects. See “Nested objects” below.

For `tags`, the settings API also accepts tag IDs and stores them as names. In theme code, each object with a `tags` property also gets a `tag_objects` array with the `id` and `name` of each selected tag the visitor can see, so you can target tags by ID, for example in CSS.

## Default value

Once the schema is defined, `default` can hold objects that match it:

```yaml
links:
  type: objects
  default:
    - name: Guidelines
      url: /guidelines
    - name: FAQ
      url: /faq
  schema:
    name: link
    identifier: name
    properties:
      name:
        type: string
      url:
        type: string
```

## Required properties

Properties are optional by default. Add `required: true` to make one required:

```yaml
properties:
  name:
    type: string
    required: true
  url:
    type: string
```

Blank `string`, `datetime` and `icon` values and empty `categories`, `groups` and `tags` lists count as missing: required properties reject them, and optional properties skip their validations. `false` counts as set.

## Validations

Some types accept a `validations` key:

```yaml
properties:
  url:
    type: string
    required: true
    validations:
      max_length: 2048
      url: true
```

For `string` properties:

- `min_length`: The minimum number of characters.
- `max_length`: The maximum number of characters.
- `url`: When `true`, the value must be a URL. Absolute `http`, `https` and `ftp` URLs, `mailto:` links, paths starting with `/` and `#` anchors are accepted.

For `integer` and `float` properties:

- `min`: The minimum value.
- `max`: The maximum value.

For `tags`, `groups` and `categories` properties:

- `min`: The minimum number of selected items.
- `max`: The maximum number of selected items.

## Resolving group membership

Theme code often only needs to know whether the current user is in one of the selected groups. `currentUser.groups` can't answer that reliably, because it only includes groups the user can see. Add `resolve_group_membership: true` to a `groups` property to resolve it on the server:

```yaml
menu_sections:
  type: objects
  default:
    - name: Staff tools
      groups:
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

The admin UI and the stored value keep the `groups` list. In the frontend `settings` object, Discourse replaces the group IDs in each object with a boolean named after the property, prefixed with `user_in_`:

```gjs
for (const section of settings.menu_sections) {
  if (section.user_in_groups) {
    // The user is in at least one of the selected groups.
  }
}
```

Within object schemas, the option only works on `type: groups` properties. It also works in nested objects and with automatic groups such as `logged_in_users` and `anonymous_users`.

## Nested objects

A property with `type: objects` and its own `schema` holds a nested list:

```yaml
sections:
  type: objects
  default:
    - name: Getting started
      links:
        - name: Guidelines
          url: /guidelines
        - name: FAQ
          url: /faq
  schema:
    name: section
    identifier: name
    properties:
      name:
        type: string
        required: true
      links:
        type: objects
        schema:
          name: link
          identifier: name
          properties:
            name:
              type: string
            url:
              type: string
```

## Setting description and property labels

Describe the setting and label its properties in the theme's `locales/en.yml`. For the `sections` setting above:

```yaml
en:
  theme_metadata:
    settings:
      sections:
        description: Sections shown in the sidebar
        schema:
          properties:
            name:
              label: Name
              description: The section's heading
            links:
              name:
                label: Name
                description: The link text
              url:
                label: URL
                description: Where the link goes
```

Labels for a nested property go under the name of its collection, here `links`.

## Translatable text

To let admins translate text they enter in the object editor, declare a required string `translation_key` property and add `translatable: true` to each text property:

```yaml
links:
  type: objects
  default:
    - translation_key: guidelines
      label: Community guidelines
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

Each translatable field becomes a theme translation, such as `links.guidelines.label`, that admins manage in the admin UI. For key rules, nested objects, reading the text in code and updating existing components, see [translatable settings](14a-translatable-settings.md).
