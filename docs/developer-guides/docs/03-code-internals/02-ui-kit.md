---
title: The UI kit of shared Discourse components, helpers, and modifiers
short_title: UI kit
id: ui-kit
---

<div data-theme-toc="true"> </div>

`ui-kit` is the layer of reusable, domain-free building blocks that core, plugins, and themes compose their interfaces from. It lives under `frontend/discourse/app/ui-kit/` and ships three kinds of primitive:

- **Components**: `d-button`, `d-modal`, `d-select`, `d-skeleton`, and so on.
- **Helpers** (`ui-kit/helpers/`): `d-icon`, `d-format-date`, `d-concat-class`, `d-user-avatar`, and so on.
- **Modifiers** (`ui-kit/modifiers/`): `d-trap-tab`, `d-on-resize`, `d-close-on-click-outside`, the drag-and-drop family, and so on.

Everything in it is prefixed with `d-` (`D` in PascalCase) and is considered public API for plugins and themes. This page explains when to reach for it, what is in it, and how to add to it. Each primitive's own JSDoc/TSDoc is the reference for its arguments; the [interactive styleguide](https://meta.discourse.org/styleguide) shows most of them rendered.

# Importing

Import from the `discourse/ui-kit` namespace:

```gjs
import { on } from "@ember/modifier";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";

<template>
  <label class="rename-form__label">{{dIcon "pencil"}} {{@label}}</label>
  <input
    class="rename-form__input"
    value={{@name}}
    {{dAutoFocus selectText=true}}
    {{on "input" @onInput}}
  />
  <DButton
    class="btn-primary"
    @action={{@onSave}}
    @label="save"
    @icon="check"
    @isLoading={{@isSaving}}
  />
</template>
```

`discourse/components/*`, `discourse/helpers/*`, and `discourse/modifiers/*` are still where domain-specific, non-shareable components live; only the reusable primitives were moved into the kit. The old paths of the moved ones (`discourse/components/d-button`, `discourse/helpers/d-icon`, and so on) still resolve through the shims in `frontend/discourse/app/ui-kit-shims.js`, so existing plugins keep working, but new code should import them from `discourse/ui-kit/...` directly.

Do not import anything from a `-internals` directory, wherever it appears (`discourse/ui-kit/-internals/...`, `discourse/lib/-internals/...`, and so on). Those modules are private implementation details of the primitives that wrap them: they are not part of the public API and can be renamed, reshaped, or removed without notice or a deprecation cycle. If a primitive does not expose what you need, extend the primitive rather than reaching past it.

# When to use it

Before writing a component, check whether the kit already covers the need:

