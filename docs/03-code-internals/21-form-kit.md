---
title: Discourse toolkit to render forms.
short_title: FormKit
id: form-kit
---

<div data-theme-toc="true"> </div>

# Basic Usage

FormKit exposes a single component as its public API: `<Form />`. All other elements are yielded as contextual components, modifiers, or plain data.

Every form is composed of one or multiple fields, representing the value, validation, and metadata of a control. Each field encapsulates a control, which is the form element the user interacts with to enter data, such as an input or select. Other utilities, like submit or alert, are also provided.

Here is the most basic example of a form:

```gjs
import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/form";

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
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field @name="age" @title="Age" as |field|>
        <field.Input @type="number" />
      </form.Field>

      <form.Submit />
    </Form>
  </template>
}
```

# Form

## Yielded Parameters

### form

The `Form` component yields a `form` object containing components and helpers.

**Example**

```hbs
<Form as |form|>
  <form.Row as |row|>
    <!-- ... -->
  </form.Row>
</Form>
```

### transientData

`transientData` represents the state of the data at a given time as it's represented in the form, and not yet propagated to `@data`.

> :information_source: This is useful if you want to have conditionals in your form based on other fields.

**Example**

```hbs
<Form as |form transientData|>
  <form.Field @name="amount" as |field|>
    <field.Input @type="number" />
  </form.Field>

  {{#if (gt transientData.amount 200)}}
    <form.Field @name="confirmed" as |field|>
      <field.Checkbox>I know what I'm doing</field.Checkbox>
    </form.Field>
  {{/if}}
</Form>
```

## Properties

### @data

Initial state of the data you give to the form.

**The keys matching the `@name`s of the form's fields will be prepopulated.**

> :information_source: `@data` is treated as an immutable object, following Ember's DDAU pattern. This means when the user enters new data for any of the fields, it will not cause a mutation of `@data`! You can mutate your initial object using `@onSet`.

When working with an object object we recommend to setup your form data object like this:

```
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
  <form.Field @name="foo" as |field|>
    <!-- This input will have "bar" as its initial value -->
    <field.Input />
  </form.Field>
</Form>
```

### @onRegisterApi

Callback called when the form is inserted. It allows the developer to interact with the form through JavaScript.

**Parameters**

- `callback` (Object): The object containing callback functions.
  - `callback.submit` (Function): Function to submit the form.
  - `callback.reset` (Function): Function to reset the form.
  - `callback.set` (Function): Function to set a key/value on the form data object.
  - `callback.setProperties` (Function): Function to set an object on the form data object.
  - `callback.isDirty` (boolean): Tracked property return the state of the form. It will be true once changes have been done on the form. Reseting the changes will bring it back to false.

**Example**

```javascript
registerAPI({ submit, reset, set }) {
  // Interact with the form API
  submit();
  reset();
  set("foo", 1);
}
```

```hbs
<Form @onRegisterApi={{this.registerAPI}} />
```

### @onSubmit

Callback called when the form is submitted **and valid**.

**Parameters**

- `data` (Object): The object containing the form data.

**Example**

```javascript
handleSubmit({ username, age }) {
  console.log(username, age);
}
```

```hbs
<Form @onSubmit={{this.handleSubmit}} as |form|>
  <form.Field @name="username" as |field|>
    <field.Input />
  </form.Field>
  <form.Field @name="age" as |field|>
    <field.Input @type="number" />
  </form.Field>
  <form.Submit />
</Form>
```

### @validate

A custom validation callback added directly to the form.

**Example**

```javascript
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

```javascript
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

# Field

## @name

A field must have a unique name. This name is used to set the value on the data object and is also used for validation.

**Example**

```hbs
<form.Field @name="foo" />
```

## @title

A field must have a title. It will be displayed above the control and is also used in validation.

**Example**

```hbs
<form.Field @title="Foo" />
```

## @description

The description is optional and will be shown under the title when set.

**Example**

```hbs
<form.Field @description="Bar" />
```

## @showTitle

By default, the title will be shown on top of the control. You can choose not to render it by setting this property to `false`.

**Example**

```hbs
<form.Field @showTitle={{false}} />
```

## @disabled

