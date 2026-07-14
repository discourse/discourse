Our goal is to add a new `staticModules` flag for themes and plugins. When enabled, only essential modules are eager-loaded by core. Route splitting is also supported. If the staticModules flag is not provided, it should default to the existing behaviour.

`about.json` gets a new 'frontend' section like:

```json
{
  "tests": {
    "requiredPlugins": [
      "discourse-lazy-videos",
      "spoiler-alert"
    ]
  },
  "frontend": {
    "staticModules": true,
    "sharedModules": [
      "discourse/components/channel-title.gjs",
      "discourse/components/chat-channel.gjs",
      "discourse/models/channel-channel.js"
    ],
    "splitAtRoutes": {
      "chat/visualizer": "chat.visualizer",
      "chat/*": "chat.*"
    }
  }
}
```

Theme/plugins entrypoints should look like:
```js
export default {
  ...sharedModules
}

export const compatModules = {

}

export const routes = {
  {
    load: () => import("virtual:route:foo"),
    names: ["foo.one", "foo.two"]
  }
}
```

compatModules should ONLY include initializers, the route-map, plugin-outlet connectors, and any routes/controllers/templates which are not matched by any splitAtRoutes glob.

Route-specific entrypoints look like:

```js
const routeCompatModules = {};
routeCompatModules[`discourse/templates/wizard`] = I,
routeCompatModules[`discourse/routes/wizard`] = W,
routeCompatModules[`discourse/routes/wizard/index`] = K,
routeCompatModules[`discourse/templates/wizard/step`] = te,
routeCompatModules[`discourse/routes/wizard/step`] = re;
export {routeCompatModules as default};
```

Core's `app.js` already adds compatModules via `define()`. It should also add the route definitions to `window._embroiderRouteBundles_`