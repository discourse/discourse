---
title: Split up theme Javascript into multiple files
short_title: Multiple JS files
id: multiple-js-files
---

Complex theme javascript can be split into multiple files, to keep things nicely organised.

To use this functionality, simply add files to the `/javascripts` folder in your theme directory. These files can not be edited from the Discourse UI, so you must use the [Theme CLI](https://meta.discourse.org/t/discourse-theme-cli-console-app-to-help-you-build-themes/82950) or [source the theme from git](https://meta.discourse.org/t/how-to-source-a-theme-from-a-private-git-repository/82584).

Javascript files are treated exactly the same as they are in core/plugins, so you should follow the same file/folder structure. Theme files are loaded after core/plugins, so if the filenames match, the theme version will take precedence.

---

As an example, you can now accomplish https://meta.discourse.org/t/adding-to-plugin-outlets-using-a-theme/32727 by adding a single file to your theme:

**`/javascripts/my-theme/connectors/discovery-list-container-top/add-header-message.gjs`**

```hbs
import Component from "@glimmer/component"; import { service } from
"@ember/service"; export default class HeaderMessage extends Component {
@service currentUser;

<template>
  Welcome
  {{this.currentUser.username}}
</template>
}
```

---

To use the JS API, create an initializer:

**`/javascripts/discourse/api-initializers/init-theme.gjs`**

```js
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // Your code here
});
```

---

If you need a totally different `.js` asset (e.g. for a web worker), check out [this topic](https://meta.discourse.org/t/discourse-theme-components-now-support-wasm/223574?u=david).
