---
title: Discourse toolkit to render forms.
short_title: FormKit
id: form-kit
---

<div data-theme-toc="true"> </div>

# Basic Usage

FormKit exposes a single component as its public API: `<Form />`. All other elements are yielded as contextual components, modifiers, or plain data.

Every form is composed of one or multiple fields, representing the value, validation, and metadata of a control. Each field encapsulates a control, which is the form element the user interacts with to enter data, such as an input or select. The control type is specified via `@type` on the field. Other utilities, like submit or alert, are also provided.

Here is the most basic example of a form:

```gjs
import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";

export default class MyForm extends Component {
  @action
  handleSubmit(data) {
    // do something with data
  }

  <template>
    <Form @onSubmit={{this.handleSubmit}} as |form|>
      <form.Field
        @name="username"
        @title="Username"
        @validation="required"
        @type="input"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field @name="age" @title="Age" @type="input-number" as |field|>
        <field.Control />
      </form.Field>

      <form.Submit />
    </Form>
  </template>
}
```

# Form

## Yielded Parameters

### form

The `Form` component yields a `form` object containing contextual components and helper functions.

Common members include:

- `Field`, `Object`, `Collection`, `Fieldset`, `Row`, `Section`, `Container`
- `Submit`, `Reset`, `Button`, `Alert`, `Actions`
- `CheckboxGroup`, `InputGroup`, `ConditionalContent`
- `set(name, value)`, `setProperties(object)`, `addItemToCollection(name, value)`

**Example**

```hbs
<Form as |form|>
  <form.Row as |row|>
    <!-- ... -->
  </form.Row>
</Form>
```

### transientData

`transientData` is the form's current draft state. It starts as a clone of `@data`, updates as the user edits fields, and does not mutate the original `@data` object.

> :information_source: This is useful if you want to have conditionals in your form based on other fields.

**Example**

```hbs
<Form as |form transientData|>
  <form.Field @name="amount" @title="Amount" @type="input-number" as |field|>
    <field.Control />
  </form.Field>

  {{#if (gt transientData.amount 200)}}
    <form.Field @name="confirmed" @title="Confirm" @type="checkbox" as |field|>
      <field.Control>I know what I'm doing</field.Control>
    </form.Field>
  {{/if}}
</Form>
```

## Arguments

### @data

Initial state of the form data.

**FormKit expects a plain JavaScript object (POJO).** Internally it clones that object into draft state, tracks patches, and only mutates its own internal copy.

Keys matching field `@name`s are prepopulated automatically, including nested object and collection paths.

> :information_source: `@data` is treated as immutable. Edits do not mutate the original object you pass in. If you need to keep some external state in sync while editing, do that explicitly in `@onSet`.

When deriving a form object from a model, prefer a cached getter:

```js
@cached
get formData() {
  return getProperties(this.model, "foo", "bar", "baz");
}
```

**Parameter**

- `data` (Object): The data object passed to the template.

**Example**

```hbs
<Form @data={{hash foo="bar"}} as |form|>
  <form.Field @name="foo" @title="Foo" @type="input" as |field|>
    <!-- This input will have "bar" as its initial value -->
    <field.Control />
  </form.Field>
</Form>
```

### @onRegisterApi

Callback called when the form instance is created. It allows the developer to interact with the form through JavaScript.

**Parameters**

- `callback` (Object): The object containing callback functions.
- `callback.get` (Function): Returns the current value for a field name.
- `callback.submit` (Function): Function to submit the form.
- `callback.reset` (Function): Function to reset the form.
- `callback.set` (Function): Function to set a key/value on the form data object.
- `callback.setProperties` (Function): Function to set an object on the form data object.
- `callback.addError` (Function): Function to add an error programmatically.
- `callback.removeError` (Function): Function to remove a single field error.
- `callback.removeErrors` (Function): Function to clear all errors.
- `callback.isDirty` (boolean): Tracked property exposing the dirty state of the form. It becomes `true` after changes are made and returns to `false` after reset.

**Example**

```js
registerAPI({ get, submit, reset, set, addError }) {
  // Interact with the form API
  get("foo");
  submit();
  reset();
  set("foo", 1);
  addError("foo", { title: "Foo", message: "Something went wrong" });
}
```

```hbs
<Form @onRegisterApi={{this.registerAPI}} />
```

### @onSubmit

Callback called when the form is submitted **and valid**.

**Parameters**

- `data` (Object): The current draft data for the form.

**Example**

```js
handleSubmit({ username, age }) {
  console.log(username, age);
}
```

```hbs
<Form @onSubmit={{this.handleSubmit}} as |form|>
  <form.Field @name="username" @title="Username" @type="input" as |field|>
    <field.Control />
  </form.Field>
  <form.Field @name="age" @title="Age" @type="input-number" as |field|>
    <field.Control />
  </form.Field>
  <form.Submit />
</Form>
```

### @onReset

Callback called after FormKit rolls the draft data back to its initial state and clears errors.

**Parameters**

- `data` (Object): The rolled-back draft data.

**Example**

```js
handleReset(data) {
  console.log("reset to", data);
}
```

```hbs
<Form @data={{this.formData}} @onReset={{this.handleReset}} as |form|>
  <form.Field @name="username" @title="Username" @type="input" as |field|>
    <field.Control />
  </form.Field>

  <form.Reset />
</Form>
```

### @validate

A custom validation callback added directly to the form. This runs once per validation pass, after field-level validation.

**Example**

```js
@action
myValidation(data, { addError }) {
  if (data.foo !== data.bar) {
    addError("foo", { title: "Foo", message: "Bar must be equal to Foo" });
  }
}
```

```hbs
<Form @validate={{this.myValidation}} />
```

An asynchronous example:

```js
@action
async myValidation(data, { addError }) {
  try {
    await ajax("/check-username", {
      type: "POST",
      data: { username: data.username }
    });
  } catch(e) {
    addError("username", { title: "Username", message: "Already taken!" });
  }
}
```

### @validateOn

Controls when FormKit should validate.

- Accepted values: `submit` (default), `change`, `focusout`, and `input`.

**Example**

```hbs
<Form @validateOn="change" />
```

### @onDirtyCheck

Callback used during route transitions when the form is dirty. Return a truthy value to show the built-in "dirty form" confirmation dialog, or a falsy value to skip it.

**Parameters**

- `transition` (Transition): The Ember route transition being processed.

**Example**

```js
@action
onDirtyCheck(transition) {
  return transition.to?.name !== "wizard.step";
}
```

