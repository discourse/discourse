# UI Kit - Deferred Components

These components were excluded because form-kit has its own implementations that don't import them.
This decision is tentative - we may want to move them to ui-kit later and have form-kit depend on them, or deprecate them.

| Component | form-kit counterpart | Why deferred |
|-----------|---------------------|--------------|
| `text-field` | `fk/control/input` | form-kit has its own, doesn't import this |
| `number-field` | `fk/control/input` type="number" | form-kit has its own |
| `password-field` | `fk/control/password` | form-kit has its own |
| `radio-button` | `fk/control/radio-group` | form-kit has its own |
| `expanding-text-area` | `fk/control/textarea` | form-kit has its own |
| `char-counter` | `fk/char-counter` | form-kit has its own |
| `color-picker` + `color-picker-choice` | `fk/control/color` | form-kit has its own |
