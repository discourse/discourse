---
title: Include assets (e.g. images, fonts) in themes and components
short_title: Include assets
id: include-assets
---

Themes and theme components allow you to handle uploaded assets such as images and fonts. You can control what assets your theme accepts using the site setting: `theme authorized extensions`

## Including assets in themes and components

### For remote themes

Remote themes include:

- Themes and components installed from the <kbd>Popular</kbd> list of themes
- Themes and components installed using the <kbd>From a git repository</kbd> method

To upload assets to a remote theme or theme component, see https://meta.discourse.org/t/create-and-share-a-font-theme-component/62462 for a detailed example.

### Uploading assets to local themes and components

Local themes include:

- The default Light and Dark themes that ship with every Discourse instance
- Themes and components created using the <kbd>+ Create New</kbd> installation method
- Themes and components that were uploaded from your local computer using the <kbd>From your device</kbd> installation method.

To upload assets to a local theme or theme component, navigate to your theme or component and select <kbd>+ Add</kbd> in the Uploads section:

![uploads|690x143,50%](/assets/include-assets-1.png)

In the Add Upload modal, choose a file and enter a SCSS variable name to use with with your CSS, javascript, and/or handlebars customizations

![upload-modal|683x500,40%](/assets/include-assets-2.png)

Once uploaded, the asset will pop up in the Uploads list:

![uploaded-font|556x230,50%](/assets/include-assets-3.png)

> :warning: **Important Note**: _Do not add uploads to themes and components through the admin interface if the component was installed remotely from a git repository. Updates to the component will clear out any uploads that were not included in the git repository._

## How to make use of the assets

### SCSS

```scss
@font-face {
  font-family: Amazing;
  src: url($Comic-Sans) format("woff2");
}

body {
  font-family: Amazing;
  font-size: 15px;
}

.d-header {
  background-image: url($texture);
}
```

> :information*source: \_When using `ttf` or `otf` fonts, be sure to use a format of `opentype`.*

### Javascript

```gjs
// {theme}/javascripts/discourse/api-initializers/init-theme.gjs

import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  console.log(settings.theme_uploads.balloons);
});
```

### HTML

You can't directly add a theme asset to vanilla HTML (like in the header or after header sections of the customize admin panel). You have to use a handlebars template or the plugin API (more about those in https://meta.discourse.org/t/developer-s-guide-to-discourse-themes/93648).

One workaround is to load your asset as a background image using SCSS (like the example above). So in the header section of your theme you might add:

```html
<div class="my-custom-div">
  <a href="/"></a>
</div>
```

and then in your CSS:

```scss
.my-custom-div a {
  height: 50px;
  width: 100px;
  background-image: url($asset-name);
}
```

### Accessing theme uploads as settings

You may also treat `theme_uploads` as settings in JavaScript ([related commit](https://github.com/discourse/discourse/commit/719a93c312b9caa6c71de22d67f1ce1a78c1c8b2)).

This allows themes and components access to theme assets.

Inside theme js you can now get the URL for an asset with:

```
settings.theme_uploads.name
```

## Additional Information

- https://meta.discourse.org/t/create-and-share-a-font-theme-component/62462