```hbs
<Form @onDirtyCheck={{this.onDirtyCheck}} />
```

# Field

## @name

A field must have a unique name. This name is used to read/write the value on the form data object and is also used for validation.

Names cannot contain `.` or `-`. Dots are reserved for nested paths such as `profile.location.city`.

**Example**

```hbs
<form.Field @name="foo" @title="Foo" @type="input" as |field|>
  <field.Control />
</form.Field>
```

## @title

A field must have a title. It will be displayed above the control and is also used in validation.

**Example**

```hbs
<form.Field @name="foo" @title="Foo" @type="input" as |field|>
  <field.Control />
</form.Field>
```

## @type

A field must have a type. This determines which control component is rendered. The available types are:

- **Input types**: `input` (defaults to text), `input-text`, `input-number`, `input-email`, `input-password`, `input-url`, `input-tel`, `input-date`, `input-time`, `input-datetime-local`, `input-color`, `input-month`, `input-week`, `input-range`, `input-search`, `input-hidden`
- **Other controls**: `checkbox`, `code`, `calendar`, `color`, `composer`, `custom`, `emoji`, `icon`, `image`, `menu`, `password`, `question`, `radio-group`, `select`, `tag-chooser`, `textarea`, `toggle`

**Example**

```hbs
<form.Field @name="foo" @title="Foo" @type="input" as |field|>
  <field.Control />
</form.Field>
```

## @description

The description is optional and will be shown under the title when set.

**Example**

```hbs
<form.Field
  @name="foo"
  @title="Foo"
  @description="Bar"
  @type="input"
  as |field|
>
  <field.Control />
</form.Field>
```

## @helpText

The help text is optional and will be shown under the field when set.

**Example**

```hbs
<form.Field @name="foo" @title="Foo" @helpText="Baz" @type="input" as |field|>
  <field.Control />
</form.Field>
```

## @showTitle

By default, the title will be shown on top of the control. You can choose not to render it by setting this property to `false`.

**Example**

```hbs
<form.Field
  @name="foo"
  @title="Foo"
  @showTitle={{false}}
  @type="input"
  as |field|
>
  <field.Control />
</form.Field>
```

## @disabled

A field can be disabled to prevent any changes to it.

**Example**

```hbs
<form.Field
  @name="foo"
  @title="Foo"
  @disabled={{true}}
  @type="input"
  as |field|
>
  <field.Control />
</form.Field>
```

## @tooltip

Allows to display a tooltip next to the field's title. Won't display if title is not shown.
You can pass a string or a `<DTooltip />` component.

**Example**

```hbs
<Form as |form|>
  <form.Field
    @name="foo"
    @title="Foo"
    @type="input"
    @tooltip="a nice input"
    as |field|
  >
    <field.Control />
  </form.Field>
</Form>
```

```hbs
<Form as |form|>
  <form.Field
    @name="foo"
    @title="Foo"
    @type="input"
    @tooltip={{component DTooltip content="a nice input"}}
    as |field|
  >
    <field.Control />
  </form.Field>
</Form>
```

## @validation

Read the dedicated validation section.

## @validate

Read the dedicated custom validation section.

## @onSet

By default, when changing the value of a field, this value will be set on the form's internal data object. However, you can choose to have full control over this process for a field.

**Example**

```js
@action
handleFooChange(value, { set, name, parentName, index }) {
  set("foo", value + "-bar");
}
```

```hbs
<form.Field
  @name="foo"
  @title="Foo"
  @type="input"
  @onSet={{this.handleFooChange}}
  as |field|
>
  <field.Control />
</form.Field>
```

> :information_source: You can use `@onSet` to also mutate the initial data object if you need more reactivity for a specific case.

The second argument passed to `@onSet` contains:

- `set(name, value)`: update form draft state
- `name`: the field's full name
- `parentName`: the parent path for nested fields
- `index`: the current collection index when inside a collection

**Example**

```js
@action
handleFooChange(value, { set }) {
  set("foo", value + "-bar");
  this.model.foo = value + "-bar";
}
```

```hbs
<Form @data={{this.model}} as |form|>
  <form.Field
    @name="foo"
    @title="Foo"
    @type="input"
    @onSet={{this.handleFooChange}}
    as |field|
  >
    <field.Control />
  </form.Field>
</Form>
```

## Yielded Parameters

The field yields a single field object. The control component determined by `@type` is available as `field.Control`.

```hbs
<form.Field @name="foo" @title="Foo" @type="input" as |field|>
  <field.Control />
</form.Field>
```

### field.Control

`field.Control` is the control component determined by `@type`. You can pass control-specific attributes directly to it (e.g., `@height`, `@lang`, `placeholder`).

> :information_source: `field.Control` is the supported API. Older yielded names such as `field.Input` are deprecated.

### field

The yielded `field` object provides access to the field's data and helpers:

| Name      | Description                                         |
| --------- | --------------------------------------------------- |
| `Control` | Contextual component for the control set by `@type` |
| `id`      | ID to be used on the control for accessibility      |
| `errorId` | ID of the field error container                     |
| `name`    | Full field name, including nested path prefixes     |
| `value`   | Current value from draft data                       |
| `set`     | Function to set the field's value                   |

# Controls

Controls, as we use the term here, refer to the UI widgets that allow a user to enter data. In its most basic form, this would be an input. The control type is specified via `@type` on the field.

> :information_source: You can pass down HTML attributes to the underlying control.

**Example**

```hbs
<Form as |form|>
  <form.Field
    @name="query"
    @title="Query"
    @type="input"
    @description="You should make sure the query doesn't include bots."
    as |field|
  >
    <field.Control placeholder="Foo" />
  </form.Field>
</Form>
```

## @format

Controls accept a `@format` property which can be: `small`, `medium`, `large`, or `full`.

Form Kit sets defaults for each control, but you can override them using `@format`:

- small: `100px`
- medium: `220px`
- large: `400px`
- full: `100%`

Additionally, the following CSS variables are provided to customize these defaults:

- small: `--form-kit-small-input`
- medium: `--form-kit-medium-input`
- large: `--form-kit-large-input`

## @labelFormat

Overrides the width of the title and description (the label area) independently of `@format`. Useful when long descriptions need more room than the input itself — e.g. `@format="small"` with `@labelFormat="full"` keeps a small input but lets the description span the form. Only emit it when the label area should differ from the field; otherwise both inherit from `@format`. See `@format` for the available values.

## Checkbox

Renders an `<input type="checkbox">` element.

