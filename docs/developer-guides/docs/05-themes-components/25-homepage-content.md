---
title: Add custom content that only appears on your homepage
short_title: Homepage content
id: homepage-content
---

A very common situation you'll find yourself in as a theme developer is the need to create content that only shows on the homepage of your community.

You might add some HTML to the "After Header" section of your theme, which will then appear on every page. You can jump through some hoops in CSS to hide this everywhere except the homepage… but instead let's use a Discourse theme to create a component with content that is only visible on your homepage.

If you're unfamiliar with Discourse themes check out https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966 and https://meta.discourse.org/t/structure-of-themes-and-theme-components/60848

In your Discourse theme you'll need to setup the following directory structure:

:file_folder: `javascripts/discourse/components/`
:file_folder: `javascripts/discourse/connectors/`

From here we're going to create an Ember component. You can find more about Ember components from their documentation: https://guides.emberjs.com/release/

But for now this will be a simple component. The component will consist of two files, one containing the logic and another the template.

:page_facing_up: `javascripts/discourse/components/custom-homepage-content.js`

```js
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";

export default class CustomHomepageContent extends Component {
  @service router;

  get isHomepage() {
    const { currentRouteName } = this.router;
    return currentRouteName === `discovery.${defaultHomepage()}`;
  }
}
```

This creates a `isHomepage` getter, which checks the router service for the `currentRouteName` — if the route name matches your homepage (as dictated by site settings) then it will return `true`

Now we need our template

:page_facing_up: `javascripts/discourse/components/custom-homepage-content.hbs`

```hbs
{{#if this.isHomepage}}
  <h1>This is my homepage HTML content</h1>
{{/if}}
```

The template checks the `isHomepage` getter, and will display your content if it's `true`. You can add any HTML you want between the `{{#if}}` blocks.

Now that our component is created, we need to add it to Discourse somewhere. For this step you'll need to decide which plugin outlet to utilize. These are areas throughout Discourse where we've added a little code for developers to hook into. You can [search Discourse for these on Github](https://github.com/search?q=repo%3Adiscourse%2Fdiscourse+%3CPluginOutlet&type=code), or browse for them using the https://meta.discourse.org/t/plugin-outlet-locations-theme-component/100673/1/.

For custom homepages, [above-main-container](https://github.com/discourse/discourse/blob/4cb3412a56574b3f5de7ca518c68805daddd39c5/app/assets/javascripts/discourse/app/templates/application.hbs#L48) is a common choice, so let's use that.

We need to create our connector file in the correct directory:

:page_facing_up: `javascripts/discourse/connectors/above-main-container/custom-homepage-connector.hbs`

```hbs
<CustomHomepageContent />
```

:point_up: and that's all, it just needs a single line calling for your component :tada:

![Screenshot 2023-06-13 at 1.06.13 PM|690x109](/assets/homepage-content-1.png)
