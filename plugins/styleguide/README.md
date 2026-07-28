# styleguide

Adds a URL of `/styleguide` to discourse that renders widgets in various
configurations to aid in styling.

![Screenshot](screenshot.png)

## Automatic code examples

Discourse's build pipeline allows adding `?source=file` or `?source=template` to
a module import. This provides a string of the raw source code for the entire
file, or just for the `<template>`. Put the example in its own module under
`examples/`, import it twice, and pass the string to `@code`:

```gjs
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CharCounterExample from "../../examples/char-counter";
import charCounterSource from "../../examples/char-counter.gjs?source=file";

export default <template>
  <StyleguideExample @title="<DCharCounter>" @code={{charCounterSource}}>
    <CharCounterExample @dummy={{@dummy}} />
  </StyleguideExample>
</template>
```

The import must resolve within the same plugin or theme bundle, and
`?source=template` requires the module to contain exactly one `<template>`.

Keep using an explicit `@code` string for curated samples that intentionally
differ from the rendered implementation.