> :information_source: When to use a single checkbox
> There are only 2 options: yes/no. It feels like agreeing to something. Checking the box doesn't save; there is a submit button further down.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="approved" @title="Approved" @type="checkbox" as |field|>
    <field.Control />
  </form.Field>
</Form>
```

## Calendar

Renders a datepicker and a time input. On mobile the datepicker will be replaced by a date input.

### @includeTime

Displays the time input or not. Defaults to true.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="start" @title="Start" @type="calendar" as |field|>
    <field.Control @includeTime={{false}} />
  </form.Field>
</Form>
```

### @expandedDatePickerOnDesktop

Displays date picker expanded on desktop. Defaults to true.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="start" @title="Start" @type="calendar" as |field|>
    <field.Control @expandedDatePickerOnDesktop={{false}} />
  </form.Field>
</Form>
```

## Code

Renders an `<AceEditor />` component.

### @height

Sets the height of the editor in pixels.

### @lang

Sets the editor mode.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="query" @title="Query" @type="code" as |field|>
    <field.Control @lang="sql" @height={{400}} />
  </form.Field>
</Form>
```

## Color

Renders a color input with optional preset swatches.

Common control arguments:

- `@colors`: array of preset colors
- `@usedColors`: array of already-used colors
- `@collapseSwatches`: collapse swatches into a menu
- `@collapseSwatchesLabel`: label for the collapsed swatches button
- `@allowNamedColors`: allow named colors instead of only hex values
- `@fallbackValue`: value to restore on blur when left blank

**Example**

```hbs
<Form as |form|>
  <form.Field @name="color" @title="Color" @type="color" as |field|>
    <field.Control
      @colors={{array "0088CC" "FFCC00"}}
      @usedColors={{array "FFCC00"}}
    />
  </form.Field>
</Form>
```

## Composer

Renders a `<DEditor />` component.

### @height

Sets the height of the composer.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="message" @title="Message" @type="composer" as |field|>
    <field.Control @height={{400}} />
  </form.Field>
</Form>
```

### @preview

Controls the display the composer preview. Defaults to `false`.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="message" @title="Message" @type="composer" as |field|>
    <field.Control @preview={{true}} />
  </form.Field>
</Form>
```

## Custom

Renders a wrapper for custom content. This is the right choice when you want to provide your own control markup but still use FormKit field metadata and state.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="slug" @title="Slug" @type="custom" as |field|>
    <field.Control>
      <MyCustomControl
        id={{field.id}}
        @value={{field.value}}
        @onChange={{field.set}}
      />
    </field.Control>
  </form.Field>
</Form>
```

## Emoji

Renders an `<EmojiPicker />` component.

### @context

Passes the picker context through to `<EmojiPicker />`.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="emoji" @title="Emoji" @type="emoji" as |field|>
    <field.Control @context="chat" />
  </form.Field>
</Form>
```

## Icon

Renders an `<IconPicker />` component.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="icon" @title="Icon" @type="icon" as |field|>
    <field.Control />
  </form.Field>
</Form>
```

## Image

Renders an `<UppyImageUploader />` component.

Common control arguments:

- `@type`: uploader context passed to `<UppyImageUploader />`
- `@placeholderUrl`: optional placeholder image

### Upload Handling

By default, the component will set an upload object. It's common to only want the URL and the ID of the upload. To achieve this, you can use the `@onSet` property on the field:

```js
@action
handleUpload(upload, { set }) {
  set("upload_id", upload.id);
  set("upload_url", getURL(upload.url));
}
```

```hbs
<Form as |form|>
  <form.Field
    @name="upload"
    @title="Upload"
    @type="image"
    @onSet={{this.handleUpload}}
    as |field|
  >
    <field.Control />
  </form.Field>
</Form>
```

**Example**

```hbs
<Form as |form|>
  <form.Field @name="upload" @title="Upload" @type="image" as |field|>
    <field.Control />
  </form.Field>
</Form>
```

## Input

Renders an `<input>` element.

### @type

The input variant is specified as part of the field's `@type` using the `input-` prefix. For example, `@type="input"`, `@type="input-number"`, or `@type="input-email"`. `@type="input"` defaults to text.

### Allowed Types

- `input` (defaults to text)
- `input-color`
- `input-date`
- `input-datetime-local`
- `input-email`
- `input-hidden`
- `input-month`
- `input-number`
- `input-password`
- `input-range`
- `input-search`
- `input-tel`
- `input-text`
- `input-time`
- `input-url`
- `input-week`

### Special Cases

- `checkbox` and `radio` have dedicated controls
- file uploads should use `@type="image"`

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="email" @title="Email" @type="input" as |field|>
    <field.Control />
  </form.Field>

  <form.Field @name="age" @title="Age" @type="input-number" as |field|>
    <field.Control />
  </form.Field>
</Form>
```

### @before

Renders text before the input

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="email" @title="Email" @type="input" as |field|>
    <field.Control @before="mailto:" />
  </form.Field>
</Form>
```

### @after

Renders text after the input

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="email" @title="Email" @type="input" as |field|>
    <field.Control @after=".com" />
  </form.Field>
</Form>
```

## Menu

Renders a `<DMenu />` trigger with yielded menu content.

### @selection

The text to show on the trigger.

### yielded parameters

#### Item

Renders a selectable row. Accepts `@value`, `@icon` and `@action` props.

- @value: allows to assign a value to a row.
- @icon: shows an icon at the start of the row.
- @action: override the default action which would set the value of the field with the value of this row.

The content will be yielded.

#### Divider

Renders a separator.

#### Container

Renders a div which will have for content the yielded content.

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="email" @title="Email" @type="menu" as |field|>
    <field.Control as |menu|>
      <menu.Item @value={{1}} @icon="pencil-alt">Edit</menu.Item>
      <menu.Divider />
      <menu.Container class="foo">
        Bar
      </menu.Container>
      <menu.Item @action={{this.doSomething}}>Something</menu.Item>
    </field.Control>
  </form.Field>
</Form>
```

## Password

Renders a password input with a visibility toggle.

> :information_source: This is different from `@type="input-password"`. The dedicated `password` control adds the show/hide button.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="secret" @title="Secret" @type="password" as |field|>
    <field.Control />
  </form.Field>
</Form>
```

## Question

Renders two inputs of type radio where the first one is a positive answer, the second one a negative answer.

### @yesLabel

Allows to customize the positive label.

### @noLabel

Allows to customize the negative label.

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="email" @title="Email" @type="question" as |field|>
    <field.Control @yesLabel="Correct" @noLabel="Wrong" />
  </form.Field>