A field can be disabled to prevent any changes to it.

**Example**

```hbs
<form.Field @disabled={{true}} />
```

## @validation

Read the dedicated validation section.

## @validate

Read the dedicated custom validation section.

## @onSet

By default, when changing the value of a field, this value will be set on the form's internal data object. However, you can choose to have full control over this process for a field.

**Example**

```javascript
@action
handleFooChange(value, { set }) {
  set("foo", value + "-bar");
}
```

```hbs
<form.Field @name="foo" @onSet={{this.handleFooChange}} as |field|>
  <field.Input />
</form.Field>
```

> :information_source: You can use `@onSet` to also mutate the initial data object if you need more reactivity for a specific case.

**Example**

```javascript
@action
handleFooChange(value, { set }) {
  set("foo", value + "-bar");
  this.model.foo = value + "-bar";
}
```

```hbs
<Form @data={{this.model}} as |form|>
  <form.Field @name="foo" @onSet={{this.handleFooChange}} as |field|>
    <field.Input />
  </form.Field>
</Form>
```

# Controls

Controls, as we use the term here, refer to the UI widgets that allow a user to enter data. In its most basic form, this would be an input.

> :information_source: You can pass down HTML attributes to the underlying control.

**Example**

```hbs
<Form as |form|>
  <form.Field
    @name="query"
    @title="Query"
    @description="You should make sure the query doesn’t include bots."
    as |field|
  >
    <field.Input placeholder="Foo" />
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

**Example**

```hbs
<form.Field @name="bar" @title="Bar" @format="small" as |field|>
  <field.Input />
</form.Field>
```

Additionally, the following CSS variables are provided to customize these defaults:

- small: `--form-kit-small-input`
- medium: `--form-kit-medium-input`
- large: `--form-kit-large-input`

## Checkbox

Renders an `<input type="checkbox">` element.

> :information_source: When to use a single checkbox
> There are only 2 options: yes/no. It feels like agreeing to something. Checking the box doesn’t save; there is a submit button further down.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="approved" @title="Approved" as |field|>
    <field.Checkbox />
  </form.Field>
</Form>
```

## Code

Renders an `<AceEditor />` component.

### @height

Sets the height of the editor.

### @lang

Sets the language of the editor.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="query" @title="Query" as |field|>
    <field.Code @lang="sql" @height={{400}} />
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
  <form.Field @name="message" @title="Message" as |field|>
    <field.Composer @height={{400}} />
  </form.Field>
</Form>
```

## Icon

Renders an `<IconPicker />` component.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="icon" @title="Icon" as |field|>
    <field.Icon />
  </form.Field>
</Form>
```

## Image

Renders an `<UppyImageUploader />` component.

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
    @onSet={{this.handleUpload}}
    as |field|
  >
    <field.Image />
  </form.Field>
</Form>
```

**Example**

```hbs
<Form as |form|>
  <form.Field @name="upload" @title="Upload" as |field|>
    <field.Image />
  </form.Field>
</Form>
```

## Input

Renders an `<input>` element.

### @type

Optional property which will default to `text`. Maps to `<input>` types.

### Allowed Types

- `color`
- `date`
- `datetime-local`
- `email`
- `hidden`
- `month`
- `number`
- `password`
- `range`
- `search`
- `tel`
- `text`
- `time`
- `url`
- `week`

### Special Cases

- `file` is supported only for images through image
- checkbox

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="email" @title="Email" as |field|>
    <field.Input />
  </form.Field>

  <form.Field @name="age" @title="Age" @type="number" as |field|>
    <field.Input />
  </form.Field>
</Form>
```

### @before

Renders text before the input

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="email" @title="Email" @before="mailto:" as |field|>
    <field.Input />
  </form.Field>
</Form>
```

### @after

Renders text after the input

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="email" @title="Email" @after=".com" as |field|>
    <field.Input />
  </form.Field>
</Form>
```

## Menu

Renders a <DMenu /> component.

### @selection

The text to show on the trigger.

### yielded parameters

#### Item

Renders a selectable row. Accepts `@value`, `@icon` and `@action` props.

- @value: allows to assign a value to a row.
- @icon: shows an icon at the start of the row.
- @action: override the default action which would set the value of the field with the value of this row.

