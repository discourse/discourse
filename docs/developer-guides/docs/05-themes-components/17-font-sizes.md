---
title: Change font sizes in your themes
short_title: Font sizes
id: font-sizes
---

## Global font-size changes

The simplest way to change the font size of your entire community would be to override the default value on the HTML element in your theme's CSS, like this:

```css
html {
  font-size: 17px; /* default is 16px */
}
```

Because all of our `font-size` values within `<HTML>` are defined with em units, increasing the font-size on `<HTML>` will proportionately increase the font-size of all other elements (ems are [relative units](https://thecssworkshop.com/lessons/relative-units)).

Discourse also comes with user-selectable text size options that can be changed in each users preferences ([/my/preferences/interface](https://meta.discourse.org/my/preferences/interface)), by default these are:

```
Smallest: 13px
Smaller: 14px
Normal: 16px (default)
Larger: 18px
Largest: 20px
```

When you change the font-size of `<HTML>` as demonstrated above, you're only changing the `Normal` value. So if you want the user text-size settings to continue working in your theme you should also increase the `font-size` for the other options. If you wanted to increase the font-size of all options by 1px, that would look like this:

```css
:root {
  --base-font-size-smallest: 14px;
  --base-font-size-smaller: 15px;
  --base-font-size: 17px;
  --base-font-size-larger: 19px;
  --base-font-size-largest: 21px;
}
```

## Changing font-size of individual components

You might not want to increase the global font-size of your community, and just change the `font-size` of a specific component, like the header or posts. If you're familiar with CSS, you can target individual elements as expected.

For example, to increase the font-size of all the content within a post you can do this:

```css
.topic-post {
  font-size: 1.2em;
}
```

If you wanted to change the text size of the post content, but _not_ the usernames and other metadata you need to be a little more specific (right click on an element and use your browser's inspector if you need to figure out which element to target)...

```css
.topic-post .contents {
  font-size: 1.2em;
}
```

Note that in the above examples I'm using `em` units. You can use `px` values here, but the benefit of ems is that they're relational.

If you used pixel units in the above examples, those font sizes would stay the same even if a user changed the text size setting in their preferences. A static value like 16px is always 16px. But when you use a value like 1.2em, it acts as a multiplier... so if someone chooses a larger text size in their settings the font-size will always scale up to be 1.2x larger than the base setting.

## Utilizing Discourse's font-scaling variables

In Discourse's default styles we rely on a set of font scaling variables. You can also use these variables in your themes:

```css
:root {
  --font-up-6: 2.296em;
  --font-up-5: 2em;
  --font-up-4: 1.7511em;
  --font-up-3: 1.5157em;
  --font-up-2: 1.3195em;
  --font-up-1: 1.1487em;
  --font-0: 1em;
  --font-down-1: 0.8706em;
  --font-down-2: 0.7579em;
  --font-down-3: 0.6599em;
  --font-down-4: 0.5745em;
  --font-down-5: 0.5em;
  --font-down-6: 0.4355em;
}
```

This system ensures we're using a limited set of font sizes that scale based on the global size set on `html` (and saves you from doing math when nesting em units). If an element is set to `--font-up-3`, we know that it will be 1.5x larger than `--font-0`, no matter what the specific px value is.

If you feel a bit lost, it might help to visualize these variables like a ladder. If you have an element with `font-size: var(--font-up-3)` and needed a child of that element to be the equivalent to `--font-0`, you would need to go 3 steps down the ladder to get there (so you'd use `--font-down-3`).

Here it is in action:

```scss
.topic-post {
  font-size: var(--font-up-3); // 3 steps up
  .topic-meta-data {
    font-size: var(
      --font-down-3
    ); // 3 steps back down; equivalent to --font-0 (1em)
  }
}
```