</Form>
```

## RadioGroup

Renders a list of radio buttons sharing a common name.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="foo" @title="Foo" @type="radio-group" as |field|>
    <field.Control as |radioGroup|>
      <radioGroup.Radio @value="one">One</radioGroup.Radio>
      <radioGroup.Radio @value="two">Two</radioGroup.Radio>
      <radioGroup.Radio @value="three">Three</radioGroup.Radio>
    </field.Control>
  </form.Field>
</Form>
```

### Radio yielded parameters

#### Title

Allows to render a title.

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="foo" @title="Foo" @type="radio-group" as |field|>
    <field.Control as |RadioGroup|>
      <RadioGroup.Radio @value="one" as |radio|>
        <radio.Title>One title</radio.Title>
      </RadioGroup.Radio>
    </field.Control>
  </form.Field>
</Form>
```

#### Description

Allows to render a description.

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="foo" @title="Foo" @type="radio-group" as |field|>
    <field.Control as |RadioGroup|>
      <RadioGroup.Radio @value="one" as |radio|>
        <radio.Description>One description</radio.Description>
      </RadioGroup.Radio>
    </field.Control>
  </form.Field>
</Form>
```

## Select

Renders a `<DSelect />` component.

### @includeNone

By default, Select includes a "none" option when the field is blank or when the field is not marked `required`. Override this with `@includeNone`.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="fruits" @title="Fruits" @type="select" as |field|>
    <field.Control as |select|>
      <select.Option @value="1">Mango</select.Option>
      <select.Option @value="2">Apple</select.Option>
      <select.Option @value="3">Coconut</select.Option>
    </field.Control>
  </form.Field>
</Form>
```

## Tag Chooser

Renders a `<TagChooser />` component.

Common control arguments:

- `@allowCreate`
- `@categoryId`
- `@showAllTags`
- `@excludeSynonyms`
- `@excludeTagsWithSynonyms`
- `@unlimited`
- `@placeholder`

**Example**

```hbs
<Form as |form|>
  <form.Field @name="tags" @title="Tags" @type="tag-chooser" as |field|>
    <field.Control @categoryId={{1}} @allowCreate={{true}} />
  </form.Field>
</Form>
```

## Textarea

Renders a `<textarea>` element.

### @height

Sets the height of the textarea.

**Example**

```hbs
<Form as |form|>
  <form.Field
    @name="description"
    @title="Description"
    @type="textarea"
    as |field|
  >
    <field.Control @height={{120}} />
  </form.Field>
</Form>
```

## Toggle

Renders a `<DToggleSwitch />` component.

> :information_source: There are only 2 states: enabled/disabled. It should feel like turning something on. Toggling takes effect immediately, there is no submit button.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="allowed" @title="Allowed" @type="toggle" as |field|>
    <field.Control />
  </form.Field>
</Form>
```

# Layout

Form Kit aims to provide good defaults, allowing you to mainly use fields and controls. However, if you need more control, we provide several helpers: Row and Col, Section, Fieldset, Container and Actions.

You can also use utilities like Submit, Reset, Alert, CheckboxGroup, InputGroup, and ConditionalContent.

## Actions

`Actions` is a custom `Container` designed to wrap your buttons in the footer of your form.

**Example**

```hbs
<Form as |form|>
  <form.Actions>
    <form.Submit />
  </form.Actions>
</Form>
```

## Alert

Displays an alert in the form.

### @icon

An optional icon to use in the alert.

**Example**

```hbs
<form.Alert @icon="info-circle">
  Foo
</form.Alert>
```

### @type

Specifies the type of alert. Allowed types: `success`, `error`, `warning`, or `info`.

**Example**

```hbs
<form.Alert @type="warning">
  Foo
</form.Alert>
```

## Checkbox Group

`CheckboxGroup` allows grouping checkboxes together.

**Example**

```hbs
<form.CheckboxGroup @title="Preferences" as |group|>
  <group.Field @name="editable" @title="Editable" @type="checkbox" as |field|>
    <field.Control />
  </group.Field>
  <group.Field
    @name="searchable"
    @title="Searchable"
    @type="checkbox"
    as |field|
  >
    <field.Control />
  </group.Field>
</form.CheckboxGroup>
```

## ConditionalContent

`ConditionalContent` helps you switch between mutually exclusive blocks of content using a small radio control.

**Example**

```hbs
<Form as |form|>
  <form.ConditionalContent @activeName="basic" as |conditional|>
    <conditional.Conditions as |Condition|>
      <Condition @name="basic">Basic</Condition>
      <Condition @name="advanced">Advanced</Condition>
    </conditional.Conditions>

    <conditional.Contents as |Content|>
      <Content @name="basic">
        <form.Alert>Basic settings</form.Alert>
      </Content>

      <Content @name="advanced">
        <form.Alert @type="warning">Advanced settings</form.Alert>
      </Content>
    </conditional.Contents>
  </form.ConditionalContent>
</Form>
```

## Container

`Container` allows you to render a block similar to a field without tying it to specific data. It is useful for custom controls.

Common arguments:

- `@title`
- `@subtitle`
- `@format`
- `@direction`

**Example**

```hbs
<Form as |form|>
  <form.Container @title="Important" @subtitle="This is important">
    <!-- Container content here -->
  </form.Container>
</Form>
```

## Fieldset

Wraps content in a fieldset.

**Example**

```hbs
<form.Fieldset @name="a-fieldset" class="my-fieldset">
  Foo
</form.Fieldset>
```

### @title

Displays a title for the fieldset, will use the legend element.

**Example**

```hbs
<form.Fieldset @title="A title">
  Foo
</form.Fieldset>
```

### @description

Displays a description for the fieldset.

**Example**

```hbs
<form.Fieldset @description="A description">
  Foo
</form.Fieldset>
```

### @name

Sets the name of the fieldset. This is necessary if you want to use the fieldset test helpers.

**Example**

```hbs
<form.Fieldset @name="a-name">
  Foo
</form.Fieldset>
```

## Input Group

Input group allows you to group multiple inputs together on one line.

**Example**

```hbs
<Form as |form|>
  <form.InputGroup as |inputGroup|>
    <inputGroup.Field @title="Foo" @name="foo" @type="input" as |field|>
      <field.Control />
    </inputGroup.Field>
    <inputGroup.Field @title="Bar" @name="bar" @type="input" as |field|>
      <field.Control />
    </inputGroup.Field>
  </form.InputGroup>
</Form>
```

## Reset

The `Reset` component renders a `<DButton />` which will reset the form when clicked. It accepts all the same parameters as a standard `<DButton />`. The label and default action are set by default.