The content will be yieled.

#### Divider

Renders a separator.

#### Container

Renders a div which will have for content the yielded content.

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="email" @title="Email" as |field|>
    <field.Menu as |menu|>
      <menu.Item @value={{1}} @icon="pencil-alt">Edit</menu.Item>
      <menu.Divider />
      <menu.Container class="foo">
        Bar
      </menu.Container>
      <menu.Item @action={{this.doSomething}}>Something</menu.Item>
    </field.Menu>
  </form.Field>
</Form>
```

## Password

Renders an `<input />` of type password. This control also includes a button which will allow to toggle the visibility of the text. When toggle the type of the input will be switched to text.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="secret" @title="Secret" as |field|>
    <field.Password />
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
  <form.Field @name="email" @title="Email" as |field|>
    <field.Question @yesLabel="Correct" @noLabel="Wrong" />
  </form.Field>
</Form>
```

## RadioGroup

Renders a list of radio buttons sharing a common name.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="foo" @title="Foo" as |field|>
    <field.RadioGroup as |radioGroup|>
      <radioGroup.Radio @value="one">One</radioGroup.Radio>
      <radioGroup.Radio @value="two">Two</radioGroup.Radio>
      <radioGroup.Radio @value="three">Three</radioGroup.Radio>
    </field.RadioGroup>
  </form.Field>
</Form>
```

### Radio yielded parameters

#### Title

Allows to render a title.

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="foo" @title="Foo" as |field|>
    <field.RadioGroup as |RadioGroup|>
      <RadioGroup.Radio @value="one" as |radio|>
        <radio.Title>One title</radio.Title>
      </RadioGroup.Radio>
    </field.RadioGroup>
  </form.Field>
</Form>
```

#### Description

Allows to render a description.

**Examples**

```hbs
<Form as |form|>
  <form.Field @name="foo" @title="Foo" as |field|>
    <field.RadioGroup as |RadioGroup|>
      <RadioGroup.Radio @value="one" as |radio|>
        <radio.Description>One description</radio.Description>
      </RadioGroup.Radio>
    </field.RadioGroup>
  </form.Field>
</Form>
```

## Select

Renders a `<select>` element.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="fruits" @title="Fruits" as |field|>
    <field.Select as |select|>
      <select.Option @value="1">Mango</select.Option>
      <select.Option @value="2">Apple</select.Option>
      <select.Option @value="3">Coconut</select.Option>
    </field.Select>
  </form.Field>
</Form>
```

## Text

Renders a `<textarea>` element.

### @height

Sets the height of the textarea.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="description" @title="Description" as |field|>
    <field.Textarea @height={{120}} />
  </form.Field>
</Form>
```

## Toggle

Renders a `<DToggleSwitch />` component.

> :information_source: There are only 2 states: enabled/disabled. It should feel like turning something on. Toggling takes effect immediately, there is no submit button.

**Example**

```hbs
<Form as |form|>
  <form.Field @name="allowed" @title="Allowed" as |field|>
    <field.Toggle />
  </form.Field>
</Form>
```

# Layout

Form Kit aims to provide good defaults, allowing you to mainly use fields and controls. However, if you need more control, we provide several helpers: Row and Col, Section, Fieldset, Container and Actions.

You can also use utilities like Submit, Reset,Alert and InputGroup.

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
  <group.Field @name="editable" @title="Editable" as |field|>
    <field.Checkbox />
  </group.Field>
  <group.Field @name="searchable" @title="Searchable" as |field|>
    <field.Checkbox />
  </group.Field>
</form.CheckboxGroup>
```

## Container

`Container` allows you to render a block similar to a field without tying it to specific data. It is useful for custom controls.

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

Input group allows to group multiple inputs together on one line.

**Example**

```hbs
<Form as |form|>
  <form.InputGroup as |inputGroup|>
    <inputGroup.Field @title="Foo" @name="foo" as |field|>
      <field.Input />
    </inputGroup.Field>
    <inputGroup.Field @title="Bar" @name="bar" as |field|>
      <field.Input />
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
      <form.Field @name="foo" @title="Foo" as |field|>
        <field.Input />
      </form.Field>
    </row.Col>
    <row.Col @size={{8}}>
      <form.Field @name="bar" @title="Bar" as |field|>
        <field.Input />
      </form.Field>
    </row.Col>
  </form.Row>
