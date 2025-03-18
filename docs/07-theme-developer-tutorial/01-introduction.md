---
title: "Theme Developer Tutorial: 1. Introduction"
short_title: "1 - Introduction"
id: theme-developer-tutorial-intro
---

This tutorial will teach you how to create a Discourse Theme or Theme Component from the ground up. While this topic assumes no previous experience working on Discourse themes, it does assume some prior experience using [HTML](https://developer.mozilla.org/en-US/docs/Learn/HTML/Introduction_to_HTML), [CSS](https://developer.mozilla.org/en-US/docs/Learn/CSS) and [JavaScript](https://developer.mozilla.org/en-US/docs/Learn/JavaScript). It'll also help if you [know your way around GitHub](https://guides.github.com/activities/hello-world/).

## What are Discourse themes?

> A theme or theme component is a set of files packaged together designed to either modify Discourse visually or to add new features.

### Themes

In general, themes are not supposed to be compatible with each other because they are essentially different standalone designs. You can have multiple themes installed, but you can't use two of them at the same time.

### Theme Components

Theme components are geared towards customising one aspect of Discourse. Because of their narrowed focus, theme components are almost always compatible with each other. This means that you can have multiple theme components running at the same time under any theme.

### Technical Differences

Technically, themes and theme components are implemented in very similar ways, so this tutorial applies to both. You can convert from themes to theme-components, and vice-versa, very easily.

### Remote and local themes

Discourse themes and theme components can either be Local or Remote. Local themes are created & stored on a single Discourse installation, and work well for simple community-specific customizations.

Once your theme becomes more complex, or if you want to share it with other communities, it's beneficial to make it a Remote Theme. These are stored on GitHub (or another Git hosting system), and can be installed on any community using the repository URL.

All the themes in the #theme and #theme-component categories are remote themes.

## Getting started with a local theme

Let's kick things off by creating a new local theme! If you have your own Discourse community or [a local development environment](https://meta.discourse.org/t/developing-discourse-using-a-dev-container/336366), then log in as an administrator and visit the Appearance -> Themes and components section of the admin interface, or go directly to `/admin/config/customize/themes`

If you don't have your own community, then you can log into the public ["Theme Creator"](https://meta.discourse.org/t/get-started-with-theme-creator-and-the-theme-cli/108444) community, visit your profile page, and then choose the "Themes" tab.

From there, click the "Install" button, and then choose "Create New" in the popup. Enter a name for your theme, then hit "Create". Once you see your new theme, use the "Edit Code" button.

### Editing Code

The code editor has a number of tabs to add code to your theme. When you open a tab, a short description will tell you what it's for. The most commonly-used ones are:

1. CSS
2. `<head>`
3. Before Header
4. After Header
5. Footer
6. JS

The "show advanced" toggle can be used to show a few more tabs. Some of those are fairly niche, so we won't go into them for this tutorial. You may also notice the "Mobile" and "Desktop" groups. Those exist for historical reasons, but for new development we recommend implementing everything under "Common", and using CSS breakpoints for any device-specific tweaks.

### Hello World

Let's start with a basic local theme. We're going to add a big "Hello World!" banner under the Discourse header. In the "After Header" tab, paste this HTML code:

```html
<div class="hello-world-banner">
  <h2 class="hello-world">Hello World!</h2>
</div>
```

And in the CSS tab, add this:

```scss
.hello-world-banner {
  height: 300px;
  width: 100%;
  background: red;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1em;
}

.hello-world {
  font-size: 8em;
  color: white;
}
```

Now hit the save button, then click "Preview". You should see something like:

![Hello world welcome banner|690x406, 75%](/assets/beginners-guide-12.PNG)

Congratulations! You just created your first Discourse theme! :tada:

### Rendering into an Outlet

"Plugin Outlets" are one of the main ways to customize Discourse. These allow you to add content in thousands of places throughout the user interface. We'll explore these in more detail later, but for now let's render some dynamic content into the `discovery-list-container-top` outlet.

To do this, visit the JS tab of your theme. The code in this tab is a Discourse "API Initializer", and a boilerplate implementation should be filled in for you. To render some content into an outlet, we can use `api.renderInOutlet`, and Ember's `<template>` syntax.

Inside the `apiInitializer`, replace `// your code here` with this:

```gjs
const currentUser = api.getCurrentUser();

api.renderInOutlet(
  "discovery-list-container-top",
  <template>
    <div class="custom-welcome-banner">
      {{#if currentUser}}
        Welcome back @{{currentUser.username}}
      {{else}}
        Welcome to our community
      {{/if}}
    </div>
  </template>
);
```

Then jump back to the CSS tab, and add this new rule:

```css
.custom-welcome-banner {
  background: green;
  color: white;
  text-align: center;
  padding: 10px;
}
```

Now save and refresh the preview. You should see a new dynamic welcome banner just above the topic list! Existing users will be welcomed by their username, and new visitors will see a generic message. Nicely done!

There's a lot going on this example: the JS API, Plugin Outlets, Ember's `<template>` tag, and the handlebars template syntax inside that. Don't worry, we'll continue to explore these concepts in more detail throughout the rest of the tutorial.

Next up, we'll demonstrate how to turn this into a "Remote Theme", and take advantage of the extra features they unlock. [Let's go!](https://meta.discourse.org/t/357797)
