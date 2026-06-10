---
title: Replace Discourse's default SVG icons with custom icons in a theme
short_title: Custom icons
id: custom-icons
---

You can replace a Discourse's default SVG icons individually or as a whole with your own custom SVG and override them [within a theme or theme component.](https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966#create-new-themes-and-theme-components-7)

# Step 1 - Create an SVG Spritesheet

To get started, you must create an SVG Spritesheet. This can contain anything from a single additional custom SVG icon up to an entire replacement set of hundreds.

The spritesheet should be saved as an SVG file. In principle, you are nesting the `<svg>` tag contents from the original SVG icon file into `<symbol>` tags and giving them a nice identifier.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" style="display: none;">
  <symbol id="my-theme-icon-1">
    <!--
      Code inside the <svg> tag from the source SVG icon file
      this is typically everything between the <svg> tags
      (but not the SVG tag itself, that's replaced by <symbol> above)
      You can transfer any attributes (i.e. ViewBox="0 0 0 0") to the <symbol> tag
      -->
  </symbol>

  <symbol id="my-theme-icon-2">
    <!-- SVG code here. Add more <symbol> blocks as needed.
      -->
  </symbol>
</svg>
```

- Be sure to add a custom ID to each symbol in the spritesheet. It's probably helpful for your sanity to prefix your IDs with your theme name `my-theme-icon`.

- To have the icon color to be dynamic like the existing icons, set the fill to `currentColor` rather than a hardcoded color (like #333)

- To scale or correctly centre your icon, utilise a `viewBox` attribute on the `<symbol>` tag. See https://css-tricks.com/scale-svg/#:~:text=The%20viewBox%20is%20an%20attribute,%2C%20y%2C%20width%2C%20height.&text=Likewise%2C%20the%20height%20is%20the,to%20fill%20the%20available%20height for more information.

- Be on the lookout for style collisions within your SVGs. For example, SVGs will often have an inline style like `.st0{fill:#FF0000;}` defined. If you have multiple SVGs using the same classes this can cause issues (to fix these issues, edit the classes to be unique to each icon).

- If you have many icons, there are ways to automate this. https://www.npmjs.com/package/svg-sprite-generator is a simple command line tool for combining SVGs into a spritesheet.

### Example - single custom icon spritesheet

```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" style="display: none;">
  <symbol id="bat-icon" viewBox="6 6 36 36">
    <path
      fill="currentColor"
      d="M24,18.2c0.7,0,0.9,0.2,0.9,0.2l0.4-1.7c0,0,0.4,1.5,0.4,2.8c0.2,1.1,2.2,0.4,3.9,0C31.4,19.1,32,16,32,16h16c0,0-9.4,3.5-7,10c0,0-14.8-2-17,7l0,0c-2.2-9-17-7-17-7c2.4-6.5-7-10-7-10h16c0,0,0.6,3.1,2.3,3.5c1.7,0.4,3.9,1.1,3.9,0c0.2-1.1,0.4-2.8,0.4-2.8l0.4,1.7C23.1,18.4,23.4,18.2,24,18.2L24,18.2L24,18.2z"
    />
  </symbol>
</svg>
```

# Step 2 - Add the spritesheet to your theme

Once your spritesheet is built, you need to add the SVG file to your component/theme. This is easy via the UI, or you can hard code it into a component/theme.

> :information_source: Once it is uploaded to any installed component/theme, it is available throughout your instance using the ID in the `<symbol>` tag.

### Via the UI

Go to the Uploads section of the theme/component settings and add your sprite file with a SCSS var name of `icons-sprite`:

> ![image|334x260, 75%](/assets/custom-icons-1.png)

### Hardcode into a Theme / Component

Add the spritesheet file to the Theme's `/assets` folder. Then update your assets.json file in the root folder.
For an SVG sprite called `my-icons.svg`, your about.json should include this:

```json
"assets": {
  "icons-sprite": "/assets/my-icons.svg"
}
```

# Step 3 (optional) - Overriding default icons

Now that your spritesheet is set, you can tell Discourse to replace icons. This is how you do it from an api-initializer:

```gjs
// {theme}/javascripts/discourse/api-initializers/init-theme.gjs

import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.replaceIcon("bars", "my-theme-icon-bars");
  api.replaceIcon("link", "my-theme-icon-link");
  // etc.
});
```

The first ID, `bars`, is the default icon ID in Discourse and the second is the ID of your replacement icon. The easiest way to find an ID of one of our icons is to inspect the icon in your browser.

Here the icon name follows the `d-icon-` prefix. So in this example it's `d-unliked`

![43%20PM|690x138, 75%](/assets/custom-icons-2.png)

Most of our icons follow the icon names from https://fontawesome.com/, but there are exceptions (which is why checking the ID in your inspector is the most reliable method). You can see all the exceptions in the `const REPLACEMENTS` block [here on github](https://github.com/discourse/discourse/blob/0b5d5b0d40ecf4b1588a442598410ea64d7869d5/app/assets/javascripts/discourse-common/addon/lib/icon-library.js#L14).

That's it. You can now style Discourse with your own custom icons!

# Step 4 (recommended for full icon sets) - Declare an `icon_set`

If your theme replaces most of Discourse's icons (a full set like Lucide or Phosphor), per-icon `replaceIcon` calls have a cost: the bundle ships both the replaced default icons and your replacements, and a set with multiple weights ships every weight even though only one is used.

Declaring an `icon_set` in about.json moves the replacement to the server. Each mapped glyph from your sprite is bundled under the canonical icon id, so no `replaceIcon` calls are needed and only the glyphs actually rendered are served. Icons you don't map keep their Discourse defaults.

```json
"assets": {
  "icons-sprite": "/assets/icons-sprite.svg"
},
"icon_set": {
  "map": "/assets/icon-map.json"
}
```

`map` maps a canonical Discourse icon name to a `<symbol>` id in your sprite. It can be an inline object (`{ "bell": "ph-regular-bell" }`) or a path to a JSON file of the same shape.

Map values may contain `{placeholder}` tokens, each resolving from the theme setting of the same name. With `"bell": "ph-{weight}-bell"` and a `weight` setting set to `bold`, the `ph-bold-bell` symbol is served as `bell` - and changing the setting re-resolves the bundle. A set can have any number of variant axes (weight, style, fill, ...), each its own setting. An icon that should always use one variant maps to a fixed id instead (`"heart": "ph-fill-heart"`).

If the theme has a list setting named `ignored_icons`, icons listed there keep their Discourse default glyph, so admins can opt out of the replacement per icon (a well-known setting name, like the `icons-sprite` asset name). Mapped icons that don't resolve to a glyph in your sprite fall back to the default too, and are logged in the server logs to help catch typos.

When an `icon_set` is declared, the declaring theme's sprite is used only as a source for mapped glyphs: symbols no map entry resolves to (such as the other weights) are not bundled. Other themes' sprites and `replaceIcon` keep working as before.

Plugins can declare an icon set too, with the same shape, using the plugin's `svg-icons` sprite as the glyph source and site settings for `{placeholder}` tokens (e.g. `"bell": "ph-{my_plugin_icon_weight}-bell"`):

```ruby
# plugin.rb
register_icon_set(map: "icon-map.json")
```

A theme-declared icon set takes precedence over plugin-registered ones.
