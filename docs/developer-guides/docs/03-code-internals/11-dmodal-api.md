---
title: Using the DModal API to render Modal windows (aka popups/dialogs) in Discourse
short_title: DModal API
id: dmodal-api
---

Discourse 3.1.0.beta6 ships with a brand new `<DModal>` component-based API.

> :information_source: This supersedes the old controller-based API, which is now deprecated. If you have existing modals using the old APIs, check out the migration guide [here](https://meta.discourse.org/t/converting-modals-from-legacy-controllers-to-new-dmodal-component-api/268057).

## Rendering a Modal

Modals are rendered by including the `<DModal>` component in a handlebars template. If you don't already have a suitable template, check out https://meta.discourse.org/t/using-plugin-outlet-connectors-from-a-theme-or-plugin/32727.

A simple modal would look something like this:

```hbs
<DButton
  @translatedLabel="Show Modal"
  @action={{fn (mut this.modalIsVisible) true}}
/>

{{#if this.modalIsVisible}}
  <DModal @title="My Modal" @closeModal={{fn (mut this.modalIsVisible) false}}>
    Hello world, this is some content in a modal
  </DModal>
{{/if}}
```

> :information_source: The [`mut` helper](https://api.emberjs.com/ember/release/classes/Ember.Templates.helpers/methods/mut) is used here as a hbs-only way to set a value. You could also set `modalIsVisible` using any other standard Ember method.

This example will create a simple Modal like this:

![SCR-20230614-mxwd|690x255, 30%](/assets/dmodal-api-1.png)

## Wrapping in a component

Before introducing any more complexity, it's usually best to wrap up your new Modal in its own Component definition. Let's move the `<DModal>` stuff inside a new `<MyModal />` component

```gjs
// components/my-modal.gjs
<template>
  <DModal @title="My Modal" @closeModal={{@closeModal}}>
    Hello world, this is some content in a modal
  </DModal>
</template>
```

Upgrading this `.gjs` file to a class-based component will allow you to introduce more complex logic and state.

To make use of the new component, update the call site to reference it, making sure to pass in a `@closeModal` argument.

```hbs
<DButton
  @translatedLabel="Show Modal"
  @action={{fn (mut this.modalIsVisible) true}}
/>

{{#if this.modalIsVisible}}
  <MyModal @closeModal={{fn (mut this.modalIsVisible) false}} />
{{/if}}
```

## Adding a footer

Many modals have some kind of call-to-action. In Discourse these tend to be located at the bottom of the modal. To make this possible, `DModal` has a number of 'named blocks' which can have content rendered inside them. Here's the example updated to include two buttons in the footer, one of which is our standard `DModalCancel` button

```hbs
<DModal @title="My Modal" @closeModal={{@closeModal}}>
  <:body>
    Hello world, this is some content in a modal
  </:body>
  <:footer>
    <DButton class="btn-primary" @translatedLabel="Submit" />
    <DModalCancel @close={{@closeModal}} />
  </:footer>
</DModal>
```

![SCR-20230614-njze|690x388, 30%](/assets/dmodal-api-2.png)

## Rendering a modal from a non-hbs context

Ideally, `<DModal>` instances should be rendered from within an Ember template using the declarative technique demonstrated above. If that's not feasible for your use case, it can be done by injecting the `modal` service and calling `modal.show()`.

Make sure you've wrapped up your modal in its own component as described above. Then, trigger the modal by passing a reference of your component class to `showModal`:

```js
import MyModal from "discourse/components/my-modal";

// (inject the modal service in the relevant place)

// Add this call whenever you want to open the modal.
// A `@closeModal` argument will be passed to your component automatically.
this.modal.show(MyModal);

// Optionally, pass a '`model`' parameter. Passed as `@model` to your component.
// This can include data, and also actions/callbacks for your Modal to use.
this.modal.show(MyModal, {
  model: { topic: this.topic, someAction: this.someAction },
});

// `modal.show()` returns a promise, so you can wait for it to be closed
// It will resolve with the data passed to the `@closeModal` action
const result = await this.modal.show(MyModal);
```

## More customizability!

`<DModal>` has a number of named blocks and arguments.

### Arguments

| Arg                          | Purpose                                                                                                       |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `@closeModal`                | Required for dismiss UI to appear at all.                                                                     |
| `@title`                     | Renders `<h1 id="discourse-modal-title">`; wires `aria-labelledby`.                                           |
| `@subtitle`                  | Small text below the title.                                                                                   |
| `@flash` / `@flashType`      | Inline alert at top of modal (`DFlashMessage`).                                                               |
| `@hideHeader`, `@hideFooter` | Hide whole regions.                                                                                           |
| `@headerClass`, `@bodyClass` | Extra class on header/body wrappers.                                                                          |
| `@dismissable`               | Default true when `@closeModal` set. Disables Esc / backdrop click / X.                                       |
| `@autofocus`                 | Default true. Auto-focuses first focusable element via `dTrapTab`.                                            |
| `@submitOnEnter`             | Default true. Enter clicks `.d-modal__footer .btn-primary` unless focus is in a form / textarea / select-kit. |
| `@beforeClose`               | `async ({ initiatedBy }) => boolean`. Return `false` to cancel close (e.g. dirty-form confirm).               |
| `@hidden`                    | Pauses keyboard handling; used when a nested modal is on top.                                                 |
| `@tagName`                   | `"div"` (default) or `"form"`. Use `"form"` for forms so native submit works.                                 |

### Blocks

| Block                  | Position                                   | When to use                                                                                                                                                      |
| ---------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| default / `:body`      | Main content area                          | Default area                                                                                                                                                     |
| `:aboveHeader`         | Very top, before header                    | Rarely needed; for content that must sit above the title bar (e.g. a banner).                                                                                    |
| `:headerAboveTitle`    | Inside header, before title                | Present but unused. Rarely needed.                                                                                                                               |
| `:belowModalTitle`     | Inside `.d-modal__title`, after the `<h1>` | Excellent position for supplementary meta info.                                                                                                                  |
| `:headerBelowTitle`    | Inside header, after title block           | Tabs, sub-nav, or search input that's part of the header.                                                                                                        |
| `:headerPrimaryAction` | Right side of header on **mobile only**    | Replaces the X close button with a primary action (e.g. "Save"). Also auto-renders a "Cancel" button on the left and adds `.--has-primary-action` to the header. |
| `:belowHeader`         | Between header and body                    | Persistent sub-header content (e.g.searchar) that's outside the scrollable body, so sticky display.                                                              |
| `:aboveFooter`         | Between body and footer                    | Suppressed when `@hideFooter` is set. Use for content tied to the footer but outside it. Also rare.                                                              |
| `:footer`              | Bottom action bar                          | Primary + secondary buttons. The first `.btn-primary` here is what Enter triggers.                                                                               |
| `:belowFooter`         | After the footer                           | Rarely needed; ignores `@hideFooter`. Useful for status text outside the bordered footer area.                                                                   |

Sources: [the interactive styleguide](https://meta.discourse.org/styleguide/organisms/modal) for arguments, and [the d-modal template implementation](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/ui-kit/d-modal.gjs) for named blocks.

### CSS

Use the `.d-modal` classes as an achor to override core, and avoid the legacy `.modal selector.

4 modifiers available:

- .`--large` sets **max** **width** to 800px (desktop-only)
- .`--max` sets **max** **width** to 90vw (desktop-only)
- .`has-search` sets **fixed** **height** (80vh): intended for modals with search/filter system to avoid height change based on result length (desktop-only)
- `.--stacked` sets footer buttons to stacking (mobile-only)
