---
title: Use Discourse Core Variables in your Theme
short_title: Core variables
id: core-variables

---
Discourse is incredibly customizable! 

The goal of this topic is to show you how make use of all the amazing options that are available to you as a theme developer. You know... so that you don't have to reinvent the wheel :smile: 

### Variables? What variables?

Variables cover a large number of things, from font sizes to colors to z-index values. You can use and override the vast majority of variables in your theme editor. 

### Colors

There are many colors available for you to use or override in your theme. You can see the basic set of colors in the admin UI, under Customize > Colors. Here is a screenshot of the default color scheme: 

![admin color scheme page|445x499](/assets/core-variables-1.PNG) 

These colors are available as CSS custom properties that you can use and override via this syntax:

```
var(--primary)
var(--secondary)
var(--tertiary)
var(--quaternary)
var(--header_background)
var(--header_primary)
var(--highlight)
var(--danger)
var(--success)
var(--love)
```

> :warning: The use of SCSS color variables (like `$primary`, $secondary` and so on) is deprecated. Discourse core uses CSS custom properties since August 2020 and we can recommend all existing themes switch SCSS variables to CSS custom properties. For complex color manipulations, see [this guide](https://meta.discourse.org/t/updating-themes-and-plugins-to-support-automatic-dark-mode/161595#some-additional-notes-3). 

### So how can I use them? 

Start by creating a new theme or if you are using a git-based theme, create a new theme component and add it to your theme.

Let's say I want to set the `<body>` background to match the `highlight` color of the current color scheme. Well, I can do that like so:

```
body { 
    background: var(--highlight);
}
```

And the color would be pulled automatically from the current color scheme, like so:

![image|545x500](/assets/core-variables-2.png) 

(This background color is not recommended  :sweat_smile:)

Now, let's say the current color scheme is not set to "Light scheme" for the current theme. Instead, let's say it's set to the default "Dark" scheme, the same code would yield a different result because the variable is different. 

![image|542x500](/assets/core-variables-3.png) 

You can see how the `<body>` background follows the current `highlight` variable whatever it may be for the current color scheme.

That covers the basic color variables. Discourse also uses derivative colors that can be used or overriden. You can see the full list of colors from the current color scheme in your browser inspector, here is a screenshot of the default theme: 

![image|441x500](/assets/core-variables-4.png) 

Notice that you can inspect these colors on any Discourse instance, no need to be authenticated. On your own Discourse instance, you can (and _should_) also use the styleguide plugin, which is  now included in core. Enable it and head to `/styleguide`, and you see all of the Discourse UI elements, including colors: 

![image|428x499](/assets/core-variables-5.png) 

(That's the Grey Ember color scheme above.) 

Ok, on to more advanced topics: 
<hr>

### Advanced Variables 

Take a look at this file in the Discourse repo: 

https://github.com/discourse/discourse/blob/master/app/assets/stylesheets/common/foundation/variables.scss

This is where most of the variables are defined. Just like colors, these variables are magically available for you to use in theme stylesheets.

I will try to break down the content of the file below:

#### Widths
```
$small-width: 800px !default;
$medium-width: 995px !default;
$large-width: 1110px !default;
```

these are very handy if you want your theme to match native Discourse behavior, especially in media queries for example take a look at the relevant parts of the pre-compiled scss for `.user-info`:

```
.user-info {
  &.medium {
    flex: 0 0 32%;
    margin: 0 2% 4vh 0;
    @media screen and (max-width: $small-width) {
      flex: 0 0 48%;
      margin-right: 0;
    }
  }
}
```

Notice how the media query is fed a variable to determine a cut-off point for small screens and apply different styles.

<hr>

####  Fonts

```
  --base-font-size: 0.938em; // eq. to 15px
  --base-font-size-larger: 1.063em; // eq. to 17px
  --base-font-size-largest: 1.118em; // eq. to 19px

  // Font-size definitions, multiplier ^ (step / interval)
  --font-up-6: 2.296em;
  --font-up-5: 2em;
  --font-up-4: 1.7511em;
  --font-up-3: 1.5157em;
  --font-up-2: 1.3195em;
  --font-up-1: 1.1487em; // 2^(1/5)
  --font-0: 1em;
  --font-down-1: 0.8706em; // 2^(-1/5)
  --font-down-2: 0.7579em; // Smallest size we use based on the 1em base
  --font-down-3: 0.6599em;
  --font-down-4: 0.5745em;
  --font-down-5: 0.5em;
  --font-down-6: 0.4355em;
```

This is also pretty straightforward,  Discourse has an awesome font-scaling system and so you **should** make use of it. 

The units used are in `em` and so would be relative to `--base-font-size` which is used on the `<html>` element. 

So:

```
.btn {
    font-size: var(--font-up-6);
}
```
gets compiled into:

(--base-font-size * --font-up-6) or (14px * 2.296) = `32.14px`

Or this:

![Capture|690x492](/assets/core-variables-6.PNG)

<hr>

#### Line heights

```
--line-height-small: 1;
--line-height-medium: 1.2; // Headings or large text
--line-height-large: 1.4; // Normal or small text
```

These variables can be used just like the previous example. Do note that they are unitless values. Here's what that means:

[quote="awesomerobot, post:10, topic:75396"]
That’s why it’s recommended that unitless line-height values are used, because your line-height will always be based on the font-size. With 14px font-size and line-height of 1, your line height will be 14px. Update the font-size to 16px and your line-height will be 16px. Unitless line-heights serve as multipliers of the font-size, not values.
[/quote]
 

#### Z-index values

```
$z-layers: (
  "max":              9999, 
  "fullscreen":       1700,
  "modal": (
    "tooltip":        1600,   
    "popover":        1500,
    "dropdown":       1400,
    "content":        1300,
    "overlay":        1200,
  ),
  "mobile-composer":  1100,
  "header":           1000,
  "tooltip":          600,
  "composer": (
      "popover":      500,
      "content":      400,
  ),
  "dropdown":         300,  
  "usercard":         200,
  "timeline":         100,
  "base":             1
  );
```

These can be used as discussed here: 

[quote="awesomerobot, post:1, topic:78236"]
You have basic values like “dropdown” and “fullscreen” but we can also nest some values for more complex stacking like within modals or the composer. The nested values don’t need to be sequential as I’ve set them (due to stacking contexts), but it makes the hierarchy clearer and works as you’d expect.

You call these values in our core CSS like this:
[/quote]

```
div {
    z-index: z("header");
}
```

"or when nested, like this:"

```
div {
    z-index: z("modal", "dropdown");
}
```

"You can also do basic math as you’d expect:"

```
div {
    z-index: z("base") + 1;
}
```

_The code-blocks above are part of the quote but I moved them out for formatting_

Now here's an example: 

Put a box above the header:

```
.zbox {
    position: fixed;
    top: 0;
    left: 0;
    height: 200px;
    width: 200px;
    background: red;
    z-index: z("header") + 1;
}
```

![Capture|690x218](/assets/core-variables-7.PNG)


Put a box below the header:

```
.zbox {
    position: fixed;
    top: 0;
    left: 0;
    height: 200px;
    width: 200px;
    background: red;
    z-index: z("header") - 1;
}
```

![Capture|690x170](/assets/core-variables-8.PNG)

<hr>

#### Box shadows

```
$box-shadow: (
  "modal":        0 8px 60px rgba(0, 0, 0, 0.6),
  "composer":     0 -1px 40px rgba(0, 0, 0, 0.12),
  "menu-panel":   0 6px 14px rgba(0, 0, 0, 0.15),
  "card":         0 4px 14px rgba(0, 0, 0, 0.15),
  "dropdown":     0 2px 3px 0 rgba(0, 0, 0, 0.2),
  "header":       0 2px 4px -1px rgba(0, 0, 0, 0.25),
  "kbd":         (0 2px 0 rgba(0, 0, 0, 0.2), 0 0 0 1px dark-light-choose(#fff, #000) inset),
  "focus":        0 0 6px 0 $tertiary,
  "focus-danger": 0 0 6px 0 $danger
);
```

As you can sort of see, most of the work has been done for you when it comes to variables, and you only need to utilize what's already there in most cases. 

The use for box shadows looks like this:

```
.d-header {
    box-shadow: shadow("focus");
}
```

This should make the header use the focus box-shadow. And if we check to confirm:

![Capture|690x100](/assets/core-variables-9.PNG)

<hr>

This post is a wiki so edit as needed :wink:
