# Reader syntax-highlighting module

`core.min.js` is the unmodified ES module from `@highlightjs/cdn-assets` version
11.12.0, distributed under the accompanying BSD-3-Clause `LICENSE`.

This file is shipped with the plugin so the reader can serve it without production
`node_modules` or changes to core's runtime asset packaging. Language registrations
continue to come from core's `/highlight-js/` endpoint and respect the site's
configured languages.

When core upgrades its highlighting dependency, refresh this module and license
from the matching installed dependency, from the Discourse project root:

```sh
cp frontend/discourse/node_modules/@highlightjs/cdn-assets/es/core.min.js plugins/blog/vendor/highlightjs/core.min.js
cp frontend/discourse/node_modules/@highlightjs/cdn-assets/LICENSE plugins/blog/vendor/highlightjs/LICENSE
node --test plugins/blog/test/browser/*.test.mjs
bin/rspec plugins/blog/spec/requests/syntax_highlighter_spec.rb
```

Update the version above. Preserve the upstream file rather than formatting or
editing it; the served asset URL is derived from its content digest.
