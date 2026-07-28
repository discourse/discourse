# styleguide

Adds a URL of `/styleguide` to discourse that renders widgets in various
configurations to aid in styling.

![Screenshot](screenshot.png)

## Derived example source

When a code sample should exactly match the rendered example, put the example in
its own module under `examples/` and import that module normally. Importing the
same file a second time with a source query yields its contents as a string,
which can be passed straight to `@code`.

Use `?template-source` when only the markup matters. It returns the dedented
contents of the module's `<template>`, and requires the module to contain
exactly one:

```js
import SpinnerSmallExample from "../../examples/spinner-small";
import spinnerSmallSource from "../../examples/spinner-small.gjs?template-source";
```

Use `?source` when the imports or the backing class are part of what the reader
needs. It returns the whole file verbatim, and works on any module, not just GJS:

```js
import CharCounterExample from "../../examples/char-counter";
import charCounterSource from "../../examples/char-counter.gjs?source";
```

Either query must resolve within the same plugin or theme bundle. Keep using an
explicit `@code` string for curated samples that intentionally differ from the
rendered implementation.
