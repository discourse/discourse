# Data flow: two-way bindings, call sites, inputs

Classic components let a child write into its parent through any arg. Glimmer args are
read-only (`this.args` is frozen in development, and a write is a silent no-op in
production), so every such write becomes an explicit callback. This is the only part of a
conversion that changes the component's interface, and the one that must be designed per
case. Nothing here is mechanical.

## 1. Find the writes

A two-way binding exists when the component writes to a name that a caller passes as an
arg. Sources of writes. `scripts/analyze.sh` lists 1, 2, and 4, and greps the template for
the common entries of 3; check the rest of `MUTATING_COMPONENTS` by hand:

1. `this.set("x", v)`, `this.setProperties({ x })`, `this.toggleProperty("x")`,
   `this.x = v`, `this.incrementProperty("x")`.
2. Template writes: `{{mut this.x}}`, `(fn (mut this.x))`, `<Input @value={{this.x}}>`,
   `<Textarea @value={{this.x}}>`, `<Input @checked={{this.x}}>`.
3. Passing `this.x` into a component that mutates its arg when no callback is given. The
   full list is `MUTATING_COMPONENTS` in
   `node_modules/@discourse/lint-configs/eslint-rules/no-unnecessary-tracked.mjs`; read it
   rather than a copy here. Common entries: `@value` on `Input`, `Textarea`, `DTextarea`,
   `TextField`, `DTextField`, `DDatePicker`; `@checked` on `Input`, `PreferenceCheckbox`;
   `@selection` on `DRadioButton`; `@tags` on `TagChooser`. Add select-kit without
   `@onChange` (deprecated implicit mutation: `this.set("value", v)` in `select-kit.js`
   `_deprecateMutations`). When the value passed is a path into an arg's object
   (`@value={{this.composer.title}}`), it is case 4, not a binding of the arg.
4. Writes to a *property of* an arg: `this.set("model.x", v)`, `this.args.model.x = v`,
   `set(this, "model.x", v)`, and the template form `<Input @value={{this.model.x}}>` /
   `<DTextField @value={{this.composer.title}}>`. Not a two-way binding of the arg itself;
   see 3.3.

A component whose class body is empty still counts: `{{fn (mut this.value)}}` or
`@value={{this.value}}` in the template of a class with no `value` field is a two-way
binding on an arg, and turning the file into a template-only component keeps it alive as
`(mut @value)`. Read the template before calling a conversion trivial.

Cross each write with the call sites: the name is an arg if any invocation passes
`@x=`. A name nobody passes is own state, not a binding, even when the classic class never
declared it: declare the field and apply SKILL.md Step 2.3 for `@tracked`. It drops out of
this reference.

## 2. Find who reads it back

For each written arg, look at every call site's owner (the parent component, controller,
or route template) and answer: after the child writes, does the parent read the value?
Signs: the parent renders `{{this.x}}`, passes `this.x` to another component, has a
`@computed`/getter over it, sends it in a request, or a test asserts on it.

## 3. Choose the redesign

### 3.1 Nobody reads it back: drop the binding

The parent passed a starting value and never looked again. The child keeps a local
`@tracked` field seeded from the arg and stops writing upward.

```js
// before: this.set("selectedTopicId", topic.id) with @selectedTopicId passed but never read
// after
@tracked selectedTopicId = this.args.selectedTopicId;
```

A copy made in a field initializer or the constructor runs once and never follows later
arg changes; that is only right when the parent stops changing the value. If the arg can
change later and the local copy must follow it, use
`@resettableTracked selectedTopicId = this.args.selectedTopicId;` instead, or lift the
state to the parent.

### 3.2 The parent reads it back: add a callback

The parent owns the state; the child asks. Name the callback for the event, not the
property, and pass the new value as the argument.

```hbs
{{! before (b1b218aa992, choose-topic) }}
<ChooseTopic @selectedTopicId={{this.selectedTopicId}} />
{{! after }}
<ChooseTopic @topicChangedCallback={{this.newTopicSelected}} />
```

```js
// child
@action chooseTopic(topic) { this.args.topicChangedCallback?.(topic); }
// parent (classic controller or component): @action newTopicSelected(topic) { this.set("selectedTopicId", topic.id); }
// parent (Glimmer): @action newTopicSelected(topic) { this.selectedTopicId = topic.id; }   // @tracked
```

When the child set several independent flags, one setter arg each is the smallest change
(`c18e5d1698c`; the state lives on classic controllers, so their route templates pass
`mut`):

```hbs
{{! before, templates/email-login.hbs }}
<SecurityKeyForm @showSecurityKey={{this.showSecurityKey}} @showSecondFactor={{this.showSecondFactor}} />
{{! after }}
<SecurityKeyForm @setShowSecurityKey={{fn (mut this.showSecurityKey)}} @setShowSecondFactor={{fn (mut this.showSecondFactor)}} />
```

