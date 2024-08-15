---
title: Using modifyClass for objects which are initialized early in boot
short_title: ModifyClass
id: modifyclass

---
When using modifyClass in an initializer, you may see this warning in the console:

> Attempted to modify "{name}", but it was already initialized earlier in the boot process (e.g. via a lookup()). Remove that lookup, or move the modifyClass call earlier in the boot process for changes to take effect.

In theme/plugin development, there are two ways this error is normally introduced:

### Adding a `lookup()` caused the error

If you `lookup()` a singleton too early in the boot process, it will cause any later `modifyClass` calls to fail. In this situation, you should try to move the lookup to happen later. For example, you would change something like this:

```js
// Lookup service in initializer, then use it at runtime (bad!)
export default apiInitializer("0.8", (api) => {
  const composerService = api.container.lookup("service:composer");
  api.composerBeforeSave(async () => {
    composerService.doSomething();
  });
});
```


To this:

```js
// 'Just in time' lookup of service (good!)
export default apiInitializer("0.8", (api) => {
  api.composerBeforeSave(async () => {
    const composerService = api.container.lookup("service:composer");
    composerService.doSomething();
  });
});
```

## Adding a new `modifyClass` caused the error

If the error is introduced by your theme/plugin adding a `modifyClass` call, then you'll need to move it earlier in the boot process. This commonly happens when overriding methods on services (e.g. topicTrackingState), and on models which are initialized early in the app boot process (e.g. a `model:user` is initialized for `service:current-user`).

Moving the modifyClass call earlier in the boot process normally means moving the call to a `pre-initializer`, and configuring it to run before Discourse's 'inject-discourse-objects' initializer. For example:

```js
// (plugin)/assets/javascripts/discourse/pre-initializers/extend-user-for-my-plugin.js
// or
// (theme)/javascripts/discourse/pre-initializers/extend-user-for-my-plugin.js

import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "extend-user-for-my-plugin",
  before: "inject-discourse-objects",

  initializeWithApi(api){
    api.modifyClass("model:user", {
      myNewUserFunction() {
        return "hello world";
      }
    });
  },

  initialize() {
    withPluginApi("0.12.1", this.initializeWithApi);
  },
};
```

This modification of the user model should now work without printing a warning, and the new method will be available on the currentUser object.