1. Browse the `ui-kit/` directory (component, helper, and modifier names are descriptive) and the [styleguide](https://meta.discourse.org/styleguide) sections.
2. Prefer composing existing primitives over adding a variant. A `d-button` with `@icon` and a `class` attribute is better than a new button component; a `d-empty-state` with a custom `@ctaLabel` is better than a bespoke empty message.
3. If the need is a **form**, use [FormKit](22-form-kit.md) rather than assembling inputs by hand; FormKit's controls are themselves built on ui-kit primitives.
4. If the need is **anchored or hover-triggered UI** (tooltips, menus, popovers), use float-kit rather than positioning things yourself. It ships both components (`DTooltip`, `DMenu`, `DPopover`, `DToast`, and their headless variants, imported from `discourse/float-kit/components/...`) and the `tooltip`, `menu`, and `toasts` services for showing the same things programmatically. See [Menus](https://meta.discourse.org/styleguide/molecules/menus), [Tooltips](https://meta.discourse.org/styleguide/molecules/tooltips), and [Toasts](https://meta.discourse.org/styleguide/molecules/toasts).

Reach for a new component in `frontend/discourse/app/components/` when the thing you are building knows about Discourse domain concepts (a topic, a post, a category, a user's notification level). Add to `ui-kit/` only when the primitive is domain-free and useful to more than one consumer; see [Adding a primitive](#adding-a-primitive) below.

# What is in it

The groups below are a map, not an exhaustive list. Run `ls frontend/discourse/app/ui-kit` for the current inventory, and read the JSDoc/TSDoc of each file for its arguments and blocks.

## Actions

| Primitive                                              | Use it for                                                                          | Styleguide                                                                   |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `DButton`                                              | Every clickable action. Handles labels, icons, `@isLoading`, `@disabled`, and ARIA. | [Buttons](https://meta.discourse.org/styleguide/atoms/buttons)               |
| `DComboButton`                                         | A primary action paired with a dropdown of secondary actions.                       | [Combo button](https://meta.discourse.org/styleguide/molecules/combo-button) |
| `DCopyButton`                                          | Copy a value to the clipboard with feedback.                                        |                                                                              |
| `DPageActionButton`                                    | Actions in a page header.                                                           |                                                                              |
| `DBadgeButton`, `DToggleSwitch`, `DTogglePasswordMask` | Toggles and badge-shaped actions.                                                   |                                                                              |
| `DShortcut`                                            | Render a keyboard shortcut in the platform's notation.                              | [Shortcut](https://meta.discourse.org/styleguide/atoms/shortcut)             |

## Inputs

Form-level composition belongs to [FormKit](22-form-kit.md). These are the underlying controls, useful when a single control is needed outside a form.

| Primitive                                                                                                                                                                      | Use it for                                  | Styleguide                                                                       |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------- | -------------------------------------------------------------------------------- |
| `DSelect`                                                                                                                                                                      | A native `<select>` with Discourse styling. | [Dropdowns](https://meta.discourse.org/styleguide/atoms/dropdowns)               |
| `DMultiSelect`                                                                                                                                                                 | Choose several values with search.          | [Multi select](https://meta.discourse.org/styleguide/molecules/multi-select)     |
| `DTextField`, `DTextarea`, `DExpandingTextArea`, `DPasswordField`, `DRadioButton`                                                                                              | Single controls.                            | [Forms](https://meta.discourse.org/styleguide/atoms/forms)                       |
| `DDateInput`, `DDatePicker`, `DTimeInput`, `DDateTimeInput`, `DDateTimeInputRange`, `DFutureDateInput`, `DRelativeTimePicker`, `DTimeShortcutPicker`, `DCalendarDateTimeInput` | Dates, times, and ranges.                   | [Date/time inputs](https://meta.discourse.org/styleguide/atoms/date-time-inputs) |
| `DOtp`, `DSecondFactorInput`                                                                                                                                                   | One-time codes.                             | [OTP](https://meta.discourse.org/styleguide/atoms/otp)                           |
| `DFilterInput`, `DFilterControls`                                                                                                                                              | Filter a list.                              |                                                                                  |
| `DColorPicker`, `DIconGridPicker`, `DPickFilesButton`                                                                                                                          | Specialised pickers.                        |                                                                                  |
| `DCharCounter`, `DInputTip`, `DPopupInputTip`                                                                                                                                  | Feedback attached to an input.              | [Char counter](https://meta.discourse.org/styleguide/molecules/char-counter)     |
| `DAccessControl`, `DAccessControlField`                                                                                                                                        | Edit access control lists.                  |                                                                                  |
| `DEditor`                                                                                                                                                                      | The composer's markdown editor.             |                                                                                  |

## Page chrome and layout

| Primitive                                               | Use it for                                                                   | Styleguide                                                                       |
| ------------------------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `DPageHeader`, `DPageSubheader`                         | Titles, breadcrumbs, tabs, and actions of an admin or settings page.         |                                                                                  |
| `DBreadcrumbsContainer`, `DBreadcrumbsItem`             | Breadcrumb trails registered from routes.                                    | [Breadcrumbs](https://meta.discourse.org/styleguide/molecules/bread-crumbs)      |
| `DNavItem`, `DNavigationItem`, `DHorizontalOverflowNav` | Navigation bars, including ones that scroll horizontally when they overflow. | [Navigation bar](https://meta.discourse.org/styleguide/molecules/navigation-bar) |
| `DResponsiveTable`, `DTableHeaderToggle`                | Tables that stay usable on narrow viewports, with sortable column headers.   |                                                                                  |
| `DStatTiles`                                            | Rows of headline numbers.                                                    |                                                                                  |
| `DTapTileGrid`, `DTapTile`                              | Grids of tappable choices.                                                   |                                                                                  |
| `DPostAccordion`, `DPostAccordionItem`                  | Collapsible sections.                                                        |                                                                                  |
| `DResizeHandles`, `DResizeSeparator`                    | User-resizable regions.                                                      | [Drag and drop](https://meta.discourse.org/styleguide/molecules/drag-and-drop)   |
| `DSaveControls`                                         | The save button and "saved" feedback of a settings form.                     |                                                                                  |

## Loading, empty, and feedback states

| Primitive                                                  | Use it for                                                                                                                                                                                                                                                                                                          |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DSkeleton`                                                | Placeholder shapes while content loads. Prefer a skeleton that mirrors the eventual layout over a spinner.                                                                                                                                                                                                          |
| `DConditionalLoadingSpinner`, `DConditionalLoadingSection` | Show a spinner (`@condition`) or a dimmed, labelled section (`@isLoading`) in place of content while it loads.                                                                                                                                                                                                      |
| `DAsyncContent`                                            | Render content that is loaded asynchronously. Give it a promise, a `TrackedAsyncData`, or a function that fetches the data via `@asyncData`, and fill the `loading`, `content`, `empty`, and `error` blocks; it reloads when `@context` changes, so there is no need to hand-roll loading flags and error handling. |
| `DEmptyState`                                              | A titled, illustrated "nothing here" message with an optional call to action. See [Empty state](https://meta.discourse.org/styleguide/molecules/empty-state).                                                                                                                                                       |
| `DFlashMessage`                                            | Inline success, error, and warning banners.                                                                                                                                                                                                                                                                         |
| `DLoadMore`                                                | Infinite scrolling.                                                                                                                                                                                                                                                                                                 |

## Content rendering

| Primitive                                | Use it for                                                                    |
| ---------------------------------------- | ----------------------------------------------------------------------------- |
| `DCookText`                              | Render raw markdown as cooked HTML.                                           |
| `DDecoratedHtml`                         | Render HTML and apply the decorators registered through the plugin API to it. |
| `DHighlightedCode`                       | Syntax-highlighted code.                                                      |
| `DHtmlWithLinks`, `DCustomHtml`          | Trusted HTML fragments.                                                       |
| `DInterpolatedTranslation`, `DCountI18n` | Translations whose placeholders are components or counts.                     |
| `DRelativeDate`                          | A live-updating relative timestamp.                                           |
| `DCdnImg`, `DLightDarkImg`               | Images that follow the CDN and the colour scheme.                             |

## Users, avatars, and categories

`DUserAvatar`, `DUserAvatarFlair`, `DAvatarFlair`, `DUserLink`, `DUserInfo`, `DUserStat`, `DUserStatusMessage`, `DSmallUserList`, `DBadgeCard`, plus the `d-avatar`, `d-bound-avatar`, `d-category-badge`, `d-category-link`, `d-discourse-tag`, and `d-topic-link` helpers. See [Categories](https://meta.discourse.org/styleguide/molecules/categories).

## Overlays

`DModal` and `DModalCancel` render modals; see the [DModal API](12-dmodal-api.md). `DDropdownMenu` renders the content of a menu opened through the `menu` service. `DConditionalInElement` renders its block into `@element` elsewhere in the DOM, or in place when `@inline` is set.

## Helpers

`d-icon`, `d-icon-or-image`, `d-emoji`, `d-replace-emoji`, `d-format-date`, `d-format-duration`, `d-number`, `d-age-with-tooltip`, `d-dasherize`, `d-dir-span`, `d-unique-id`, `d-base-path`, `d-loading-spinner`, `d-element` (a typed wrapper for a chosen tag, so attributes and modifiers are checked against the right element), and `d-concat-class` (join class names, dropping falsy ones).

## Modifiers

| Modifier                                                                          | Use it for                                                                               |
| --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `d-auto-focus`                                                                    | Focus an element when it renders.                                                        |
| `d-trap-tab`                                                                      | Keep keyboard focus inside a dialog.                                                     |
| `d-tab-to-sibling`                                                                | Make Tab move focus between sibling elements.                                            |
| `d-close-on-click-outside`                                                        | Dismiss an overlay when the user clicks elsewhere.                                       |
| `d-on-resize`, `d-observe-intersection`, `d-scroll-into-view`                     | React to layout and visibility.                                                          |
| `d-autocomplete`                                                                  | Attach an autocomplete popup to a text input.                                            |
| `d-swipe`, `d-pointer-drag`, `d-resize-edge`, `d-drag-dwell`, `d-drag-and-drop-*` | Gestures. See [Drag, resize, and gesture primitives](30-drag-and-gesture-primitives.md). |

# Adding a primitive

A primitive belongs in `ui-kit/` when it is **domain-free** (it does not know what a topic or a post is) and either already has two consumers or is an obvious platform capability (a focus trap, a skeleton, a keyboard-shortcut renderer). Otherwise keep it next to its single consumer in `app/components/`.

When you add one:

- **Name it `d-<name>`** and put it at `frontend/discourse/app/ui-kit/d-<name>.gts` (or `helpers/d-<name>.js`, `modifiers/d-<name>.ts`). See [Splitting a large primitive](#splitting-a-large-primitive) when one file is not enough.
- **Write it in TypeScript with a `Signature`** (`Args`, `Blocks`, `Element`) and TSDoc on the class and every public argument. The kit is platform-level code, so accurate types matter more here than elsewhere; `d-shortcut.gts`, `d-skeleton.gts`, `d-resize-separator.gts`, and `modifiers/d-drag-dwell.ts` are good models. See [Types](27-types.md).
- **Forward `...attributes`** to the element consumers will want to target, and declare that element in the `Element` type so the type checker allows attributes and modifiers on it.
- **Use BEM class names rooted at the component name** (older primitives predate this rule; new ones must follow it), `d-<name>`, `d-<name>__part`, `d-<name>--modifier`, and put the stylesheet at `app/assets/stylesheets/common/components/d-<name>.scss`, registered in `_index.scss`. Use colour and spacing tokens only; no hard-coded colours. See [CSS guidelines](26-css-guidelines-bem.md).
- **Prefer named blocks over boolean arguments** when the consumer supplies content, and yield a small API object when the consumer needs to call back into the component.
- **Take strings already translated.** A primitive receives display text as a plain `string` argument (`@label`, `@title`) that the consumer has already passed through `i18n()`; it never resolves translation keys itself. The kit does not know which locale file a consumer's key lives in, and a key-taking argument forces a parallel `@translatedX` argument for every string. `d-resize-separator.gts` documents its `label` this way. `DButton`'s `@label`-as-key plus `@translatedLabel` pair predates this rule; do not copy it.
- **Do not mention plugins or specific libraries** in its docs or comments; describe the mechanism instead.

## Splitting a large primitive

A primitive whose behaviour outgrows one file keeps **one public entry module** and moves everything else into a sibling directory named after it. Consumers import only the entry; nothing outside the directory imports from `-internals/`.

```text
ui-kit/
  d-widget.gts                     # the public component; the only import path
  d-widget/
    README.md                      # what each collaborator owns and why
    types.ts                       # every interface, incl. the ones the entry re-exports
    -internals/
      constants.ts                 # values shared by more than one collaborator
      engine/                      # the headless logic: state, algebra, resolution
      coordinators/                # non-rendering classes the component constructs once
      parts/                       # rendering subcomponents that add no wrapper DOM
      modifiers/                   # element-attached behaviour private to this primitive
  modifiers/
    d-gesture.ts                   # a modifier entry follows the same shape
    d-gesture/
      types.ts
      keyboard.ts, strategies/, …
```

Use the buckets that apply; a two-file split needs only `types.ts`. What goes where:

- **`types.ts`** holds every interface, including the ones the entry re-exports as public API. It is the documentation home for the argument reference, so the entry's `Args` block can point at it.
- **`-internals/engine/`** is the headless layer: state, filtering, the move or selection algebra, value resolution. It has no DOM and no component reference, which is what makes it unit-testable on its own.
- **`-internals/coordinators/`** are plain classes the component constructs once and configures downward with thunks (`() => this.args.x`); they never hold a reference back to the component. Announcers, menu coordinators, and load-feedback timers live here.
- **`-internals/parts/`** are the rendering subcomponents. They receive the stable helper objects (the engine, a presenter) plus per-slot inputs, and add no wrapper DOM of their own.
- **`-internals/constants.ts`** exists so two collaborators that must agree on a value (a menu identifier, a selector) import it rather than restating it.
- **`README.md`** explains the split: what each collaborator owns, the invariants that cross files, and the design decisions a future reader would otherwise undo.

Something shared by several primitives, rather than private to one, goes in `ui-kit/-internals/<topic>/` (cursor navigation, for example), still off-limits to consumers.

# Blast radius and backward compatibility

The kit exists to build all of Discourse's UI: core, every plugin, and every theme render through it. A change here therefore has a far larger blast radius than a change to a single feature, and code you cannot see (third-party plugins and themes) depends on the public surface exactly as it is today.

Before changing anything public facing (an argument, a block, a yielded API object, a class name, DOM structure, or a helper's or modifier's signature), work out:

- **Who can be relying on it.** Search core, the in-repo plugins, and the wider plugin and theme ecosystem for the argument or class name; assume any exported name or documented argument has consumers you cannot see.
- **Whether the change is backward compatible.** Adding an optional argument or block is; renaming, removing, changing a default, changing the element `...attributes` land on, or restructuring the DOM that stylesheets target is not.
- **Whether a deprecation cycle is required.** A breaking change to a public surface ships behind a deprecation first: keep the old path working, emit a deprecation with an id and a `since` version, document the replacement, and remove it only after the cycle. Do not skip this because the old behaviour looks unused.

For anything **new** (a feature, an argument, a component, a modifier), the bar is exhaustive testing rather than a happy-path check: every argument and block, keyboard and pointer input, the states a consumer can put it in, error paths, and the accessibility contract. A primitive that ships with a gap ships that gap to every surface that adopts it.

# Testing a primitive

- **Rendering tests** go in `frontend/discourse/tests/integration/ui-kit/d-<name>-test.gjs`, next to the other 40-odd kit tests. Assert through the public API and observable DOM, not internal state. Cover every argument and block, every input method the primitive answers to, and the states it can be driven into; the drag-and-drop family in `frontend/discourse/tests/integration/ui-kit/modifiers/` shows the expected depth (modifier tests live in that `modifiers/` subdirectory, helper tests in `helpers/`).
- **Type tests** for `.gts` primitives go in `frontend/discourse/type-tests/ui-kit/d-<name>-test.gts`, using `@glint-expect-error` (and `expect-type` where a value type matters) to pin down both what compiles and what must not.
- **Module-level state** (registries, callbacks) needs a reset export that `frontend/discourse/tests/helpers/qunit-helpers.js` calls from `testCleanup()`, as `d-decorated-html` and `d-editor` do.
- **System specs** for behaviour a component test cannot reach (real drag negotiation, portaled overlays, scroll containers) go in the styleguide plugin when the primitive has no core consumer to exercise it.

# Styleguide section

Every primitive is browsable at `/styleguide/<category>/<section>`, and the section is part of the deliverable, not an afterthought. Add or extend one under `plugins/styleguide/assets/javascripts/discourse/components/sections/` and register it in `plugins/styleguide/assets/javascripts/discourse/lib/styleguide.js`.

A section should be designed, with multiple examples that each isolate one capability. `sections/molecules/drag-and-drop.gjs` is the model: it groups its examples with `StyleguideGroups`, and each `Example` carries a title, a `@kind`, a description of what the example demonstrates, a `@tryThis` prompt telling the reader what to do, an optional `@note` on the subtlety it exposes, and the source via `@code` so the reader can copy it. Aim for one example per argument or behaviour worth understanding (types, positions, disabled state, nesting, custom preview, and so on), rather than a single kitchen-sink demo.

# Related guides

- [FormKit](22-form-kit.md) for forms.
- [DModal API](12-dmodal-api.md) for modals.
- [CSS guidelines](26-css-guidelines-bem.md) for BEM and tokens.
- [Designing for devices](28-designing-for-devices.md) and [responsive widths](29-designing-for-responsive-widths.md).
- [Drag, resize, and gesture primitives](30-drag-and-gesture-primitives.md) for the modifiers that handle input.
- [Types](27-types.md) for the Glint and TypeScript conventions the kit follows.
