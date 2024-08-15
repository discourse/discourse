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
> :information_source: The [`mut` helper](https://api.emberjs.com/ember/release/classes/Ember.Templates.helpers/methods/mut)  is used here as a hbs-only way to set a value. You could also set `modalIsVisible` using any other standard Ember method.

This example will create a simple Modal like this:

![SCR-20230614-mxwd|690x255, 30%](/assets/dmodal-api-1.png)

## Wrapping in a component

Before introducing any more complexity, it's usually best to wrap up your new Modal in its own Component definition. Let's move the `<DModal>` stuff inside a new `<MyModal />` component

```hbs
{{! components/my-modal.hbs }}
<DModal @title="My Modal" @closeModal={{@closeModal}}>
  Hello world, this is some content in a modal
</DModal>
```

Introducing a companion `.js` component file will allow you to introduce more complex logic and state.

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

Ideally, `<DModal>` instances should be rendered from within an Ember handlebars template using the declarative technique demonstrated above. If that's not feasible for your use case (e.g. you need to trigger a modal from Discourse's legacy 'raw-hbs' or 'widget' rendering systems) then it can be done by injecting the `modal` service and calling `modal.show()`.

Make sure you've wrapped up your modal in its own component as described above. Then, trigger the modal by passing a reference of your component class to `showModal`:

```js
import MyModal from "discourse/components/my-modal";

// (inject the modal service in the relevant place)

// Add this call whenever you want to open the modal.
// A `@closeModal` argument will be passed to your component automatically.
this.modal.show(MyModal);

// Optionally, pass a '`model`' parameter. Passed as `@model` to your component.
// This can include data, and also actions/callbacks for your Modal to use.
this.modal.show(MyModal, { model: { topic: this.topic, someAction: this.someAction } });

// `modal.show()` returns a promise, so you can wait for it to be closed
// It will resolve with the data passed to the `@closeModal` action
const result = await this.modal.show(MyModal);
```

## More customizability!

`<DModal>` has a number of named blocks and arguments. Check out [the interactive styleguide](https://meta.discourse.org/styleguide/organisms/modal) for arguments, and [the d-modal template implemetation](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/d-modal.hbs) for named blocks.
