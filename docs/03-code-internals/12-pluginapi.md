---
title: Using the JS API
short_title: JS API
id: pluginapi
---

Discourse's JavaScript API allows themes and plugins to make extensive customizations to the user experience. The simplest way to use it is to create a new theme from the admin panel, click "Edit Code", and then head to the JS tab.

For file-based themes, the API can be used by creating a file in the `api-initializers` directory. For theme's that's `{theme}/javascripts/api-initializers/init-theme.gjs`, and for plugins, it's `{plugin}/assets/javascripts/discourse/api-initializers/init-plugin.js`. The content should be:

```gjs
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // Your code here
});
```

All the available APIs are listed in the [`plugin-api.gjs` source code](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs) in Discourse core, along with a short description and examples.

For a full tuturial, including examples of JS API usage, check out:

https://meta.discourse.org/t/theme-developer-tutorial-1-introduction/357796