</Form>
```

## Section

`Section` provides a simple way to create a section with or without a title.

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

The object component allows to handle an object in your form.

**Example**

```hbs
<Form @data={{hash foo=(hash bar=1 baz=2)}} as |form|>
  <form.Object @name="foo" as |object name|>
    <object.Field @name={{name}} @title={{name}} as |field|>
      <field.Input />
    </object.Field>
  </form.Object>
</Form>
```

## @name

An object must have a unique name. This name is used as a prefix for the underlying fields.

**Example**

```hbs
<form.Collection @name="foo" />
```

## Nesting

An object can accept a nested Object or Collection.

**Example**

```hbs
<Form @data={{hash foo=(hash bar=(hash baz=1 bol=2))}} as |form|>
  <form.Object @name="foo" as |parentObject|>
    <parentObject.Object @name="bar" as |childObject name|>
      <childObject.Field @name={{name}} @title={{name}} as |field|>
        <field.Input />
      </childObject.Field>
    </parentObject.Object>
  </form.Object>
</Form>

<Form @data={{hash foo=(hash bar=(array (hash baz=1) (hash baz=2)))}} as |form|>
  <form.Object @name="foo" as |parentObject|>
    <parentObject.Collection @name="bar" as |collection index|>
      <collection.Field @name="baz" @title="baz" as |field|>
        <field.Input />
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

The collection component allows to handle array of objects in your form.

**Example**

```hbs
<Form @data={{hash foo=(array (hash bar=1) (hash bar=2))}} as |form|>
  <form.Collection @name="foo" as |collection index|>
    <collection.Field @name="bar" @title="Bar" as |field|>
      <field.Input placeholder={{concat "item-" index}} />
    </collection.Field>
  </form.Collection>
</Form>
```

## @name

A collection must have a unique name. This name is used as a prefix for the underlying fields.

For example, if collection has the name "foo", the 2nd field of the collection with the name "bar", will actually have "foo.1.bar" as name.

**Example**

```hbs
<form.Collection @name="foo" />
```

## @tagName

A collection will by default render as a `<div class="form-kit__collection>`, you can alter this behavior by setting a `@tagName`.

**Example**

```hbs
<form.Collection @name="foo" @tagName="tr" />
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
      <object.Field @name="baz" @title="Baz" as |field|>
        <field.Input />
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
      <child.Field @name="baz" @title="Baz" as |field|>
        <field.Input />
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
    <collection.Field @name="bar" @title="Bar" as |field|>
      <field.Input placeholder={{concat "item-" index}} />
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
    <collection.Field @name="bar" @title="Bar" as |field|>
      <field.Input />
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
<field.Checkbox @name="terms" @validation="accepted" />
```

### Length

Checks that the input’s value is over a given length, or between two length values.

**Example**

```hbs
<field.Input @name="username" @validation="length:5,16" />
```

### Number

Checks if the input is a valid number as evaluated by `isNaN()`.

> :information_source: When applicable, prefer to use the number input: `<field.Input @type="number" />`.

**Example**

```hbs
<field.Input @name="amount" @validation="number" />
```

### Required

Checks if the input is empty.

**Example**

```hbs
<field.Input @name="username" @validation="required" />
```

### URL

Checks if the input value appears to be a properly formatted URL including the protocol. This does not check if the URL actually resolves.

**Example**

```hbs
<field.Input @name="endpoint" @validation="url" />
```

### integer

Checks if the input value is an integer.

**Example**

```hbs
<field.Input @name="age" @validation="integer" />
```

## Combining Rules

Rules can be combined using the pipe operator: `|`.

**Example**

```hbs
<field.Input @name="username" @validation="required|length:5,16" />
```

## Custom Validation

### Field

Field accepts a `@validate` property which allows you to define a callback function to validate the field. Read more about addError in helpers section.

**Parameters**

- `name` (string): The name of the form field being validated.
- `value` (string): The value of the form field being validated.
- `data` (Object): The data object containing additional information for validation.
- `handlers` (Object): An object containing handler functions.
  - `handlers.addError` (Function): A function to add an error if validation fails.