`{{fn (mut this.x)}}` at a call site is acceptable when the caller is classic or a
template with no backing class. A Glimmer caller passes an `@action` that assigns a
`@tracked` field, adding one if none exists. A Glimmer component that only relays the arg
forwards the setter unchanged (`@setShowSecurityKey={{@setShowSecurityKey}}`, as
`local-login-form` does in that commit). `(fn (mut @x))` inside the *converted* component
would write through to its own caller and reintroduce the hidden binding; `mut` belongs
only at the call site that owns the state.

The old `@x` arg is usually still needed for the initial value. Keep it as read-only
input and add the callback next to it: `@value={{this.x}} @onChange={{this.setX}}` is the
Discourse-wide shape (select-kit, DTextField, form-kit).

### 3.3 Writes into an arg's object: not a binding

`this.set("composer.title", v)` mutates the shared model the parent passed. Keep it:
`this.args.composer.set("title", v)` for `EmberObject`/`RestModel`, plain assignment for
tracked models. Reactivity depends on the model declaring the property; check the model
before assuming a getter over it updates. This is not DDAU-pure, but it is the same
amount of code and the same behavior, so it stays.

### 3.4 Editable local copy with reset

Forms that let the user edit a value and then submit or cancel:

```js
@resettableTracked value = this.args.checked;          // follows the arg until the user edits
get changed() { return !!this.args.checked !== !!this.value; }
@action reset() { this.value = this.args.checked; }
// submit: <DButton @action={{fn @action this.value}} />   the parent applies the value
```

(`f3c6260e1b3`, inline-edit-checkbox). Without reset semantics, the fallback shape is
`@tracked _x; get x() { return this._x ?? this.args.x; }` with a setter.

### 3.5 Yielded state

A classic component that yielded an `EmberObject` (`info`) which the block mutated
(`info.toggleProperty("expanded")`) becomes a small tracked class plus a yielded action
(`991cbda4528`): `{{yield this.info this.toggleProgressExpansion}}`, and the block calls
the action instead of writing into `info`.

## 4. Update the call sites

For every invocation (core, bundled plugins, tests):

1. Add the callback arg; remove the arg if it was write-only.
2. Replace `@classNames=`, `@class=`, `@id=`, `@elementId=`, `@tagName=` with attributes.
3. Replace string action names with functions.
4. Check the parent's own state is reactive: a Glimmer parent needs `@tracked` on the field
   the callback assigns; a classic parent uses `this.set` inside the action.
5. If the parent is a route template (`app/templates/*.gjs`), the state lives on the
   controller: `@onChange={{@controller.someAction}}` or `{{fn (mut @controller.x)}}`.

Then the plugin outlet args: `@outletArgs={{lazyHash x=this.x}}` becomes `x=@x` for args
and `x=this.x` for own state; forgetting this renders `undefined` silently.

## 5. Built-in inputs inside the converted component

`<Input @value={{this.x}}>`, `<Textarea @value={{this.x}}>`, `<Input @checked={{this.x}}>`
write to whatever `this.x` resolves to.

- `x` is own state: keep it, declared `@tracked`. `discourse/no-unnecessary-tracked` counts
  `@value`/`@checked` on these components as a write, so it does not warn. Do not leave it a
  plain field: the input writes with `set()`, which only invalidates direct template reads
  of `this.x`; a getter over it never re-evaluates, and a `this.x = v` in JS leaves the
  template stale (and trips the mandatory-setter assertion in development).
- `x` is a path into an arg's object (`@value={{this.composer.title}}`): this is 3.3.
  Keep `@value={{@composer.title}}`; the input writes into the shared model exactly as
  before, and the component stays (`DTextField`, `DTextarea`), so selectors do not change.
- `x` was an arg itself: `@value={{@x}}` would write through the reference to the caller's
  property, hiding the binding. Replace with a native element and a callback:

    ```hbs
    <input type="text" value={{@value}} {{on "input" (withEventValue @onChange)}} />
    <input type="checkbox" checked={{@checked}} {{on "change" (withEventValue @onChange "target.checked")}} />
    ```

`withEventValue` is `discourse/helpers/with-event-value`. `DTextField` and `DTextarea`
expose `@onChange`; select-kit expects `@value` + `@onChange`.

## 6. `{{action}}` and `{{mut}}` leftovers at call sites

`{{action}}` and `(action)` no longer exist in Ember; they work here only through the
compatibility shim in `lib/ember-events.js` and `helpers/action.js`, which logs a
deprecation on every use. Leftovers at any call site you edit are replaced, not carried
over.

| Found at a call site | Replace with |
|---|---|
| `@action="saveThing"` (string) | `@action={{this.saveThing}}` |
| `{{action "x"}}` / `(action "x" arg)` | `{{on "click" this.x}}` / `(fn this.x arg)` |
| `onclick={{action ...}}` | `{{on "click" ...}}` (and `preventDefault` if a link) |
| `@onChange={{action (mut this.x)}}` | `@onChange={{fn (mut this.x)}}` or an `@action` |
| `@value={{readonly this.x}}` | `@value={{this.x}}` once the child is Glimmer |

## 7. Report the interface change

List in the reply, per arg: old contract (`@x` two-way), new contract (`@x` read-only +
`@onX(value)`), every call site edited, and every external call site that needs the same
edit. A reviewer should be able to check the change from the list alone.