**Example**

```hbs
<form.Reset />
```

To customize the `Reset` button further, you can pass additional parameters as needed:

**Example with Additional Parameters**

```hbs
<form.Reset @translatedLabel="Remove changes" />
```

## Row and Col

`Row` and `Col` enable you to utilize a simple grid system (12 columns) within your form.

**Example**

```hbs
<Form as |form|>
  <form.Row as |row|>
    <row.Col @size={{4}}>
      <form.Field @name="foo" @title="Foo" @type="input" as |field|>
        <field.Control />
      </form.Field>
    </row.Col>
    <row.Col @size={{8}}>
      <form.Field @name="bar" @title="Bar" @type="input" as |field|>
        <field.Control />
      </form.Field>
    </row.Col>
  </form.Row>
</Form>
```

## Section

`Section` provides a simple way to create a section with or without a title.

### @subtitle

Displays secondary text in the section header.

**Example**

```hbs
<Form as |form|>
  <form.Section @title="Settings">
    <!-- Section content here -->
  </form.Section>
</Form>
```

## Submit

The `Submit` component renders a `<DButton />` which will submit the form when clicked. It accepts all the same parameters as a standard `<DButton />`. The label, default action, and primary style are set by default.

**Example**

```hbs
<form.Submit />
```

To customize the `Submit` button further, you can pass additional parameters as needed:

**Example with Additional Parameters**

```hbs
<form.Submit @translatedLabel="Send" />
```

# Object

The object component lets you work with a nested object in your form.

**Example**

```hbs
<Form @data={{hash foo=(hash bar=1 baz=2)}} as |form|>
  <form.Object @name="foo" as |object data|>
    <object.Field @name="bar" @title="Bar" @type="input" as |field|>
      <field.Control />
    </object.Field>
    <object.Field @name="baz" @title="Baz" @type="input" as |field|>
      <field.Control />
    </object.Field>
  </form.Object>
</Form>
```

## @name

An object must have a unique name. This name is used as a prefix for the underlying fields.

Like field names, object names should not contain `.` or `-`.

**Example**

```hbs
<form.Object @name="foo" />
```

## Nesting

An object can accept a nested Object or Collection.

**Example**

```hbs
<Form @data={{hash foo=(hash bar=(hash baz=1 bol=2))}} as |form|>
  <form.Object @name="foo" as |parentObject|>
    <parentObject.Object @name="bar" as |childObject data|>
      <childObject.Field @name="baz" @title="Baz" @type="input" as |field|>
        <field.Control />
      </childObject.Field>
    </parentObject.Object>
  </form.Object>
</Form>

<Form @data={{hash foo=(hash bar=(array 1 2))}} as |form|>
  <form.Object @name="foo" as |parentObject|>
    <parentObject.Collection @name="bar" as |collection index|>
      <collection.Field @title="Baz" @type="input" as |field|>
        <field.Control />
      </collection.Field>
      <form.Button
        class={{concat "remove-" index}}
        @action={{fn collection.remove index}}
      >Remove</form.Button>
    </parentObject.Collection>
  </form.Object>
</Form>
```

# Collection

The collection component lets you work with arrays in your form.

It yields three values: the collection API, the current index, and the current item.

**Example**

```hbs
<Form @data={{hash foo=(array (hash bar=1) (hash bar=2))}} as |form|>
  <form.Collection @name="foo" as |collection index item|>
    <collection.Field @name="bar" @title="Bar" @type="input" as |field|>
      <field.Control placeholder={{concat "item-" index}} />
    </collection.Field>
  </form.Collection>
</Form>
```

## @name

A collection must have a unique name. This name is used as a prefix for the underlying fields.

For example, if collection has the name "foo", the 2nd field of the collection with the name "bar", will actually have "foo.1.bar" as name.

Like field names, collection names should not contain `.` or `-`.

**Example**

```hbs
<form.Collection @name="foo" />
```

## @tagName

A collection renders as a `<div class="form-kit__collection">` by default. You can alter this behavior with `@tagName`.

**Example**

```hbs
<form.Collection @name="foo" @tagName="tr" />
```

## Primitive array

If the shape of your data is an array of primitives, eg: [1, 2, 3], form-kit is able to handle it. You just have to omit the name on the field in this case, as the name will be auto generated for you with the index.

**Example**

```hbs
<Form @data={{hash foo=(array 1 2)}} as |form|>
  <form.Collection @name="foo" as |collection|>
    <collection.Field @title="Baz" @type="input" as |field|>
      <field.Control />
    </collection.Field>
  </form.Collection>
</Form>
```

## Nesting

A collection can accept a nested Object or Collection.

**Example**

```hbs
<Form
  @data={{hash foo=(array (hash bar=(hash baz=1)) (hash bar=(hash baz=2)))}}
  as |form|
>
  <form.Collection @name="foo" as |collection|>
    <collection.Object @name="bar" as |object|>
      <object.Field @name="baz" @title="Baz" @type="input" as |field|>
        <field.Control />
      </object.Field>
    </collection.Object>
  </form.Collection>
</Form>

<Form
  @data={{hash
    foo=(array (hash bar=(array (hash baz=1))) (hash bar=(array (hash baz=2))))
  }}
  as |form|
>
  <form.Collection @name="foo" as |parent parentIndex|>
    <parent.Collection @name="bar" as |child childIndex|>
      <child.Field @name="baz" @title="Baz" @type="input" as |field|>
        <field.Control />
      </child.Field>
    </parent.Collection>
  </form.Collection>
</Form>
```

## Add an item to the collection

The `<Form />` component yielded object has a `addItemToCollection` function that you can call to add an item to a specific collection.

**Example**

```hbs
<Form @data={{hash foo=(array (hash bar=1) (hash bar=2))}} as |form|>
  <form.Button @action={{fn form.addItemToCollection "foo" (hash bar=3)}}>
    Add
  </form.Button>

  <form.Collection @name="foo" as |collection index|>
    <collection.Field @name="bar" @title="Bar" @type="input" as |field|>
      <field.Control placeholder={{concat "item-" index}} />
    </collection.Field>
  </form.Collection>
</Form>
```

## Remove an item from the collection

The `<Collection />` component yielded object has a `remove` function that you can call to remove an item from this collection, it takes the index as parameter

**Example**