**Example**

```javascript
validateUsername(name, value, data, { addError }) {
  if (data.bar / 2 === value) {
    addError(name, { title: I18n.t(`foo.bar.${name}`), message: "That's not how maths work." });
  }
}
```

```hbs
<form.Field @name="username" @validate={{this.validateUsername}} />
```

### Form

Form accepts a `@validate` property which allows you to define a callback function to validate the form. This will be called for each field of the form.

**Parameters**

- `data` (Object): The data object containing additional information for validation.
- `handlers` (Object): An object containing handler functions.
  - `handlers.addError` (Function): A function to add an error if validation fails.

**Example**

```javascript
validateForm(data, { addError }) {
  if (data.bar / 2 === data.baz) {
    addError(name, { title: I18n.t(`foo.bar.${name}`), message: "That's not how maths work." });
  }
}
```

```hbs
<Form @validate={{this.validateForm}} />
```

# Helpers

Helpers are yielded by some blocks, like Form, or provided as parameters to callbacks. They allow you to interact with the form state in a simple and clear way.

## set

`set` allows you to assign a value to a specific field in the form's data.

**Parameters**

- `name` (string): The name of the field to which the value is to be set.
- `value` (number): The value to be set.

**Example**

```javascript
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

```javascript
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
- `error` (object): The error’s data
  - `title` (string): The title of the error, usually the translated name of the field
  - `message` (string): The error message

**Example**

```javascript
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
<@outletArgs.form.Field @name="bar" as |field|>
  <field.Input />
</@outletArgs.form.Field>
```

## Styling

All FormKit components propagate attributes, allowing you to set classes and data attributes, for example:

```hbs
<Form class="my-form" as |form|>
  <form.Field class="my-field" as |field|>
    <field.Input class="my-control" />
  </form.Field>
</Form>
```

## Custom Control

Creating a custom control is straightforward with the properties yielded by `form` and `field`:

```hbs
<Form as |form|>
  <form.Field class="my-field" as |field|>
    <field.Custom>
      <MyCustomControl id={{field.id}} @onChange={{field.set}} />
    </field.Custom>
  </form.Field>
</Form>
```

### Available Parameters on `form`

| Name  | Description                                                       |
| ----- | ----------------------------------------------------------------- |
| `set` | Allows you to set the value of any field by name: `set("bar", 1)` |

### Available Parameters on `field`

| Name    | Description                                    |
| ------- | ---------------------------------------------- |
| `id`    | ID to be used on the control for accessibility |
| `name`  | Name of the field                              |
| `value` | The value of the field                         |

# Custom Validation

## Field

The Field component accepts a `@validate` property, allowing you to define a callback function for custom field validation. Read more about addError in the helpers section.

**Parameters**

- `name` (string): The name of the form field being validated.
- `value` (string): The value of the form field being validated.
- `data` (Object): The data object containing additional information for validation.
- `handlers` (Object): An object containing handler functions.
  - `handlers.addError` (Function): A function to add an error if validation fails.

**Example**

```javascript
validateUsername(name, value, data, { addError }) {
  if (data.bar / 2 === value) {
    addError(name, { title: I18n.t(`foo.bar.${name}`), message: "That's not how maths work." });
  }
}
```

```hbs
<form.Field @name="username" @validate={{this.validateUsername}} />
```

## Form

The Form component accepts a `@validate` property, allowing you to define a callback function for custom form validation.

**Parameters**

- `data` (Object): The data object containing additional information for validation.
- `handlers` (Object): An object containing handler functions.
  - `handlers.addError` (Function): A function to add an error if validation fails.

**Example**

```javascript
validateForm(data, { addError }) {
  if (data.bar / 2 === data.baz) {
    addError(name, { title: I18n.t(`foo.bar.${name}`), message: "That's not how maths work." });
  }
}
```

```hbs
<Form @validate={{this.validateForm}} />
```

# Javascript assertions

## Form

The form element assertions are available at `assert.form(...).*`. By default it will select the first "form" element.

**Parameters**

- `target` (string | HTMLElement): The form element or selector.

