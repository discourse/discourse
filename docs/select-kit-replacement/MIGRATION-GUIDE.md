# Third-party migration guide (notes)

Notes for the guide published on Meta for plugin and theme developers (PHASE-5, "Third-party
migration guide"). Each entry records what changed, who is affected, how to migrate and what
behaves differently, so the guide can be written from here when the time comes.

## `DTimeInput` is deprecated

Shipped by a standalone PR on `main` (not this branch).

- **Deprecation:** id `discourse.d-time-input`, since `2026.11.0`, reported when a `DTimeInput`
  is created. It keeps working unchanged; no removal date is set.
- **Core's replacement:** `DDateTimeInput` renders a native `<input class="time-input"
  type="time">` instead of `DTimeInput`. Core's other time fields (bookmarks, topic timers, local
  dates, FormKit's calendar control) already used the native input.

### Who is affected

- Code that renders `<DTimeInput>` (`discourse/ui-kit/d-time-input`, or the older
  `discourse/components/time-input` path).
- Classes that extend `DTimeInput`.
- Classes that extend `DDateTimeInput` and rely on its template: the time field is now
  `input.time-input`, not a select-kit `.d-time-input`. Its `date`, `hours`, `minutes`,
  `relativeDate` getters and `onChangeTime` action are unchanged.
- Styles that target `.d-date-time-input .d-time-input` or its `.select-kit-header`.
- Tests that pick a time through select-kit (`selectKit(".d-time-input")`). Use
  `fillIn(".time-input", "14:45")` instead.

### Migrating

The native input's value is the time as `"HH:mm"` in 24-hour form.

| `DTimeInput` argument | Native input |
|---|---|
| `@date` | `value` set to `date.format("HH:mm")` |
| `@hours`, `@minutes` | `value` set to the two, zero-padded, as `"HH:mm"` |
| `@onChange({ hours, minutes })` | the `input` event; split its `"HH:mm"` value into hours and minutes |
| `@relativeDate` | `min` set to the relative time as `"HH:mm"` when both fall on the same day |

```gjs
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";

export default class MyTimeField extends Component {
  get time() {
    return this.args.date?.format("HH:mm");
  }

  @action
  onInputTime(value) {
    if (!value) {
      return;
    }
    const [hours, minutes] = value.split(":").map(Number);
    this.args.onChange({ hours, minutes });
  }

  <template>
    <input
      type="time"
      value={{this.time}}
      {{on "input" (withEventValue this.onInputTime)}}
    />
  </template>
}
```

### What behaves differently

- **No quarter-hour list.** Any minute can be typed. `step="900"` (as FormKit's calendar control
  uses) hints at 15-minute steps.
- **No duration hints** on an end time (the "30 min" and "1h 30 min" labels `@relativeDate`
  added).
- **12 or 24-hour display follows the user's device**, not the Discourse locale. The value is
  always 24-hour `"HH:mm"`.
- **Emptying the field** gives an empty value. `DDateTimeInput` ignores it and keeps the time, as
  `DTimeInput` could not be emptied.

## `DFutureDateInput` renders `DSelect` behind the flag

Shipped on this branch, behind `enable_new_select_controls`.

- **What changed:** with the flag on, `DFutureDateInput` (and the old
  `discourse/components/future-date-input` path) renders its shortcut list as a typeahead `DSelect`
  instead of `FutureDateInputSelector`. Its arguments and the value it emits are unchanged, apart
  from clearing (below). It takes a new `@ariaLabel` to name the select where no `@label` is
  shown.
- **`FORMAT`** now lives in `discourse/lib/time-shortcut`. The old
  `discourse/select-kit/components/future-date-input-selector` module still re-exports it.

### Who is affected

- Styles that target `.future-date-input-selector`, `.future-date-input-selector-header`,
  `-row`, `-icons` or `-datetime`. With the flag on, the select is `.future-date-input__select`
  (a `.d-select` with `@identifier="future-date-input"`, which its list carries as
  `data-identifier`); rows are the select's own `[role="option"]` rows with their icon drawn as
  `.d-select__option-icon`, and the trigger's date is `.future-date-input__selection-date`.
- Tests that open it through select-kit (`selectKit(".future-date-input-selector")`,
  `.future-date-input-selector-header`). Use the `DSelect` test helper on
  `.future-date-input .d-select`.
- Code that renders `FutureDateInputSelector` directly. It keeps working with the flag off and goes
  away with select-kit.

### What behaves differently

- **Clearing** empties the caller's date: `@onChangeInput` receives `null`. The old header had no
  clear button, so `@clearable` had no effect before.
- **The list can be searched.** Typing matches a shortcut's name or its date.
- **Each row's date** is the option's description. It sits beside the name when the row has room
  and wraps under it when it doesn't.
