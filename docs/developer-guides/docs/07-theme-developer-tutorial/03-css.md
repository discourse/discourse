---
title: "Theme Developer Tutorial: 3. CSS in Themes"
short_title: 3 - CSS
id: theme-developer-tutorial-css
---

Technically, Discourse uses [SCSS](https://sass-lang.com/) to author its stylesheets. However, we're increasingly moving towards native CSS features as they mature, so the vast majority of themes won't need to use SCSS features or syntaxes. We follow a [variant of BEM for our CSS](https://meta.discourse.org/t/361851), you should be familiar with this when writing theme CSS.

This chapter will focus on Discourse-specific subjects, so if you don't already have a passing familiarity with CSS, take some time to learn about it from https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Styling_basics.

## Authoring theme CSS

As we touched on in the last chapter, the main entrypoint for theme CSS is the `common/common.scss` file. For many themes, that's all you'll need.

You can also use `desktop/desktop.scss` and `mobile/mobile.scss`, although we're increasingly moving away from these separate files and towards breakpoint-based styling in `common.scss`.

But for more complex situations, you can put additional scss in files like `/stylesheets/my-styles.scss`, and import from `common.scss` like `@import "my-styles";`

## Using variables

Discourse makes extensive use of [CSS variables](https://www.w3schools.com/css/css3_variables.asp) for colors, font sizes, and other things which need to be shared throughout the stylesheets. You can find a full list of the color variables [here](https://github.com/discourse/discourse/blob/main/app/assets/stylesheets/color_definitions.scss), font variables [here](https://github.com/discourse/discourse/blob/main/app/assets/stylesheets/common/font-variables.scss). Or alternatively, open your browser dev tools, select the `<html>` element, and scroll through all the available variables.

Let's make use of this knowledge by updating our theme to use the theme colors for the banner! Open up the `common.scss` file, and update the color properties to use variables:

```css
.custom-welcome-banner {
  background: var(--quaternary);
  color: var(--secondary);
  text-align: center;
  padding: 10px;
}
```

`discourse_theme` will sync this change up to your site instantly, and the change should appear in your browser.

Great! Now your banner's colors will match the site color scheme, and automatically adjust based on light/dark modes.

For more information about the variables available, check out [this document](https://meta.discourse.org/t/77551)

## Finding CSS selectors to style

The number of elements and classes in Discourse can feel quite overwhelming from a re-styling standpoint. The key to having a maintainable theme is to keep your changes as small as possible, and match the selectors used in Discourse core's stylesheets.

For example, let's assume you want to style all the buttons in Discourse. One approach would be to use DevTools and try to find every variation of every button and style it. But a better approach would be to see how core is styling buttons, and base your approach on that.

To explore re-styling Discourse in more detail, check out [the Designer's guide to Discourse themes](https://meta.discourse.org/t/152002)

Or if you're ready to explore more ways to add/change content in Discourse, let's go to the [next chapter](https://meta.discourse.org/t/357799)