### hasErrors()

Asserts that the form has errors.

**Parameters**

- `message` (string): The description of the test.

**Example**

```javascript
assert.form().hasErrors("the form shows errors");
```

## Field

The field element assertions are available at `assert.form(...).field(...).*`.

**Parameters**

- `name` (string): The name of the field.

**Example**

```javascript
assert.form().field("foo");
```

### hasValue()

Asserts that the `value` of the field matches the `expected` text.

**Parameters**

- `expected` (anything): The expected value.
- `message` (string) [optional]: The description of the test.

**Example**

```javascript
assert.form().field("foo").hasValue("bar", "user has set the value");
```

### isDisabled()

Asserts that the `field` is disabled.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```javascript
assert.form().field("foo").isDisabled("the field is disabled");
```

### isEnabled()

Asserts that the `field` is enabled.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```javascript
assert.form().field("foo").isEnabled("the field is enabled");
```

### hasError()

Asserts that the `field` has a specific error.

**Parameters**

- `error` (string): The error message on the field.
- `message` (string) [optional]: The description of the test.

**Example**

```javascript
assert.form().field("foo").hasError("Required", "it is required");
```

### hasNoErrors()

Asserts that the `field` has no error.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```javascript
assert.form().field("foo").hasNoErrors("it is valid");
```

### exists()

Asserts that the `field` is present.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```javascript
assert.form().field("foo").exists("it has the food field");
```

### doesNotExist()

Asserts that the `field` is not present.

**Parameters**

- `message` (string) [optional]: The description of the test.

**Example**

```javascript
assert.form().field("foo").doesNotExist("it has no food field");
```

### hasCharCounter()

Asserts that the `field` has a char counter.

**Parameters**

- `current` (integer): The current length of the field.
- `max` (integer): The max length of the field.
- `message` (string) [optional]: The description of the test.

**Example**

```javascript
assert.form().field("foo").hasCharCounter(2, 5, "it has updated the counter");
```

## Fieldset

The field element assertions are available at `assert.form(...).fieldset(...).*`.

**Parameters**

- `name` (string): The name of the fieldset.

**Example**

```javascript
assert.form().fieldset("foo");
```

### hasTitle()

Asserts that the `title` of the fieldset matches the `expected` value.

**Parameters**

- `expected` (anything): The expected value.
- `message` (string) [optional]: The description of the test.

**Example**

```javascript
assert.form().fieldset("foo").hasTitle("bar", "it has the correct title");
```

### hasDescription()

Asserts that the `description` of the fieldset matches the `expected` value.

**Parameters**

- `expected` (anything): The expected value.
- `message` (string) [optional]: The description of the test.

**Example**

```javascript
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

```javascript
assert.form().fieldset("foo").includesText("bar", "it has the correct text");
```

# Javascript helpers

## Form

The FormKit helper allows you to manipulate a form and its fields through a clear and expressive API.

**Example**

```javascript
import formKit from "discourse/tests/helpers/form-kit";

