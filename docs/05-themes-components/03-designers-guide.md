---
title: Designer's Guide to getting started with themes in Discourse
short_title: Designers guide
id: designers-guide

---
So you're interested in in designing your own theme for Discourse? You've arrived at the right topic :smile:

This guide will be more focused on the SCSS/CSS aspects of working with themes in Discourse. If you are also knowledgeable in JS/EmberJs/Handlebars you can go even deeper by looking into this guide.

https://meta.discourse.org/t/developer-s-guide-to-discourse-themes/93648

I will describe to you my personal method's of designing and theming in Discourse. As with most things, there are LOTS of ways to go about implementing your own designs. I enjoy using the inspector tools heavily when creating themes, and will show you a couple times how I do that in this post.

# Getting Setup for Theming
Please read through [Beginners Guide to Using Discourse Themes](https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966), as well as the [Structure of Themes...](https://meta.discourse.org/t/structure-of-themes-and-theme-components/60848) before continuing. A deep knowledge isnt necessary at this point, but these articles will give you a little more familarity before beginning.

In order to best work with theming in Discourse, I suggest getting setup with the following to offer yourself the quickest and most streamlined design process. These steps will enable you to see your changes as you make them, without having to 'save' and refresh from a discourse site admin panel.

*It is totally possible to work through this guide using the admin console (provided you have admin level access to a discourse forum.)*

- Install  [Discourse Theme CLI](https://meta.discourse.org/t/discourse-theme-cli-console-app-to-help-you-build-themes/82950) and read through that topic for an understanding of what it can do.
- Retrieve an API Key from [ https://discourse.theme-creator.io/](https://discourse.theme-creator.io/)
    - Sign in with your Meta Account
    - Click on <kbd>My Themes</kbd>
    - Click on the <kbd>API Key</kbd>
    - In the popup modal, click <kbd>Generate API Key</kbd> & copy the key generated for you (we will use this in a bit)

## Running the Discourse Theme CLI

With the Discourse Theme CLI installed, and your API Key ready, open your preferred text editor or terminal window and change your working directory to where you would like your theme folder to be setup.

Once there, run the following command `discourse_theme new your_theme_name` fill out the prompts like so:

1) **What would you like to call your theme?** Choose your theme name

2) **Would you like to start watching this theme?** Yes

3) **What is the root URL of your Discourse Site?** `https://discourse.theme-creator.io/`

4) **Would you like this site name stored in...?** Yes

5) **What is your API Key?** enter the API key you retrieved from theme creator

6) **Would you like this API key stored...?** Yes

7) Choose **Create and Sync with a new theme** when prompted

8) Choose **Do Nothing** when prompted about child theme components

