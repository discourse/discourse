:warning: This plugin is still in active development and may change frequently

## Documentation

The Discourse Chat plugin adds chat functionality to your Discourse so it can natively support both long-form and short-form communication needs of your online community.

For documentation, see [Discourse Chat](https://meta.discourse.org/t/discourse-chat/230881)

## Plugin API

### registerChatComposerButton

#### Usage

```javascript
api.registerChatComposerButton({ id: "foo", ... });
```

#### Options

Every option accepts a `value` or a `function`, when passing a function `this` will be the `chat-composer` component instance. Example of an option using a function:

```javascript
api.registerChatComposerButton({
  id: "foo",
  displayed() {
    return this.site.mobileView && this.canAttachUploads;
  },
});
```

##### Required

- `id` unique, used to identify your button, eg: "gifs"
- `action` callback when the button is pressed, can be an action name or an anonymous function, eg: "onFooClicked" or `() => { console.log("clicked") }`

A button requires at least an icon or a label:

- `icon`, eg: "times"
- `label`, text displayed on the button, a translatable key, eg: "foo.bar"
- `translatedLabel`, text displayed on the button, a string, eg: "Add gifs"

##### Optional

- `position`, can be "inline" or "dropdown", defaults to "inline"
- `title`, title attribute of the button, a translatable key, eg: "foo.bar"
- `translatedTitle`, title attribute of the button, a string, eg: "Add gifs"
- `ariaLabel`, aria-label attribute of the button, a translatable key, eg: "foo.bar"
- `translatedAriaLabel`, aria-label attribute of the button, a string, eg: "Add gifs"
- `classNames`, additional names to add to the button’s class attribute, eg: ["foo", "bar"]
- `displayed`, hide/or show the button, expects a boolean
- `disabled`, sets the disabled attribute on the button, expects a boolean
- `priority`, an integer defining the order of the buttons, higher comes first, eg: `700`
- `dependentKeys`, list of property names which should trigger a refresh of the buttons when changed, eg: `["foo.bar", "bar.baz"]`