test("fill in input", async function (assert) {
  await render(<template>
    <Form class="my-form" as |form data|>
      <form.Field @name="foo" as |field|>
        <field.Input />
      </form.Field>
    </Form>
  </template>);

  const myForm = formKit(".my-form");
});
```

### submit()

Submits the associated form.

**Example**

```javascript
formKit().submit();
```

### reset()

Resets the associated form.

**Example**

```javascript
formKit().reset();
```

## Field

**Parameters**

- `name` (string): The name of the field.

### fillIn()

Can be used on [`<field.Input @type="text" />`](/docs/guides/frontend/form-kit/controls/input), [`<field.Code />`](/docs/guides/frontend/form-kit/controls/code), [`<field.Textarea />`](/docs/guides/frontend/form-kit/controls/textarea), and [`<field.Composer />`](/docs/guides/frontend/form-kit/controls/composer).

**Parameters**

- `value` (string | integer | undefined): The value to set on the input.

**Example**

```javascript
await formKit().field("foo").fillIn("bar");
```

### toggle()

Can be used on [`<field.Checkbox />`](/docs/guides/frontend/form-kit/controls/checkbox), [`<field.Toggle />`](/docs/guides/frontend/form-kit/controls/toggle) or [`<field.Password />`](/docs/guides/frontend/form-kit/controls/password)

Will toggle the state of the control. In the case of the password control it will actually toggle the visibility of the field.

**Example**

```javascript
await formKit().field("foo").toggle();
```

### accept()

Can be used on [`<field.Checkbox />`](/docs/guides/frontend/form-kit/controls/question).

**Example**

```javascript
await formKit().field("foo").accept();
```

### refuse()

Can be used on [`<field.Checkbox />`](/docs/guides/frontend/form-kit/controls/question).

**Example**

```javascript
await formKit().field("foo").refuse();
```

### select()

Can be used on [`<field.Select />`](/docs/guides/frontend/form-kit/controls/select), [`<field.Menu />`](/docs/guides/frontend/form-kit/controls/menu), [`<field.Icon />`](/docs/guides/frontend/form-kit/controls/icon), and [`<field.RadioGroup />`](/docs/guides/frontend/form-kit/controls/radio-group).

Will select the given value.

**Parameters**

- `value` (string | integer | undefined): The value to select.

**Example**

```javascript
await formKit().field("foo").select("bar");
```

# System specs page object

## Form

The FormKit page object component is available to help you write system specs for your forms.

**Parameters**

- `target` (string | Capybara::Node::Element): The selector or node of the form.

**Example**

```ruby
form = PageObjects::Components::FormKit.new(".my-form")
```

```ruby
form = PageObjects::Components::FormKit.new(find(".my-form"))
```

### submit

Submits the form

**Example**

```ruby
form.submit
```

### reset

Reset the form

**Example**

```ruby
form.reset
```

### has_an_alert?

Returns if the field is enabled or not.

**Example**

```ruby
form.has_an_alert?("message")
```

```ruby
expect(form).to have_an_alert("message")
```

## Field

The `field` helper allows you to interact with a specific field of a form.

**Parameters**

- `name` (string): The name of the field.

**Example**

```ruby
field = form.field("foo")
```

### value

Returns the value of the field.

**Example**

```ruby
field.value
```

```ruby
expect(field).to have_value("bar")
```

### checked?

Returns if the control of a checkbox is checked or not.

**Example**

```ruby
field.checked?
```

```ruby
expect(field).to be_checked
```

### unchecked?

Returns if the control of a checkbox is unchecked or not.

**Example**

```ruby
field.unchecked?
```

```ruby
expect(field).to be_unchecked
```

### disabled?

Returns if the field is disabled or not.

**Example**

```ruby
field.disabled?
```

```ruby
expect(field).to be_disabled
```

### enabled?

Returns if the field is enabled or not.

**Example**

```ruby
field.enabled?
```

```ruby
expect(field).to be_enabled
```

### toggle

Allows toggling a field. Only available for: [checkbox](/docs/guides/frontend/form-kit/controls/checkbox).

**Example**

```ruby
field.toggle
```

### fill_in

Allows filling a field with a given value. Only available for: [input](/docs/guides/frontend/form-kit/controls/input), [text](/docs/guides/frontend/form-kit/controls/text), [code](/docs/guides/frontend/form-kit/controls/code), and [composer](/docs/guides/frontend/form-kit/controls/composer).

**Example**

```ruby
field.fill_in("bar")
```

### select

Allows selecting a specified value in a field. Only available for: [select](/docs/guides/frontend/form-kit/controls/select), [icon](/docs/guides/frontend/form-kit/controls/icon), [menu](/docs/guides/frontend/form-kit/controls/menu), [radio-group](/docs/guides/frontend/form-kit/controls/radio-group), and [question](/docs/guides/frontend/form-kit/controls/question).

**Example**

```ruby
field.select("bar")
```

### accept

Allows accepting a field. Only available for: [question](/docs/guides/frontend/form-kit/controls/question).

**Example**

```ruby
field.accept
```

### refuse

Allows refusing a field. Only available for: [question](/docs/guides/frontend/form-kit/controls/question).

**Example**

```ruby
field.refuse
```

### upload_image

Takes an image path on the filesystem and uploads it for the field. Only available for the `Image` control.

**Example**

```ruby
field.upload_image(image_file_path)
```
