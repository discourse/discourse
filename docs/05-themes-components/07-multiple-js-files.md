---
title: Split up theme Javascript into multiple files
short_title: Multiple JS files
id: multiple-js-files

---
Complex theme javascript can be split into multiple files, to keep things nicely organised. 

To use this functionality, simply add files to the `/javascripts` folder in your theme directory. Currently, these files can not be edited from the Discourse UI, so you must use the [Theme CLI](https://meta.discourse.org/t/discourse-theme-cli-console-app-to-help-you-build-themes/82950) or [source the theme from git](https://meta.discourse.org/t/how-to-source-a-theme-from-a-private-git-repository/82584). 

Javascript files are treated exactly the same as they are in core/plugins, so you should follow the same file/folder structure. Theme files are loaded after core/plugins, so if the filenames match, the theme version will take precedence.

---

As an example, you can now accomplish https://meta.discourse.org/t/adding-to-plugin-outlets-using-a-theme/32727 by adding a single file to your theme:


**`/javascripts/mytheme/connectors/discovery-list-container-top/add-header-message.hbs`**

```handlebars
Welcome {{currentUser.username}}. Please visit <a class="nav-link " href="http://google.com" target="_blank">My Site</a>
```

To add a connector class, add another file

**`/javascripts/mytheme/connectors/discovery-list-container-top/add-header-message.js`**
```javascript
import { isAppleDevice } from "discourse/lib/utilities";

export default {
  shouldRender(args, component) {
    return isAppleDevice();
  }
};
```

---

If you want to simply move some existing theme javascript out of a `<script type="text/discourse-plugin"` block, you should wrap it in an initializer like this:

**`/javascripts/mytheme/initializers/initialize-stuff.js`**

```javascript
import { withPluginApi } from "discourse/lib/plugin-api";
export default {
  name: "my-initializer",
  initialize(){
    withPluginApi("0.8.7", api => {
      // Do something with the API here
    });
  }
}
```

---

If you need a totally different `.js` asset (e.g. for a web worker), check out [this topic](https://meta.discourse.org/t/discourse-theme-components-now-support-wasm/223574?u=david).