If everything worked correctly, you should now be able to navigate to `My Themes` on the [ https://discourse.theme-creator.io/]( https://discourse.theme-creator.io/) and see your new theme in the themes list on the left. 

To view these changes in real time, click on your theme name, then at the bottom of the info area, click on <kbd>Preview</kbd>

The Theme CLI is also now watching for any changes in the newly created directory, and will save, as well as update the theme on theme-creator with every change.

# First Steps
The Discourse Theme CLI has created a theme scaffolding for us inside of the folder name we specified in the command we ran earlier. A lot of files are generated that we will not be using, so we will go ahead and delete everything but the following:

`common/common.scss`

`desktop/desktop.scss`

`mobile/mobile.scss`

`about.json`

Inside of the directory, go ahead and run `rm -rf .git` as well to remove git version tracking, it will not be needed for this guide.

Your theme directory should now look like this:

![image|284x210](/assets/designers-guide-1.png)

It is worth noting that the styles we add to these files will render in their respective use case. Styles in `common.scss` will be applied to desktop + mobile, while styles in `desktop.scss` will only be applied to desktop browsing, and those in `mobile.scss` will only apply to mobile views.

## Hello World (in color)

Discourse uses `SCSS` for its styling, so in order to best utilize styles, you may want to familiarize yourself with [SASS](https://sass-lang.com/guide), but if not, you will still be able to follow along with this guide.

Ok, now to get what to what we've all been waiting for... THEMING!

Right now, our `about.json` currently does not have any color_schemes defined, so paste in the following code into that section then save.

```json
{
  "name": "my theme",
  "about_url": null,
  "license_url": null,
  "assets": {
  },
  "color_schemes": {
    "Default": {
      "primary": "222222",
      "secondary": "ffffff",
      "tertiary": "0088cc",
      "quaternary": "e45735",
      "header_background": "ffffff",
      "header_primary": "333333",
      "highlight": "ffff4d",
      "danger": "e45735",
      "success": "009900",
      "love": "fa6c8d"
    }
  } 
}
```
If you have your browser open, you wouldn't have seen any changes take effect, because this is the default color scheme used when no scheme is present.

# Theme Overview

In order to have something to actually implement in this guide, I will walk you through on creating a simple theme based on this color palette.

![image|440x59](/assets/designers-guide-2.png) 
## Changing BG Color + Primary Text Color

Let's do something very simple. We will go ahead and change the `"Secondary"` value of our current color scheme. Let's change it to `"secondary": "EEF4F7"` (this changes the background color.) Let's also change the `"primary"` value to `"203243"` .

![image|690x427](/assets/designers-guide-3.png)
With just that line, we have already changed the look and feel of our forum. A lot of customization can be done by just editing the color's in the color scheme alone.

## Color Scheme Use

All of the following keys are defined in the `about.json` file under the corresponding color scheme name.  These descriptions are a good reference to help you understand what the main purpose of each variable name is for:

| Color | Description
--------- | -------------
**primary**  | Most text, icons, and borders
**secondary** | The main background color, and text color of some buttons
**tertiary** | Links, some buttons, notifications, and accent color
**quaternary** | Navigation links
**header_background** | Background color of the site's header
**header_primary** | Text and icons in the site's header
**highlight** | The background color of highlighted elements on the page, such as posts and topics
**danger** | Highlight color for actions like deleting posts and topics
**success**  | Used to indicate an action was successful
**love** | The like button's color

Each of these variables are available to us to use inside of our SCSS files like so.
```scss
body {
	background-color: var(--primary)
}
```
Other versions of each color are also created for us to use as well. Things like `var(--primary-medium)` , or `var(--primary-very-low)` can be used to get different tones of the same color.

Lets change the other colors in our "Default" color scheme to match this:
```json
"Default": {
      "primary": "203243",
      "secondary": "EEF4F7",
      "tertiary": "416376",
      "quaternary": "5E99B9",
      "header_background": "FaFaFa",
      "header_primary": "EEF4F7",
      "highlight": "86BDDB",
      "danger": "8F393E",
      "success": "70DB82",
      "love": "FC94CB"
    }
```

> :flashlight: You can see all of the available variables for use in your SCSS files if you click on the <kbd>Style Guide</kbd> link while previewing your theme on theme creator, then clicking on Colors in the left hand menu. 
>
>The Styleguide is a very helpful section to look at when you are creating a custom theme. Each Atom will show you how certain elements of Discourse will look with your styles applied.

![image|311x500](/assets/designers-guide-4.png) 

# Going Deeper

With the previous section under our belt, I think it's time for us to go a bit deeper as to what can be done in Discourse with only SCSS. (Hint: A LOT!)

### Styling the Header

You will notice that our previous changes to the color scheme have left something to be desired with our header. The icons are barely visible!

![image|690x37](/assets/designers-guide-5.png) 

The Discourse Header includes a container (with a background color) to hold a site logo, as well as the nav icons to the right. All of these can be customized.

The target class to customize the header is `.d-header` .

In our `common/common.scss` file, let's add the following:
```scss
.d-header {
  box-shadow: none;
  border-bottom: 1px solid var(--primary-low-mid);
  height: 5em;
}
```
This will remove the default box-shadow on the header, give it a little more height, as well as set a border-bottom to give us some separation.

For the icons --  Inside of the `.d-header` SCSS brackets, lets add in this nested code.

```scss
.d-header {
// ...previous code
	.d-icon {
    color: var(--primary-low-mid);
  }
}
```

This is looking good, but a keen eye will notice the increased header height has given us less room in between itself and the rest of the Discourse forum elements!

![image|690x366](/assets/designers-guide-6.png) 

The spacing between the main area and the header is controller by the #main-outlet target. Lets increase this spacing just a bit by adding the following to the bottom of your common/common.scss file.

```scss
#main-outlet {
  padding-top: 6.5em;
}
```

## Navigation Container

The navigation container includes the following pieces.

![image|690x39](/assets/designers-guide-7.png) 

The leftmost area is the category/tag filter dropdowns, followed by the navigation links, ended with the New Topic button.

### Category / Tag Dropdown

Let's make some changes to this area. To do so, add the following to your `common.scss` file.
```scss
.navigation-container {
  .select-kit.combo-box {
    .select-kit-header {
      border-radius: .9em;
      background-color: var(--header_background);
    }
  }
}
```
Here we target the `.select-kit-header` to give them each an identical border-radius, as well as a lighter background color.

Clicking on either of these, opens up a drop down menu.

![image|350x439](/assets/designers-guide-8.png) 

Currently, it is also has hard corners, so lets add some styles to round these off as well as change the background color to be the same as the header.

```scss
.navigation-container {
	.select-kit.combo-box {
		// ...previous code
		&.category-drop,
    &.tag-drop {
      .select-kit-body {
        border-radius: .9em;
        background-color: var(--header_background);
  
        .select-kit-collection {
          background-color: var(--header_background);
          border-top-left-radius: 0px;
          border-top-right-radius: 0px;
        }
      }
    }
  }
}
```
This results in the following look...
![image|420x460](/assets/designers-guide-9.png) 

If you look closely, you can see our changes have left a small border visible at the top right of the search area.

Lets fix this by looking in our browser's inspector. This is always a super helpful tool to learn what classes/IDs we need to target in order to apply styles correctly.

With the dropdown menu visible, right click on the search area and 'Inspect' the element in your browser.

![image|690x424](/assets/designers-guide-10.png) 

We can see that this input is located inside of a `div` with a class of `select-kit-filter` .

If we look at the rules being applied to this selector, we can see that it currently has a border-top and bottom, as well as some padding applied. We want to only change the border-top styling.

Add the following code nested in the `.select-kit-body` scss from earlier.

```scss
.select-kit.combo-box.category-drop,
  .select-kit.combo-box.tag-drop {
    .select-kit-body {
// ...previous code
      .select-kit-filter {
        border-top: 0px;
      }
    }
  }
```
With that, our code to style the navigation container should look like so.
```scss
.navigation-container {
	// Category + Tag Drop Down
  .select-kit.combo-box {
    .select-kit-header {
      border-radius: .9em;
      background-color: var(--header_background);
    }

    &.category-drop,
    &.tag-drop {
      .select-kit-body {
        border-radius: .9em;
        background-color: var(--header_background);
  
        .select-kit-collection {
          background-color: var(--header_background);
          border-top-left-radius: 0px;
          border-top-right-radius: 0px;
        }

        .select-kit-filter {
          border-top: 0px;
        }
      }
    }
  }
}
```

### Navigation Links

Let's add some styles to get these navigation links looking similar to this:

![image|450x42](/assets/designers-guide-11.png) 

Let's use our inspector again to discover what we should target here.

![image|690x318](/assets/designers-guide-12.png) 

We can see that our navigation elements are inside of a UL with a class of `"nav nav-pills ..."`

Back in our  `common.scss` file, under the previous section, but still nested inside of `navigation-container` lets add the following:

```scss
.nav-pills {
	& > li a {
      &.active {
       color: var(--tertiary);
       background-color: var(--secondary);
       border-bottom: 4px solid var(--tertiary);
	  }
  }
}
```

This change will target only our links with a class of active that are children of `nav-pills`. This change should get our active link looking like so:

![image|70x33](/assets/designers-guide-13.png) 

This is fine, but I would like the bottom border to only extend as far as the text. To do this, above the `&.active {` line, lets add the following, which will affect all A links inside of the navigation `<li>` tags.

```scss
// ...other code
.nav-pills {
	& > li a {
     padding: 0;
     margin-right: 20px;
     color: var(--tertiary-high);
     border-bottom: 4px solid transparent;

		&.active {
// ...more code
```

Now, we need to style the "hover" effect to be the same as the "active" effect.

Under our previous `&.active` lets add

```scss
&:hover {
  color: var(--tertiary);
  background-color: var(--secondary);
  border-bottom: 4px solid var(--primary);
}
```

So all of our navigation code should now look like so:

```scss
// Nav Pills
.nav-pills {
  & > li a {
    padding: 0;
    margin-right: 20px;
    color: var(--tertiary-high);
    border-bottom: 4px solid transparent;

    &.active {
      color: var(--tertiary);
      background-color: var(--secondary);
      border-bottom: 4px solid var(--tertiary);
    }

    &:hover {
      color: var(--tertiary);
      background-color: var(--secondary);
      border-bottom: 4px solid var(--primary);
    }
  }
}
```
### Buttons

Buttons in Discourse come in many shapes and sizes. You can view an assortment of them in the Style Guide in the Buttons section.

I would like to change most of the buttons on this theme to be rounded with some custom styling. This will change the <kbd>+ New Topic</kbd> button, as well as other buttons throughout the site.

At the bottom of our `common.scss` file, lets add the following:

```scss
.btn {
  background-color: var(--header_background);
  color: var(--primary);
  border-radius: 1.2em;
  border: 1px solid var(--primary-low-mid);

  .d-icon {
    color: var(--primary);
  }

  &:hover {
    background-color: var(--quaternary-low);
    color: var(--primary);
    .d-icon {
      color: var(--primary);
    }
  }

  &.btn-default,
  &.btn-primary {
    padding: 10px 12px;
  }
}
```

This will get our buttons looking like this:

![image|145x51](/assets/designers-guide-14.png) 

Now that our buttons are styled, I'd like to point something out about button styling and why it's important to test all of your designs.

Go ahead and click through to a Topic on your site preview, then hit the <kbd>reply</kbd> button on a topic reply, or from the reply button at the bottom of the topic stream. You will see that our button styling has affected some things we may not have had in mind.

![image|615x500](/assets/designers-guide-15.png) 

I do not want these text-editing buttons to be affected by my previous styling. This requires a bit of more complex SASS/CSS, but we can get our code to `:not()` affect these buttons. :wink:

Lets add this line of code, in front of our current `.btn` target. This will tell our styles to only apply to buttons who are not children of the `.d-editor-button-bar` .

```scss
:not(.d-editor-button-bar) > .btn {
```

Ok that worked great... but wait! Now there is this strange rebel doing it's own thing.

![image|404x46](/assets/designers-guide-16.png) 

Inspecting this in the browser, I can see that this button has a class of .select-kit-header because upon clicking this gear, more options will show up.

![image|690x184](/assets/designers-guide-17.png) 

> :flashlight:  I can not stress how important using your browser's inspector tools are when creating Discourse Themes. They are your best friend to ride with you on this journey.

Now that we know we *DON'T* want to target this button, let's add some more `:not()` functionality to our code.

```scss
:not(.d-editor-button-bar) > 
.btn:not(.single-select-header) {
```

This will select all buttons that are NOT children of the `.d-editor-button-bar` and do not have the class `.single-select-header`. I know this is a little confusing, but inside Discourse, there are many moving parts, so sometimes the styling needs to be very specific for it to affect elements correctly.

I have also noticed that our current styling affects the modal close button awkwardly. Clicking on anything that pops open a modal would allow you to see this, or even easier, we can navigate to the modal section of the Style Guide.

![image|668x500](/assets/designers-guide-18.png) 

To fix this, I will add another target to our code.

```scss
:not(.d-editor-button-bar) > 
.btn:not(.single-select-header):not(.modal-close)
```
### Moving on...

I see one more button that doesn't seem to have been affected by our code. It is the `Tracking` button located at the very bottom of a topic post stream.

![image|643x73](/assets/designers-guide-19.png) 

I will add the following line, after a comma, to our current `.btn` code.

```scss
:not(.d-editor-button-bar) > 
.btn:not(.single-select-header):not(.modal-close),
.topic-notifications-button > .select-kit > .btn {
```

This will target the button that appears in this section correctly, and for now, we are finished with styling the top area of our forum.

> :flashlight: Feel free to tweak any of the parameters in your own css. The more you play around with these styles and see what and how they affect the html, the more you will learn!

# Where to go from here
This guide was meant to scratch the surface of how you can customize your own theme for Discourse. I hope that you now have more insight into how to target areas of the app for your own customizations. 

**Remember** A LOT of things can be customized with only using SCSS. If you would like to go even deeper with your development, I would recommend reading the articles linked at the top of this post.

Feel free to ask any questions and I will gladly try and help you, or point you in the right direction.