```hbs
<Form @data={{hash foo=(array (hash bar=1) (hash bar=2))}} as |form|>
  <form.Collection @name="foo" as |collection index|>
    <collection.Field @name="bar" @title="Bar" @type="input" as |field|>
      <field.Control />
      <form.Button @action={{fn collection.remove index}}>
        Remove
      </form.Button>
    </collection.Field>
  </form.Collection>
</Form>
```

# Validation

Field accepts a `@validation` property which allows you to describe the validation rules of the field.

## List of Available Rules

### Accepted

The value must be `"yes"`, `"on"`, `true`, `1`, or `"true"`. Useful for checkbox inputs — often where you need to validate if someone has accepted terms.

**Example**

```hbs
<form.Field
  @name="terms"
  @title="Terms"
  @type="checkbox"
  @validation="accepted"
  as |field|
>
  <field.Control />
</form.Field>
```

### Between

Checks that a numeric value is between a minimum and maximum value.

**Example**

```hbs
<form.Field
  @name="amount"
  @title="Amount"
  @type="input-number"
  @validation="between:1,10"
  as |field|
>
  <field.Control />
</form.Field>
```

### dateAfterOrEqual

Checks if a calendar value is after or equal to the specified date. Format must be `YYYY-MM-DD`.

**Example**

```hbs
<form.Field
  @name="start"
  @title="Start"
  @type="calendar"
  @validation="dateAfterOrEqual:2022-02-01"
  as |field|
>
  <field.Control />
</form.Field>
```

### dateBeforeOrEqual

Checks if a calendar value is before or equal to the specified date. Format must be `YYYY-MM-DD`.

**Example**

```hbs
<form.Field
  @name="start"
  @title="Start"
  @type="calendar"
  @validation="dateBeforeOrEqual:2022-02-01"
  as |field|
>
  <field.Control />
</form.Field>
```

### EndsWith

Checks that a string ends with a given suffix.

**Example**

```hbs
<form.Field
  @name="domain"
  @title="Domain"
  @type="input"
  @validation="endsWith:.com"
  as |field|
>
  <field.Control />
</form.Field>
```

### Integer

Checks if the value is an integer.

**Example**

```hbs
<form.Field
  @name="age"
  @title="Age"
  @type="input-number"
  @validation="integer"
  as |field|
>
  <field.Control />
</form.Field>
```

### Length

Checks that the input's value is over a given length, or between two length values.

**Example**

```hbs
<form.Field
  @name="username"
  @title="Username"
  @type="input"
  @validation="length:5,16"
  as |field|
>
  <field.Control />
</form.Field>
```

### Number

Checks if the input is a valid number as evaluated by `isNaN()`.

> :information_source: When applicable, prefer to use the number input: `@type="input-number"`.

**Example**

```hbs
<form.Field
  @name="amount"
  @title="Amount"
  @type="input"
  @validation="number"
  as |field|
>
  <field.Control />
</form.Field>
```

### Required

Checks if the input is empty.

`required:trim` trims leading and trailing whitespace before checking the value.

**Example**

```hbs
<form.Field
  @name="username"
  @title="Username"
  @type="input"
  @validation="required:trim"
  as |field|
>
  <field.Control />
</form.Field>
```

### StartsWith

Checks that a string starts with a given prefix.

**Example**

```hbs
<form.Field
  @name="handle"
  @title="Handle"
  @type="input"
  @validation="startsWith:@"
  as |field|
>
  <field.Control />
</form.Field>
```

### URL

Checks if the input value appears to be a properly formatted URL including the protocol. This does not check if the URL actually resolves.

**Example**

```hbs
<form.Field
  @name="endpoint"
  @title="Endpoint"
  @type="input-url"
  @validation="url"
  as |field|
>
  <field.Control />
</form.Field>
```

## Combining Rules

Rules can be combined using the pipe operator: `|`.

**Example**

```hbs
<form.Field
  @name="username"
  @title="Username"
  @type="input"
  @validation="required|length:5,16"
  as |field|
>
  <field.Control />
</form.Field>
```

## Custom Validation

### Field

Field accepts a `@validate` property which allows you to define a callback function to validate a single field.

**Parameters**

- `name` (string): The name of the form field being validated.
- `value` (unknown): The current field value.
- `context` (Object)
  - `context.data` (Object): Current form draft data.
  - `context.type` (string): Field control type.
  - `context.addError` (Function): Adds an error if validation fails.

**Example**

```js
@action
validateUsername(name, value, { data, addError }) {
  if (value === data.slug) {
    addError(name, {
      title: "Username",
      message: "Username and slug must differ.",
    });
  }
}
```

```hbs
<form.Field
  @name="username"
  @title="Username"
  @type="input"
  @validate={{this.validateUsername}}
  as |field|
>
  <field.Control />
</form.Field>
```

### Form

Form accepts a `@validate` property which allows you to define a callback function to validate the full form state once per validation pass.

**Parameters**

- `data` (Object): The data object containing additional information for validation.
- `handlers` (Object): An object containing handler functions.
  - `handlers.addError` (Function): A function to add an error if validation fails.
  - `handlers.removeError` (Function): A function to clear an existing error.

**Example**

```js
@action
validateForm(data, { addError, removeError }) {
  if (data.start && data.end && data.end < data.start) {
    addError("end", {
      title: "End",
      message: "End must be after start.",
    });
  } else {
    removeError("end");
  }
}
```

```hbs
<Form @validate={{this.validateForm}} as |form|>
  <form.Field @name="start" @title="Start" @type="input-date" as |field|>
    <field.Control />
  </form.Field>

  <form.Field @name="end" @title="End" @type="input-date" as |field|>
    <field.Control />
  </form.Field>

  <form.Submit />
</Form>
```

> :information_source: Unknown validation rule names raise at runtime. Keep the rule list above in sync with the implementation when extending FormKit.

# Helpers

Helpers are yielded by some blocks, like Form, or provided as parameters to callbacks. They allow you to interact with the form state in a simple and clear way.

## set

`set` allows you to assign a value to a specific field in the form's data.

**Parameters**

- `name` (string): The name of the field to which the value is to be set.
- `value` (number): The value to be set.

**Example**

```js
set("foo", 1);
```

Using the `set` helper yielded by the form:

```hbs
<Form as |form|>
  <DButton @action={{fn form.set "foo" 1}} @translatedLabel="Set foo" />
</Form>
```

## setProperties

`setProperties` allows you to assign an object to the form's data.

**Parameters**

- `data` (object): A POJO where each key is going to be set on the form using its value.

**Example**

```js
setProperties({ foo: 1, bar: 2 });
```

Using the `setProperties` helper yielded by the form:

