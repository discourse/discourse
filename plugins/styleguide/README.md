# styleguide

Adds a URL of `/styleguide` to discourse that renders widgets in various
configurations to aid in styling.

![Screenshot](screenshot.png)

## Code examples

Discourse's build pipeline allows adding `?source=file` or `?source=template` to
a module import. This provides a string of the raw source code for the entire
file, or just for the `<template>`. Put the example in its own module under
`examples/`, import it twice, and pass the string to `@code`:

```gjs
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CharCounterExample from "../../examples/molecules/char-counter";
import charCounterSource from "../../examples/molecules/char-counter?source=file";

export default <template>
  <StyleguideExample @title="<DCharCounter>" @code={{charCounterSource}}>
    <CharCounterExample />
  </StyleguideExample>
</template>
```

The import must resolve within the same plugin or theme bundle, and
`?source=template` requires the module to contain exactly one `<template>`.

### Criteria

Samples typed by hand drift from the code they describe. These rules keep that
from being possible.

1. Every `<StyleguideExample>` that passes `@code` passes a `?source=` import,
   never a hand-written string.

2. Each example is its own module under `examples/`. A module may back several
   examples when the variants differ only in the data passed in.

3. Use `?source=file` when the module has imports or JS, so the reader sees
   what to paste into a new file. Use `?source=template` when it is pure markup.

4. The example module holds only the API being taught. Styleguide-only chrome
   stays in the section file, wrapping the example.

5. An example receives only what it cannot build itself. Store-backed records
   come in as named args; literal fixtures, state and callbacks the example
   owns. Examples never take `@dummy` itself.

6. An example demonstrating a design token, a color or a type scale does not
   need `@code` at all.

7. A hand-written `@code` string is admissible only when the sample cannot be a
   module that renders on this page: it is computed from the page's live
   controls, or the block is a gallery rather than a usage example. It must
   carry a comment saying which.

### Layout

```
examples/<group>/<section>/<tab>/<name>.gjs
```

`<group>` is `atoms`, `molecules` or `organisms`; `<section>` is the section
file name without its numeric prefix; `<tab>` is the in-page tab or query-group
slug; and `<name>` is a kebab-case slug for the variant. A section without
in-page tabs omits the `<tab>` directory. Grouping modules under the same tab
slug used by the page keeps the source tree correlated with its navigation.
Import with a relative specifier and no file extension, and name the bindings
`<Name>Example` and `<name>Source`.