```hbs
<Form as |form|>
  <DButton
    @action={{fn form.setProperties (hash foo=1 bar=2)}}
    @translatedLabel="Set foo and bar"
  />
</Form>
```

## addError

`addError` allows you to add an error message to a specific field in the form.

**Parameters**

- `name` (string): The name of the field that is invalid.
- `error` (object): The error's data
  - `title` (string): The title of the error, usually the translated name of the field
  - `message` (string): The error message

**Example**

```js
addError("foo", { title: "Foo", message: "This should be another thing." });
```

# Customize

## Plugin Outlets

FormKit works seamlessly with `<PluginOutlet />`. You can use plugin outlets inside your form to extend its functionality:

```hbs
<Form as |form|>
  <PluginOutlet @name="above-foo-form" @outletArgs={{hash form=form}} />
</Form>
```

Then, in your connector, you can use the outlet arguments to add custom fields:

```hbs title="connectors/above-foo-form/bar-input.hbs"
<@outletArgs.form.Field @name="bar" @title="Bar" @type="input" as |field|>
  <field.Control />
</@outletArgs.form.Field>
```

## Styling

All FormKit components propagate attributes, allowing you to set classes and data attributes, for example:

```hbs
<Form class="my-form" as |form|>
  <form.Field
    @name="foo"
    @title="Foo"
    @type="input"
    class="my-field"
    as |field|
  >
    <field.Control class="my-control" />
  </form.Field>
</Form>
```

## Custom Control

Creating a custom control is straightforward with the properties yielded by `form` and `field`:

```hbs
<Form as |form|>
  <form.Field
    @name="foo"
    @title="Foo"
    @type="custom"
    class="my-field"
    as |field|
  >
    <field.Control>
      <MyCustomControl id={{field.id}} @onChange={{field.set}} />
    </field.Control>
  </form.Field>
</Form>
```

### Common Values on `form`

| Name                  | Description                                 |
| --------------------- | ------------------------------------------- |
| `set`                 | Set any field by name, e.g. `set("bar", 1)` |
| `setProperties`       | Set multiple field values at once           |
| `addItemToCollection` | Append an item to a collection by path      |

### Common Values on `field`

| Name      | Description                          |
| --------- | ------------------------------------ |
| `id`      | Input ID                             |
| `errorId` | Error container ID                   |
| `name`    | Full nested field path               |
| `value`   | Current field value from draft state |
| `set`     | Set the current field value          |

# Javascript assertions

## Form

The form element assertions are available at `assert.form(...).*`. By default it will select the first "form" element.

**Parameters**

- `target` (string | HTMLElement): The form element or selector.

### hasErrors()

Asserts that the form error summary contains the given field errors.

**Parameters**

- `fields` (Object): A map of field names to error messages, e.g. `{ username: "Required" }`.
- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().hasErrors({ username: "Required" }, "the form shows errors");
```

### hasNoErrors()

Asserts that the form error summary is not present.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().hasNoErrors("the form is valid");
```

## Field

The field element assertions are available at `assert.form(...).field(...).*`.

**Parameters**

- `name` (string): The name of the field.

**Example**

```js
assert.form().field("foo");
```

### hasValue()

Asserts that the `value` of the field matches the `expected` text.

**Parameters**

- `expected` (anything): The expected value.
- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().field("foo").hasValue("bar", "user has set the value");
```

### hasNoValue()

Asserts that the field is blank.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().field("foo").hasNoValue("the field starts blank");
```

### isDisabled()

Asserts that the `field` is disabled.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().field("foo").isDisabled("the field is disabled");
```

### isEnabled()

Asserts that the `field` is enabled.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().field("foo").isEnabled("the field is enabled");
```

### hasTitle()

Asserts that the field title matches the expected text.

**Parameters**

- `expected` (anything): The expected value.
- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().field("foo").hasTitle("Foo", "it shows the field title");
```

### hasDescription()

Asserts that the field description matches the expected text.

**Parameters**

- `expected` (anything): The expected value.
- `message` (string) [optional]: The description of the test.

**Example**

```js
assert
  .form()
  .field("foo")
  .hasDescription("Helpful copy", "it shows the description");
```

### hasError()

Asserts that the `field` has a specific error.

**Parameters**

- `error` (string): The error message on the field.
- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().field("foo").hasError("Required", "it is required");
```

### hasNoErrors()

Asserts that the `field` has no error.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().field("foo").hasNoErrors("it is valid");
```

### exists()

Asserts that the `field` is present.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().field("foo").exists("it has the foo field");
```

### doesNotExist()

Asserts that the `field` is not present.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().field("foo").doesNotExist("it has no foo field");
```

### hasCharCounter()

Asserts that the `field` has a char counter.

**Parameters**

- `current` (integer): The current length of the field.
- `max` (integer): The max length of the field.
- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().field("foo").hasCharCounter(2, 5, "it has updated the counter");
```

## Fieldset

The field element assertions are available at `assert.form(...).fieldset(...).*`.

**Parameters**

- `name` (string): The name of the fieldset.

**Example**

```js
assert.form().fieldset("foo");
```

### hasTitle()

Asserts that the `title` of the fieldset matches the `expected` value.

**Parameters**

- `expected` (anything): The expected value.
- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().fieldset("foo").hasTitle("bar", "it has the correct title");
```

### hasDescription()

Asserts that the `description` of the fieldset matches the `expected` value.

**Parameters**

- `expected` (anything): The expected value.
- `message` (string) [optional]: The description of the test.

**Example**

```js
assert
  .form()
  .fieldset("foo")
  .hasDescription("bar", "it has the correct description");
```

### includesText()

Asserts that the fieldset has yielded the `expected` value.

**Parameters**

- `expected` (anything): The expected value.
- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().fieldset("foo").includesText("bar", "it has the correct text");
```

### exists()

Asserts that the fieldset is present.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().fieldset("foo").exists("the fieldset is rendered");
```

### doesNotExist()

Asserts that the fieldset is not present.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```js
assert.form().fieldset("foo").doesNotExist("the fieldset is hidden");
```

# Javascript helpers

## Form

The FormKit helper allows you to manipulate a form and its fields through a clear and expressive API.

**Example**

```gjs
import formKit from "discourse/tests/helpers/form-kit-helper";

test("fill in input", async function (assert) {
  await render(
    <template>
      <Form class="my-form" as |form data|>
        <form.Field @name="foo" @title="Foo" @type="input" as |field|>
          <field.Control />
        </form.Field>
      </Form>
    </template>
  );

  const myForm = formKit(".my-form");
});
```

### submit()

Submits the associated form.

**Example**

```js
formKit().submit();
```

### reset()

Resets the associated form.

**Example**

```js
formKit().reset();
```

### field()

Returns a field helper for a named field.

**Parameters**

- `name` (string): The name of the field.

**Example**

```js
const field = formKit().field("foo");
```

### hasField()

Checks whether a field with the given name exists in the form.

**Parameters**

- `name` (string): The name of the field.

**Example**

```js
formKit().hasField("foo");
```

## Field

**Parameters**

- `name` (string): The name of the field.

### value()

Returns the current UI value for supported controls.

**Example**

```js
formKit().field("foo").value();
```

### options()

Returns the available option values for a `@type="select"` field.

**Example**

```js
formKit().field("foo").options();
```

### fillIn()

Can be used on input-like controls such as `@type="input"`, `@type="input-text"`, `@type="input-number"`, `@type="password"`, `@type="color"`, `@type="code"`, `@type="textarea"`, and `@type="composer"`.

**Parameters**

- `value` (string | integer | undefined): The value to set on the input.

**Example**

```js
await formKit().field("foo").fillIn("bar");
```

### toggle()

Can be used on `@type="checkbox"`, `@type="toggle"`, or `@type="password"` fields.

Will toggle the state of the control. In the case of the password control it will actually toggle the visibility of the field.

**Example**

```js
await formKit().field("foo").toggle();
```

### accept()

Can be used on `@type="question"` fields.

**Example**

```js
await formKit().field("foo").accept();
```

### refuse()

Can be used on `@type="question"` fields.

**Example**

```js
await formKit().field("foo").refuse();
```

### select()

Can be used on `@type="select"`, `@type="menu"`, `@type="icon"`, `@type="radio-group"`, and `@type="color"` fields.

Will select the given value.

**Parameters**

- `value` (string | integer | undefined): The value to select.

**Example**

```js
await formKit().field("foo").select("bar");
```

### setDay()

Can be used on `@type="calendar"` fields.

**Parameters**

- `day` (integer): The day of the month to select.

**Example**

```js
await formKit().field("start").setDay(15);
```

### setTime()

Can be used on `@type="calendar"` fields.

**Parameters**

- `time` (string): The time to set, e.g. `"14:30"`.

**Example**

```js
await formKit().field("start").setTime("14:30");
```

### isDisabled()

Returns whether the field is disabled.

**Example**

```js
formKit().field("foo").isDisabled();
```

### hasPrefix()

Can be used on `@type="color"` fields. Returns whether the color input renders its prefix.

**Example**

```js
formKit().field("color").hasPrefix();
```

### swatches()

Can be used on `@type="color"` fields. Returns the rendered swatches as `{ color, isUsed, isDisabled }`.

**Example**

```js
formKit().field("color").swatches();
```

### triggerEvent()

Triggers a DOM event on the field's input element.

**Parameters**

- `eventName` (string): The event to trigger.
- `options` (Object) [optional]: Extra event options.

**Example**

```js
await formKit().field("foo").triggerEvent("blur");
```

# System specs page object

## Form

The FormKit page object component is available to help you write system specs for your forms.

**Parameters**

- `target` (string): The selector of the form.

**Example**

```rb
form = PageObjects::Components::FormKit.new(".my-form")
```

### submit

Submits the form.

**Example**

```rb
form.submit
```

### reset

Resets the form.

**Example**

```rb
form.reset
```

### has_an_alert?

Checks whether the form renders an alert with the given message.

**Example**

```rb
form.has_an_alert?("message")
```

```rb
expect(form).to have_an_alert("message")
```

### has_field_with_name?

Checks whether a field with the given `data-name` exists.

**Example**

```rb
form.has_field_with_name?("foo")
```

### has_no_field_with_name?

Checks whether a field with the given `data-name` is absent.

**Example**

```rb
form.has_no_field_with_name?("foo")
```

### container

Returns a container helper for the named container.

**Example**

```rb
container = form.container("advanced-settings")
container.has_content?("More options")
```

### choose_conditional

Chooses a `ConditionalContent` branch by radio value.

**Example**

```rb
form.choose_conditional("advanced")
```

## Field

The `field` helper allows you to interact with a specific field of a form.

**Parameters**

- `name` (string): The name of the field.

**Example**

```rb
field = form.field("foo")
```

### value

Returns the value of the field.

**Example**

```rb
field.value
```

```rb
expect(field).to have_value("bar")
```

### has_value?

Checks that the field value matches the expected value.

**Example**

```rb
field.has_value?("bar")
```

### checked?

Returns if the control of a checkbox is checked or not.

**Example**

```rb
field.checked?
```

```rb
expect(field).to be_checked
```

### unchecked?

Returns if the control of a checkbox is unchecked or not.

**Example**

```rb
field.unchecked?
```

```rb
expect(field).to be_unchecked
```

### disabled?

Returns if the field is disabled or not.

**Example**

```rb
field.disabled?
```

```rb
expect(field).to be_disabled
```

### enabled?

Returns if the field is enabled or not.

**Example**

```rb
field.enabled?
```

```rb
expect(field).to be_enabled
```

### toggle

Allows toggling a field. Available for `@type="checkbox"`, `@type="password"`, and `@type="toggle"`.

**Example**

```rb
field.toggle
```

### fill_in

Allows filling a field with a given value. Available for `@type="input"`, `@type="input-*"` variants, `@type="password"`, `@type="color"`, `@type="textarea"`, `@type="code"`, and `@type="composer"`.

**Example**

```rb
field.fill_in("bar")
```

### select

Allows selecting a specified value in a field. Available for `@type="select"`, `@type="icon"`, `@type="menu"`, `@type="radio-group"`, `@type="question"`, tag choosers, and custom multi-select controls.

**Example**

```rb
field.select("bar")
```

### accept

Allows accepting a field. Only available for: `@type="question"`.

**Example**

```rb
field.accept
```

### refuse

Allows refusing a field. Only available for: `@type="question"`.

**Example**

```rb
field.refuse
```

### upload_image

Takes an image path on the filesystem and uploads it for the field. Only available for the `@type="image"` control.

**Example**

```rb
field.upload_image(image_file_path)
```

### has_errors?

Checks that the field renders the given error messages.

**Example**

```rb
field.has_errors?("Required")
```

### has_no_errors?

Checks that the field has no errors.

**Example**

```rb
field.has_no_errors?
```

### has_selected_names?

Checks the selected names for a `@type="tag-chooser"` field.

**Example**

```rb
field.has_selected_names?("support", "meta")
```
