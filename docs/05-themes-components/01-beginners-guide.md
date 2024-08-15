---
title: Beginner's guide to developing Discourse Themes
short_title: Beginners guide
id: beginners-guide

---
So, you want to create Discourse themes? Not sure where to start? Or maybe you have created Discourse themes before, but want to learn how to do even more cool things. Well, you've come to the right place :wink:

**Developer's guide to Discourse Themes**

> Subjects include a general overview of Discourse themes, creating and sharing Discourse themes, theme development examples, searching for and finding information / examples in the Discourse repository, and best practices.

Prerequisites: 

https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966

> :warning: While there's very little fluff in this guide, it's still long. It is not meant to be read in one go. To get the most out of this guide, I suggest taking your time. Go slow and easy, and follow the examples.

<hr>

### Introduction  

#### The structure of this tutorial 

Since this topic is going to be long and will cover a wide variety of subjects, it's good to take a step back and describe its structure a bit. I will be using a lot of headings. The reason for this is that say at some point in the future you want a quick refresher (something that I do a lot), you can easily navigate to the section you need to look at. The headings for different sections are listed in the table of contents on the right side. Clicking on any of those items takes you to that section. 

Finally, for the purposes of this guide, and unless otherwise specified, the terms "theme" and "themes" here refer to both themes and to theme components.

#### The scope of this topic

Let's start by highlighting what this topic is all about.

> Introduction to Discourse theme development for developers with little or no previous experience working on Discourse themes. Developers learn how to create Discourse themes that either modify the design of a forum or add new functionality. While this topic assumes no previous experience working on Discourse themes, it does assume some experience in the languages it covers.

Those languages are listed below - each is a link to a good place to read more about the language.

1. [HTML](https://developer.mozilla.org/en-US/docs/Learn/HTML/Introduction_to_HTML)
2. [CSS](https://developer.mozilla.org/en-US/docs/Learn/CSS)
3. [JavaScript](https://developer.mozilla.org/en-US/docs/Learn/JavaScript) / [jQuery](https://learn.jquery.com/about-jquery/)
4. [SCSS](https://sass-lang.com/guide)
5. [Handlebars](https://handlebarsjs.com/guide/)

It's also a good idea to [know your way around Github](https://guides.github.com/activities/hello-world/)

[quote="You,"]
What?! That's a lot of things and we haven't even started yet! :scream:
[/quote]

**Don't stress about it!** You won't need to learn / know all of these to create a theme. I have to include everything here for this guide to be a good reference point. 

The beauty of Discourse themes is that they will go as far as you take them. 

Want to create a simple CSS theme component that adds hover effects to titles? 
**You can.**

Want to create a mega-complex monolith theme that uses SCSS / Handlebars / Ajax and completely overhauls all the things? 
**You can.**  

[quote="You,"]
So, why did you start with all of that then?
[/quote]

In order to scope this tutorial. 

Think of it this way. This tutorial will **not** teach you how to write js conditional statements. It will, however, teach you how to find and feed Discourse-specific bits into conditional statements.

Ok, now we covered the scope and structure, we can move on to the bits you're actually interested in reading.

<hr>

### Overview of Discourse themes

#### What are themes anyway?

In a previous guide, I described themes / theme components as:

[quote]

A theme or theme component is a set of files packaged together designed to either modify Discourse visually or to add new features.
[/quote]

[quote]
#### Themes

In general, themes are not supposed to be compatible with each other because they are essentially different standalone designs. Think of themes like skins, or like launchers on Android. You can have multiple launchers installed but you can't use two of them at the same time. Your default Discourse installation comes with two themes
[/quote]

[quote]
#### Theme Components

We use the phrase theme-component to describe packages that are more geared towards customising one aspect of Discourse. Because of their narrowed focus, theme components are almost always compatible with each other. This means that you can have multiple theme components running at the same time under any theme. You can think of theme components like apps on your phone.
[/quote]

Those definitions come from the https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966 (probably worth glancing over if you haven't done so already) which is geared towards users of Discourse themes and not Discourse theme developers. However, this is a good base to start with. 

[quote="You,"]
So, what's different from a developer's perspective?
[/quote]

Beyond the definitions above, here's what you need to know as a theme developer.

Themes can only amend the front end and have no access to the back-end. If this makes little to no sense to you, you don't need to worry about it for now. 
 
#### Remote and local themes

Discourse themes and theme components can either be

1. Local
2. Remote

Local themes are themes created / stored on a Discourse install. 

You create a brand new local theme by clicking here:

![2024-03-12_ss-install-theme|690x454, 75%](/assets/beginners-guide-1.jpeg)

...and then here:

![2024-03-12_ss-new-theme|475x500, 75%](/assets/beginners-guide-2.jpeg)

After making your changes. These can be exported and saved / shared by clicking here:

![2024-03-12_ss-export-theme|690x454, 75%](/assets/beginners-guide-3.jpeg)

...but sharing a file somewhere is not the ideal way to share a theme publicly, so we have remote themes. 

Remote themes are Discourse themes that live in repositories on Github. This makes it easy to share themes. You create a theme and share the link to the repository, then users can install the theme using that link by clicking `Install` and then adding the repository location:

![2024-03-12_ss-import-theme-git|690x350, 50%](/assets/beginners-guide-4.png)

All the themes in the #theme categories are remote themes. Here's an example of what one of them looks like on [Github](https://github.com/discourse/discourse-brand-header)

![Capture2|690x481, 72%](/assets/beginners-guide-5.PNG) 

#### Theme files and folders

Let's look at the interface for the theme editor:

![5|672x500, 75%](/assets/beginners-guide-6.PNG) 

Notice how there are three main sections.

1. Common
2. Desktop
3. Mobile

As you may have already guessed, this allows your theme to target different device types, or apply your changes to both. Anything you change in the common tab will apply to desktop and mobile. Anything you change in the desktop or mobile tab will only apply to that respective device type. 

You can preview the mobile view on a desktop device by appending `?mobile_view=1` to the end of the URL (`?mobile_view=0` switches back to Desktop).

Now let's look at the subsections under those.

1. CSS
2. `<head>`
3. Header
4. After Header
5. `</body>` 
6. Footer
7. Embedded CSS

First a little bit about those subsections:

1. CSS: You can add CSS and SCSS here. Whatever you add is compiled automatically on save and added as a separate `.css` stylesheet to the `<head>` section if the theme is active.

2. `<head>`: You can add html here (including script tags). Anything you add here is inserted just before the close tag of the `<head>` close tag or `</head>` 

3. Header: You can also add html here. Anything you add here is inserted at the top of the `<body>` tag before the Discourse Header

 4. After Header: Same as above. You can add html here. However, anything you add here will be inserted below the Discourse header but above the rest of the page content

5. `</body>`: You can use html here. Anything you add is inserted at the very bottom of the `<body>` tag or just before the `</body>` tag

6.  Footer: You can also use html here but it's is inserted just after the end of the page content or just below the `<div id="main-outlet">` close tag

7. Embedded CSS: You can add CSS and SCSS here as well, the difference is that whatever you add here is only applied to Discourse when it's embedded on another site. At the moment we support embedding [comments](https://meta.discourse.org/t/embedding-discourse-comments-via-javascript/31963) and [topic lists](https://meta.discourse.org/t/embedding-a-list-of-discourse-topics-in-another-site/125911).

This covers all the subsections of the common section of the theme editor. The desktop and mobile sections are exactly the same except that they will only target their respective devices and they don't have the Embedded CSS subsection.   

Now that you understand what those sections are. Here are (most of) the files that a theme can contain:

```
common/common.scss
common/head_tag.html
common/header.html
common/after_header.html
common/body_tag.html
common/footer.html
common/embedded.scss

desktop/desktop.scss
desktop/head_tag.html
desktop/header.html
desktop/after_header.html
desktop/body_tag.html
desktop/footer.html

mobile/mobile.scss
mobile/head_tag.html
mobile/header.html
mobile/after_header.html
mobile/body_tag.html
mobile/footer.html
```

We're pretty serious about making sure file names are intuitive and so I hope that you can glance at the file name and figure out which section it relates to. 

I said most of the files above because there are also other files a theme can / must include.

A theme can include assets like fonts and images and those go into an `assets` folder.

```
assets/background.jpg
assets/font.woff2
assets/icon.svg
```
A remote theme must include an `about.json` file in order for it to importable. The `about.json` file lives at the root of the theme and its contents look like this

```json
{
  "name": "Theme name",
  "about_url": "Theme about url",
  "license_url": "Theme license url",
   "assets": {
        "asset-variable": "assets/background.svg"
   },
   "color_schemes": {
       "color scheme name": {
          "primary": "000000",
          "secondary": "000000",
          "tertiary": "000000",
          "quaternary": "000000",
          "header_background": "000000",
          "header_primary": "000000",
          "highlight": "000000",
          "danger": "000000",
          "success": "000000",
          "love": "000000"
        }
    }
}
```

Themes can also include settings. The settings live in a `settings.yml` file that also live at the root of the theme directory. A theme settings file looks like this:

```yaml
whitelisted_fruits:
  default: apples|oranges
  type: list

favorite_fruit:
  default: orange
  type: enum
  choices:
    - apple
    - banana
```

This is just an example of theme settings. More details about them will follow. 

So, here's an example of what a finished theme would look like:

```
about.json

assets/font.woff2
assets/background.jpg
assets/icon.svg

common/common.scss
common/head_tag.html
common/header.html
common/after_header.html
common/body_tag.html
common/footer.html
common/embedded.scss

desktop/desktop.scss
desktop/head_tag.html
desktop/header.html
desktop/after_header.html
desktop/body_tag.html
desktop/footer.html

mobile/mobile.scss
mobile/head_tag.html
mobile/header.html
mobile/after_header.html
mobile/body_tag.html
mobile/footer.html

settings.yml
```

pretty straightforward huh?

[quote="You,"]
Do I need to include all of these for every theme?
[/quote]

No! The only thing required is the `about.json` file for remote themes. Everything else is optional and should only be added if you need it.


#### Color schemes

You probably noticed the `color_schemes` section in the `about.json` file example above. Well, themes can introduce new color schemes!

[quote="You,"]
uhm... backup a bit. What are color schemes?
[/quote]

A Color scheme is a set of colors you choose that is used to automatically color all the elements in Discourse. 

The interface looks like this

![6|619x500, 75%](/assets/beginners-guide-7.PNG) 

and the colors are linked to the values you enter in the `about.json` file we discussed earlier. So 

```json
"color_schemes": {
  "Foo bar": {
      "primary": "cccccc",
      "secondary": "111111",
      "tertiary": "009dd8",
      "quaternary": "9E9E9E",
      "header_background": "131418",
      "header_primary": "cccccc",
      "highlight": "9E9E9E",
      "danger": "96000e",
      "success": "1ca551",
      "love": "f50057"
    }
}
```

would create a new color scheme that looks like this 

![7|617x500, 75%](/assets/beginners-guide-8.PNG) 

Discourse then takes those colors (if that color scheme is active) does a bit of magic to them (which we'll cover later) and creates a few variations of those colors to style all the elements. This removes the need to write a gazillion lines of CSS just to change the theme colors across the board.

[quote="You,"]
Can you stop blabbering and let's create some themes already?!
[/quote]

Fine. :sob:

### Your first themes!

#### Hello World (HTML / CSS)

Let's start with a basic local theme. We're going to add a big "Hello World!" banner under the Discourse header. Like I mentioned at the intro, this topic will not teach you how to write CSS / HTML so I won't be explaining those but here are the bits we're going to need for this theme.

html
```xml
<div class="hello-world-banner">
    <h1 class="hello-world">Hello World!</h1>
</div>
```

CSS
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

So, since we want our banner here

![9|690x245, 75%](/assets/beginners-guide-9.PNG) 

Then the best place to add the html for it would be the After Header section in the theme editor or here

![10|690x339, 75%](/assets/beginners-guide-10.PNG) 

and the CSS goes here

![11|690x331, 75%](/assets/beginners-guide-11.PNG) 

Be sure to hit the save button and then hit the **preview** button 

and if we check to see...

![12|690x406, 75%](/assets/beginners-guide-12.PNG) 

There! You've just created your first Discourse theme! :tada: 

#### Hello World (JS)

We will now try to do something similar but with JS. Let's try to create an alert that says "Hello World!" when you first load Discourse. 

The script we're going to need is

```xml
<script>
    alert('Hello world!')
</script>
```

Now, since this is a script, we need be a little bit more careful where to add to ensure that it fires. You have one of three options:

![13|567x500, 75%](/assets/beginners-guide-13.PNG) 

1. The `</head>` section
2. The Header section
3. The `</body>` section

Adding the script to any other section will cause it not to fire. I prefer to keep scripts in the `</head>` or Header sections. So, let's add it to the `</head>` section like so:

![14|690x373, 60%](/assets/beginners-guide-14.PNG) 

Save, and check if it worked

![15|690x244, 60%](/assets/beginners-guide-15.jpg)

Hooray! :tada: Your second basic Discourse theme is done. 

[quote="You,"]
great... but these are all local themes. How do I create a remote theme?
[/quote]

#### Hello World (Remote)

As we discussed earlier, remote themes live in Github repositories. So, let's go ahead and create a new repository and add a license to it

![15|690x472, 60%](/assets/beginners-guide-16.PNG) 

When in doubt, Select MIT for the license. 

Now we have a repository! But it's a bit...empty. So let's fix that. We're going to recreate the (HTML / CSS) "Hello World!" theme you created locally earlier. 

If you remember, We added 

 ```xml
<div class="hello-world-banner">
    <h1 class="hello-world">Hello World!</h1>
</div>
```

To the After Header subsection in the common section

![10|690x339, 60%](/assets/beginners-guide-17.PNG)

So we need to do the same with your first remote theme. If you recall from earlier, I mentioned that if you need to add html to the common After Header section of a theme, you need your remote repository to contain a folder named `common`, with a file named `after_header.html` in it. So, let's create that and add the markup for the "Hello World!" banner there.

![17|485x499, 88%](/assets/beginners-guide-18.PNG) 

Then commit the new file. 

We also need to add the banner CSS. So, we need to create a file named `common.scss` in the same `common` folder and add the CSS to it. So this

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
Is added like so:

![18|485x500](/assets/beginners-guide-19.PNG)

You can then commit the new `common.scss` file.

Now, your first remote theme does not have any settings or assets, so the only file left for you to make is the `about.json` file. As we discussed before. `about.json` files are **required** for remote themes to work.

[quote="You,"]
Ok great, what do I put in that about.json file then? 
[/quote]

This:

```json
{
  "name": "My first remote theme",
  "about_url": "https://some.url.com",
  "license_url": "https://github.com/GitHubUsername/my-first-remote-theme/blob/master/LICENSE"
}
```
1. the name of your theme
2. The "About" URL for your theme, which shows up here for users of your theme:

![19|566x499, 75%](/assets/beginners-guide-20.PNG)

3. The URL for the theme's license, which you can get by clicking on the license file of your repository (or you can use any license URL you have like [here)](https://desandro.mit-license.org/)

![20|435x500, 98%](/assets/beginners-guide-21.PNG)

The link to the theme's license show's up here in for users of your theme:

![21|568x500, 75%](/assets/beginners-guide-22.PNG)

So, now you know what to add to the `about.json` file of your theme, let's go ahead and make one. **It needs to be at the root of your repository.**

![22|485x500, 88%](/assets/beginners-guide-23.PNG)

Commit the `about.json` file and your theme should be ready to be imported. 

Let's try to import your first remote theme. Copy the repository's link from here

![23|517x500, 82%](/assets/beginners-guide-24.PNG)

Then go to the theme editor and click on Import here

![24|567x500, 75%](/assets/beginners-guide-25.PNG)

Then on "From the web" and paste the repository link in the input like so

![25|690x498, 60%](/assets/beginners-guide-26.PNG)

Click on Import...and... Magic!

![26|568x500, 75%](/assets/beginners-guide-27.PNG)

Try to preview your first remote theme to make sure everything looks right by clicking here 

![27|568x500, 75%](/assets/beginners-guide-28.PNG)

and....:drum:

![12|690x406, 62%](/assets/beginners-guide-29.PNG)

There it is! Your first remote Discourse Theme! :tada::tada:

You can share the repository URL with anyone and they will be able to install your theme with only a few clicks but we can take this a step further!

[quote="You,"]
What do you mean? 
[/quote]

This. 

#### Creating previews on Theme Creator

Not long ago, we introduced [Theme Creator](https://meta.discourse.org/t/theme-creator-create-and-show-themes-without-installing-discourse/84942) 

Theme creator is a tool that allows theme developers to

1. Create themes (without installing Discourse)
2. Have content to test themes on (not so easy on an empty install)
3. Create previews for themes (super easy to show your work!)

[quote="You,"]
So how do I use it? 
[/quote]

While logged in here on Meta, visit 

 https://theme-creator.discourse.org

hit login... done! 

You now have an account on theme creator and can create and share themes.

Once logged in, you'll see this:

![28|690x466, 75%](/assets/beginners-guide-30.jpg)

Now click on My themes and you'll be taken to a familiar interface:

![29|690x490, 75%](/assets/beginners-guide-31.PNG)

The reason this interface looks familiar is that it's the same you would see on your own Discourse install. However, with theme creator, you now have access to it even if you don't have Discourse installed! 

Now, let's try to import your first remote theme to theme creator like we did earlier

![25|690x498, 60%](/assets/beginners-guide-32.PNG)

Now, let's create a preview link for your theme on theme creator. All you need is to click here and give it a name.

![30|690x489, 75%](/assets/beginners-guide-33.PNG)

copy the link

![31|690x260, 75%](/assets/beginners-guide-34.PNG)

Done! now you can share this link with anyone and they will be able to preview your theme on a live Discourse install

Here's mine:

 [https://theme-creator.discourse.org/theme/Johani/my-first-remote-theme](https://theme-creator.discourse.org/theme/Johani/my-first-remote-theme)

Now, when users click that link they will see

![32|690x491, 75%](/assets/beginners-guide-35.PNG)

Very cool, huh? :wink::+1:

#### Develop and preview changes live on Theme Creator

With our [theme command line tool](https://meta.discourse.org/t/discourse-theme-cli-console-app-to-help-you-build-themes/82950) (Theme CLI) you can work on your theme locally and preview your changes as you make them on the Theme Creator site (or on a [local dev install](https://meta.discourse.org/tags/dev-install)). 

To learn more about how, check out the https://meta.discourse.org/t/beginners-guide-to-using-theme-creator-and-theme-cli-to-start-building-a-discourse-theme/108444

### Advanced Discourse themes

#### Let's talk about CSS

Discourse uses [SCSS](https://sass-lang.com/) to simplify styling and increase maintainability. I won't get into the details of why it is like that. I'll just leave it at recommending that you use SCSS instead of CSS when possible in your themes. It scales a lot better and your future self will thank you!

##### SCSS variables
Because Discourse uses SCSS, you can use variables like so

```scss
$font-stack: Helvetica, sans-serif;
$primary-color: #333;

body {
  font: 100% $font-stack;
  color: $primary-color;
}
```   

It's very easy to change one line at the top of your sheet to change either the color or font when compared to changing hard-coded colors for tens of different elements.

Additionally, you can use Discourse core variables in your theme. This includes color schemes and lot of other things. Going back to the "Hello World!" banner theme from earlier, we had this CSS

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

Notice how the background color is hard-coded to `red` and the font color for the heading is hardcoded to `white` 

Let's try to use the color scheme variables instead. These look like so

```css
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

and the names should sound familiar to you because they are the same as here  

![6|619x500, 75%](/assets/beginners-guide-36.PNG)

If we attempt to use those color instead of hard-coded values, we'd end up with this

```scss
.hello-world-banner {
  height: 300px;
  width: 100%;
  background: var(--quaternary);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1em;
}

.hello-world {
  font-size: 8em;
  color: var(--secondary);
}
```

and here's the result 

![33|690x490, 65%](/assets/beginners-guide-37.PNG)

now, if the active color scheme changes, your theme will adjust itself magically! 

![34|599x500, 74%](/assets/beginners-guide-38.PNG)

This is just an example of one of the variable types you can use in your theme. We have a lot more and there's a topic detailing those here:

https://meta.discourse.org/t/how-to-use-discourse-core-variables-in-your-theme/77551

##### A better way of finding CSS selectors

The amount of elements in Discourse can look a bit overwhelming from a re-styling stand point. However, this feeling is rooted in trying to use traditional approaches on a very modern web app like Discourse. You can honestly write 4-8k lines of pure "traditional" CSS and you'd barely be close to a full theme. 

This is part of the reason why I recommend you use SCSS.

let's assume you want to style all the buttons in Discourse. Well, you can use DevTools and try to find every variation of every button and style it, or you can try a different approach. The approach is to reuse whatever you can.

##### Reuse Discourse SCSS

Let's try to restyle all the buttons in Discourse by using this approach

1. Open [DevTools](https://developers.google.com/web/tools/chrome-devtools/)
2. Highlight a button 
3. Find the origin stylesheet for its styles 
4. Copy the selectors

With screenshots

1. 
    ![35|690x339, 75%](/assets/beginners-guide-39.PNG)

2. 
    ![36|690x347, 75%](/assets/beginners-guide-40.PNG)

3. 
    ![37|690x369, 75%](/assets/beginners-guide-41.PNG)

4.
    ![38|690x339, 75%](/assets/beginners-guide-42.PNG)

There, now you have organised SCSS selectors that match those used on Discourse core.


[details="Expand snippet"]
```scss
// --------------------------------------------------
// Buttons
// --------------------------------------------------

// Base
// --------------------------------------------------

.btn {
  display: inline-block;
  margin: 0;
  padding: 6px 12px;
  font-weight: 500;
  font-size: $font-0;
  line-height: $line-height-medium;
  text-align: center;
  cursor: pointer;
  transition: all 0.25s;

  &:active,
  &.btn-active {
    text-shadow: none;
  }
  &[disabled],
  &.disabled {
    cursor: default;
    opacity: 0.4;
  }
  .fa {
    margin-right: 7px;
  }
  &.no-text {
    .fa {
      margin-right: 0;
    }
  }
}

.btn.hidden {
  display: none;
}

// Default button
// --------------------------------------------------

.btn {
  border: none;
  color: $primary;
  font-weight: normal;
  background: $primary-low;

  &[href] {
    color: $primary;
  }
  &:hover,
  &.btn-hover {
    background: $primary-medium;
    color: $secondary;
  }
  &[disabled],
  &.disabled {
    background: $primary-low;
    &:hover {
      color: dark-light-choose($primary-low-mid, $secondary-high);
    }
    cursor: not-allowed;
  }

  .d-icon {
    opacity: 0.7;
    line-height: $line-height-medium; // Match button text line-height
  }
  &.btn-primary .d-icon {
    opacity: 1;
  }
}

// Primary button
// --------------------------------------------------

.btn-primary {
  border: none;
  font-weight: normal;
  color: $secondary;
  background: $tertiary;

  &[href] {
    color: $secondary;
  }
  &:hover,
  &.btn-hover {
    color: #fff;
    background: dark-light-choose($tertiary, $tertiary);
  }
  &:active,
  &.btn-active {
    @include linear-gradient($tertiary, $tertiary);
    color: $secondary;
  }
  &[disabled],
  &.disabled {
    background: $tertiary;
  }
}

// Danger button
// --------------------------------------------------

.btn-danger {
  color: $secondary;
  font-weight: normal;
  background: $danger;
  &[href] {
    color: $secondary;
  }
  &:hover,
  &.btn-hover {
    background: scale-color($danger, $lightness: -20%);
  }
  &:active,
  &.btn-active {
    @include linear-gradient(scale-color($danger, $lightness: -20%), $danger);
  }
  &[disabled],
  &.disabled {
    background: $danger;
  }
}

// Social buttons
// --------------------------------------------------

.btn-social {
  color: #fff;
  &:hover {
    color: #fff;
  }
  &[href] {
    color: $secondary;
  }
  &:before {
    margin-right: 9px;
    font-family: FontAwesome;
    font-size: $font-0;
  }
  &.google,
  &.google_oauth2 {
    background: $google;
    &:before {
      content: $fa-var-google;
    }
  }
  &.instagram {
    background: $instagram;
    &:before {
      content: $fa-var-instagram;
    }
  }
  &.facebook {
    background: $facebook;
    &:before {
      content: $fa-var-facebook;
    }
  }
  &.cas {
    background: $cas;
  }
  &.twitter {
    background: $twitter;
    &:before {
      content: $fa-var-twitter;
    }
  }
  &.yahoo {
    background: $yahoo;
    &:before {
      content: $fa-var-yahoo;
    }
  }
  &.github {
    background: $github;
    &:before {
      content: $fa-var-github;
    }
  }
}

// Button Sizes
// --------------------------------------------------

// Small

.btn-small {
  padding: 3px 6px;
  font-size: $font-down-1;
}

// Large

.btn-large {
  padding: 9px 18px;
  font-size: $font-up-1;
  line-height: $line-height-small;
}

.btn-flat {
  background: transparent;
  border: 0;
  outline: 0;
  line-height: $line-height-small;
  .d-icon {
    opacity: 0.7;
  }
}
```
[/details]


Once you make the changes to fit your needs and save, you will already have created a theme component that changes the way all buttons in Discourse appear. 

Obviously, you'd ideally only save the selectors you intend on modifying and remove unchanged rules. 

Much easier than finding all the buttons / selectors one by one, no? :wink:

##### Reuse Discourse classes

On a similar note, you can make your life a lot easier by using Discourse classes in your html instead of rewriting the styles. Here's what I mean, let's say you want to add a couple of buttons above the header. You'd start with something like 

```xml
<div>
    <button>Click me!</button>
    <button>Don't click me!</button>
</div>
``` 

in the Header section of a theme. This html by itself would look like this:

![39|671x500, 75%](/assets/beginners-guide-43.PNG)

Now, this doesn't look right, it needs to be styled. There are two ways to do this, you can either write the SCSS needed to style these new elements, which can take a bit of time, or you can simply reuse Discourse core classes. 

For example, if you check the `#main-outlet` element which wraps around the entire content, you'll find it has the class `wrap` 

![40|690x193, 70%](/assets/beginners-guide-44.PNG)

Now if we reuse that class, along with a couple of other classes in the example html we end up with this

```xml
<div class="wrap">
    <button class="btn btn-primary">Click me!</button>
    <button class="btn btn-danger">Don't click me!</button>
</div>
```

and it looks a bit better, even though we haven't added any CSS.

![41|580x500, 75%](/assets/beginners-guide-45.PNG)

Once you're sure you can't add any more reusable classes from Discourse core, you can then write your custom css and classes like so

html 
```xml
<div class="wrap foobar">
    <button class="btn btn-primary">Click me!</button>
    <button class="btn btn-danger">Don't click me!</button>
</div>
```

SCSS 
```scss

.foobar {
  display: flex;
  justify-content: flex-end;
  background: var(--secondary-high);
  padding: .5em 0;
  button {
    margin: .25em;
  }
}
```

![42|580x500, 75%](/assets/beginners-guide-46.PNG)

And again, since we have not hard-coded any colors in the design, it will follow the current active color scheme. 

[quote="You,"]
Ok, but so far you've only demonstrated adding html in very limited areas like the header and footer. How do I add html to other places?  
[/quote]

This is where Handlebars templates come in.

#### Handlebars templates

Discourse is a modern web app. Traditional HTML by itself is not flexible enough due to the dynamic nature of content on Discourse. Just like SCSS makes working with CSS a lot easier, using Handlebars templates makes working with HTML less of a hassle. 

If you're already familiar with Handlebars templates, then great! If not, don't worry about it and just think of Handlebars template as html on steroids. 

##### Modifying Discourse templates 

The easiest way to add html to any template is to find a plugin-outlet 

[quote="You,"]
plugin what?
[/quote]

Well as it turns out most Discourse templates have things like this in them

```handlebars
{{plugin-outlet name="topic-above-post-stream" args=(hash model=model)}}
```

This particular one comes from this template

https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/templates/topic.hbs#L13

[quote="You,"]
Sure, whatever you say... but what can I do with this information? 
[/quote]

Well, you can do something like this (I'll explain in a bit)

```xml
<script type="text/x-handlebars" data-template-name="/connectors/topic-above-post-stream/foobar">
  <div style="height: 200px; width: 200px;background: red"></div>
</script>
```

Now let's break this down a bit. 

```xml
<script type="text/x-handlebars" data-template-name="/connectors/topic-above-post-stream/foobar">
```
Look at the `data-template-name` attribute above. Notice anything familiar? 

Well, when you need to add raw html or Handlebars expressions like this 

```xml
<div style="height: 200px; width: 200px;background: red"></div>
```

or this

```handlebars
{{d-button class="btn-small cancel-edit" icon="times"}}
```

Discourse wants to know where you want to add those new elements. Plugin-outlets are just the way to do that.  When I specify
```
data-template-name="/connectors/topic-above-post-stream/
``` 

in the Handlebars script tag, I am literally saying to Discourse, take the content of this script tag and inject it where the `topic-above-post-stream` plugin outlet is. 

Naming is critical. so be sure to follow this

```xml
<script type="text/x-handlebars" data-template-name="/connectors/PLUGIN-OUTLET-NAME/UNIQUE-NAME">

</script>
```

Remember the example I gave you above? 

```xml
<script type="text/x-handlebars" data-template-name="/connectors/topic-above-post-stream/foobar">
  <div style="height: 200px; width: 200px;background: red"></div>
</script>
```

Here's what that results in

![43|579x499, 75%](/assets/beginners-guide-47.PNG)

I've just added a random red box above the post stream on topic pages.

Let's try something else

```xml
<script type="text/x-handlebars" data-template-name="/connectors/category-title-before/foobar2">
  <div style="height: 25px; width: 25px;background: red"></div>
</script>
```

Try to read :point_up: this and see if you can figure out what I'm trying to do there...

Well, I added a tiny box before the title of every category.

here it is

![44|578x500, 75%](/assets/beginners-guide-48.PNG)

[quote="You,"]
Ok, but how do I find those plugin-outlets?
[/quote]

The easiest way to find plugin-outlets is to search for `PluginOutlet` in the Discourse repository 

[https://github.com/discourse/discourse/search?q=PluginOutlet](https://github.com/discourse/discourse/search?q=PluginOutlet)

[quote="You,"]
Well, what if there's no plugin-outlet for the exact area I want to target?
[/quote]

You can submit a PR to add it! As long as the plugin-outlet has valid uses, we'll gladly add it to Discourse core.

[quote="You,"]
Well, all of this is about adding new elements, what if I want to remove an element or modify an existing element? 
[/quote]

Well, this is where overriding Handlebars templates comes in

##### Overriding Discourse templates

Just like you can add new elements to templates, you can make changes to existing elements by overriding the template. A word of caution first. When you override a template, you're essentially using a new template in its place. While this is not inherently a bad thing. it does come with increased maintenance. 

If you override a template (the `topic-list-item` for example) and subsequent changes are made to that template in Discourse core, you need to make sure you update your template to make sure everything works as expected. Think of it like maintaining a fork on Github.  

[quote="You,"]
You're blabbering again...
[/quote]

Fine.. :expressionless:

Here's how to override a template

```xml
<script type="text/x-handlebars" data-template-name="application">

</script>
```

It's very similar to how you would modify a template with a plugin-outlet, the difference being the way you specify the `data-template-name` attribute.

When you specify a template to override, you need to know its name. In the Discourse repository, all templates live here (bookmark that page)

 https://github.com/discourse/discourse/tree/master/app/assets/javascripts/discourse/app/templates

What you need to add as the `data-template-name` attribute is the template name minus the extension so 

```
application.hbs
```

becomes 

```
data-template-name="application"
```

While not obvious in the example above, this is actually the path of the file relative to the `templates` folder. `application.hbs` lives at the root of that folder, so nothing else needs to be added. However, if the template you want to target is inside a subfolder inside the `templates` folder, you need to specify that as well.

For example

https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/templates/list/topic-list-item.hbr

is inside the `list` sub-folder in the `templates` folder, so to target it you need to write

```
data-template-name="list/topic-list-item.hbr"
```
So, we're going to take this:

```xml
<script type="text/x-handlebars" data-template-name="list/topic-list-item.hbr">

</script>
```

Copy / paste the contents of the core template inside it first 
 https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/templates/list/topic-list-item.hbr

And then make whatever modifications we need there. For example, we can remove all poster avatars using something like this

[details="Expand snippet"]
```xml
<script type="text/x-handlebars" data-template-name="list/topic-list-item.hbr">
{{#if bulkSelectEnabled}}
  <td class="bulk-select">
    <input type="checkbox" class="bulk-select">
  </td>
{{/if}}

{{!--
  The `~` syntax strip spaces between the elements, making it produce
  `<a class=topic-post-badges>Some text</a><span class=topic-post-badges>`,
  with no space between them.
  This causes the topic-post-badge to be considered the same word as "text"
  at the end of the link, preventing it from line wrapping onto its own line.
--}}
<td class='main-link clearfix' colspan="{{titleColSpan}}">
  <span class='link-top-line'>
    {{~raw-plugin-outlet name="topic-list-before-status"}}
    {{~raw "topic-status" topic=topic}}
    {{~topic-link topic class="raw-link raw-topic-link"}}
    {{~#if topic.featured_link}}
      {{~topic-featured-link topic}}
    {{~/if}}
    {{~raw-plugin-outlet name="topic-list-after-title"}}
    {{~#if showTopicPostBadges}}
      {{~raw "topic-post-badges" unread=topic.unread newPosts=topic.displayNewPosts unseen=topic.unseen url=topic.lastUnreadUrl newDotText=newDotText}}
    {{~/if}}
  </span>

  {{discourse-tags topic mode="list" tagsForUser=tagsForUser}}
  {{#if expandPinned}}
    {{raw "list/topic-excerpt" topic=topic}}
  {{/if}}
  {{raw "list/action-list" topic=topic postNumbers=topic.liked_post_numbers className="likes" icon="heart"}}
</td>

{{#unless hideCategory}}
  {{#unless topic.isPinnedUncategorized}}
    {{raw "list/category-column" category=topic.category}}
  {{/unless}}
{{/unless}}

{{#if showPosters}}
  {{raw "list/posters-column" posters=topic.posters}}
{{/if}}

{{raw "list/posts-count-column" topic=topic}}

{{#if showParticipants}}
  {{raw "list/posters-column" posters=topic.participants}}
{{/if}}

{{#if showLikes}}
<td class="num likes">
  {{#if hasLikes}}
    <a href='{{topic.summaryUrl}}'>
      {{number topic.like_count}} {{d-icon "heart"}}</td>
    </a>
  {{/if}}
{{/if}}

{{#if showOpLikes}}
<td class="num likes">
  {{#if hasOpLikes}}
    <a href='{{topic.summaryUrl}}'>
      {{number topic.op_like_count}} {{d-icon "heart"}}</td>
    </a>
  {{/if}}
{{/if}}

<td class="num views {{topic.viewsHeat}}">{{number topic.views numberKey="views_long"}}</td>

{{raw "list/activity-column" topic=topic class="num" tagName="td"}}
</script>
```
[/details]

![45|579x500, 75%](/assets/beginners-guide-49.PNG)

Notice the red X. This part of the topic list comes from another template and so you'd need to find that and remove it as well for your design to be consistent... but the change we just made removed all avatar images from the topic list.

As well as removing elements from template, you can add new ones, just like with plugin-outlets and you can also move things around are reorder the template to your liking. 

So, let's try to add a sidebar on desktops next to the latest topic list. 

For this we're going to need to override the `components/topic-list` template. Or this

 
 https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/templates/components/topic-list.hbs

Here's the html for the (basic) sidebar 

```xml
<div class="sidebar">
  <div class="card"></div>
  <div class="card"></div>
  <div class="card"></div>
</div>
```

and here's the SCSS 

```scss
@import "common/foundation/variables";

.sidebar {
  background: $secondary-high;
  padding: 0 1em;
  .card {
  background: $secondary;
  height: 200px;
  width: 200px;
  padding: .5em;
  margin: .5em 0;
  box-sizing: border-box;
  }
}

table.topic-list {
  display: flex;
}
```

We're going to to add the HTML to the `components/topic-list` template and make other adjustments like so

[details="Expand snippet"]
```xml
<script type="text/x-handlebars" data-template-name="components/topic-list">
<div class="sidebar">
  <div class="card"></div>
  <div class="card"></div>
  <div class="card"></div>
</div>
{{plugin-outlet
  name="before-topic-list-body"
  args=(hash
    topics=topics
    selected=selected
    bulkSelectEnabled=bulkSelectEnabled
    lastVisitedTopic=lastVisitedTopic
    discoveryList=discoveryList
    hideCategory=hideCategory)
  tagName=""
  connectorTagName=""}}
<tbody>
    {{raw "topic-list-header"
      canBulkSelect=canBulkSelect
      toggleInTitle=toggleInTitle
      hideCategory=hideCategory
      showPosters=showPosters
      showLikes=showLikes
      showOpLikes=showOpLikes
      showParticipants=showParticipants
      order=order
      ascending=ascending
      sortable=sortable
      listTitle=listTitle
      bulkSelectEnabled=bulkSelectEnabled}}
  {{#each filteredTopics as |topic|}}
    {{topic-list-item topic=topic
                      bulkSelectEnabled=bulkSelectEnabled
                      showTopicPostBadges=showTopicPostBadges
                      hideCategory=hideCategory
                      showPosters=showPosters
                      showParticipants=showParticipants
                      showLikes=showLikes
                      showOpLikes=showOpLikes
                      expandGloballyPinned=expandGloballyPinned
                      expandAllPinned=expandAllPinned
                      lastVisitedTopic=lastVisitedTopic
                      selected=selected
                      tagsForUser=tagsForUser}}
    {{raw "list/visited-line" lastVisitedTopic=lastVisitedTopic topic=topic}}
  {{/each}}
</tbody>
</script>
```
[/details]

And here's our basic sidebar :tada:

![46|580x500, 75%](/assets/beginners-guide-50.PNG)

As an aside: mobile templates are inside the `mobile` subfolder in the `templates` folder. You would do the exact same thing if you want to modify any mobile template. Just be mindful of the path and the file name in the `data-template-name` attribute like we discussed before. 

Template overrides also work with Discourse plugins. When overriding a plugin template, you always need to start your `data-template-name` with `javascripts`. After that, you'll want to add the path of the template relative to the `templates` folder just as you would with core template overrides. 

The path to a plugin's template should look something like

>**plugin-name/assets/javascripts/discourse/templates/template-name.hbs**

And the override would look like this

```xml
<script type="text/x-handlebars" data-template-name="javascripts/template-name">
  
</script>
```

Remember to include a subfolder before the template name if one exists! 

##### Mounting widgets

Since modifying / overriding templates is something you might be doing quite a bit, let's do something a little bit more advanced. We're going to mount a widget and add it to a template. 

[quote="You,"]
There you go again...backup a bit...what's a widget? 
[/quote]

Since we're still in the Handlebars section of the guide, I'm not going to spend any time explaining what widgets are. I'll do that later, but for now I can give you examples of some Discourse widgets.


- The header is a widget
- The header logo is widget 
- The hamburger menu is a widget
- The categories list inside the hamburger menu is widget

These are just examples of widgets. For now, you can think of them as blocks. All Discourse widgets live here

 https://github.com/discourse/discourse/tree/master/app/assets/javascripts/discourse/app/widgets

[quote="You,"]
Why so fancy? :face_with_raised_eyebrow:
[/quote]

Widgets render faster and _more faster is more better_ :stuck_out_tongue:

[quote="You,"]
I still don't get the point of all of this.
[/quote]

I think the next example will help. First, let's pick a widget. I'll pick the `home-logo` widget, or this

![47|559x499, 80%](/assets/beginners-guide-51.PNG) 

We're going to create a footer theme component and dynamically add the site logo to it. For this I chose to go with the plugin-outlet route instead of overriding a template because there's a plugin-outlet that works for our purposes 

```handlebars
{{plugin-outlet name="below-footer" args=(hash showFooter=showFooter)}}
``` 

which you can find [here](https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/templates/application.hbs#L28)

So, based on our previous discussion about plugin-outlets, we're going to need something like this

```xml
<script type="text/x-handlebars" data-template-name="/connectors/below-footer/fancy-footer">

</script>
```

Now, mounting a widget is pretty simple, all you need to know is the widget's name. That's it. We already know the name of the widget we want to use and it's `home-logo` and so here's what we need in order to mount it and add it to the template via the plugin-outlet

```handlebars
{{mount-widget widget="home-logo"}}
```

Now we add a bit of HTML around it like so

```xml
<script type="text/x-handlebars" data-template-name="/connectors/below-footer/fancy-footer">
<div class="footer">
  <div class="wrap">
    <ul>
      <li><a href="/about">About</a></li>
      <li><a href="/Privacy">Privacy</a></li>
      <li><a href="/TOS">Terms of Service</a></li>
    </ul>
    <div class="footer-logo">
      {{mount-widget widget="home-logo"}}
    </div>
  </div>
</div>
</script>
```
and a sprinkle of SCSS

```scss
@import "common/foundation/variables";

.footer {
  background: $primary-low;
  .wrap {
    display: flex;
  }
  ul {
    display: flex;
    flex: 1;
    margin: 0;
  }
  li {
    list-style: none;
    margin: 1em;
    font-size: $font-up-1;
    color: $secondary;
  }
  .footer-logo {
    display: flex;
    align-items: center;
    img {
      max-height: 40px;
    }
  }
}
```

annnnnd.....

![48|576x499, 75%](/assets/beginners-guide-52.PNG) 

:tada:

[quote="You,"]
So far, we've covered a lot of SCSS, HTML, and Handlebars, what about JS / jQuery? Are there any cool things I can do with those? 
[/quote]

I'm glad you asked. Meet the pluginAPI :sunglasses:

#### The pluginAPI

In a nutshell, the PluginAPI is an easy way for you to write JS / jQuery and make Discourse do <s>things</s> amazing things! 

[quote="You,"]
Like what?
[/quote]

Here are a couple of examples.

[Brand header theme component:](https://meta.discourse.org/t/brand-header-theme-component/77977)

This theme component uses the pluginAPI to create new widgets. Those widget include a brand header above the Discourse header and a new hamburger menu on mobile. It looks like this:

![49|578x499, 75%](/assets/beginners-guide-53.PNG) 

[Discourse category banners:](https://meta.discourse.org/t/discourse-category-banners/86241) 

This component uses the pluginAPI to create dynamic banners and place them at the top of each category page, it automatically fetches the category name, description and color and it looks like this:

![50|577x500, 75%](/assets/beginners-guide-54.PNG) 

[quote="You,"]
So, where do I start if I want to use the pluginAPI?
[/quote]

You start here:

 https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs

This is the file in the Discourse repository where all the pluginAPI methods are defined.

I will go through the one's you're most likely to use and provide examples as a way of explaining how they work, but first, a bit of background.

When you use the pluginAPI, you have to use special `<script>` tag attributes in order for things to work properly. You're probably very used to seeing things like


```xml
<script>
    alert('Hello world!')
</script>
```

or 

```xml
<script type="text/javascript">
    alert('Hello world!')
</script>
```
And what you need for the pluginAPI is this

```xml
<script type="text/discourse-plugin" version="0.8">
    alert('Hello world!')
</script>
```

The two new things here are the `type` attribute and the `version` attribute. 

The `type` attribute is self explanatory. The `version` attribute helps you ensure stability. Say for example you create a theme that uses a pluginAPI method that was just introduced to Discourse core. You would then set the version to one that matches the core pluginAPI version number that introduced the new method. 

[quote="You,"]
Why would I need to do that? 
[/quote]

In case someone with an outdated Discourse installs your theme. They would then see a message in the console instead of their site breaking. 

![51|690x46, 75%](/assets/beginners-guide-55.PNG) 

Which brings me to the next point.

##### console.log is your friend!

I cannot begin to emphasize the importance of using `console.log()` enough. If you're ever lost, or not sure about something always use `console.log()` 

Let's try this

```xml
<script type="text/discourse-plugin" version="0.8">
    console.log(Discourse)
</script>
```

What I've done here is logged `Discourse` which is a global object to the console. Now if I check and see what I get

![52|690x384](/assets/beginners-guide-56.PNG) 

you'll notice a vary large amount of things are now available to me to use, for example, site settings, which I highlighted above. 

But this is just a warm up, let's try a quick demo

```xml
<script type="text/discourse-plugin" version="0.8">
  const settings = Discourse.SiteSettings,
    taggingEnabled = settings.tagging_enabled,
    title = settings.title;

  if (taggingEnabled) {
    console.log("Yay! "+title+" has tagging enabled!")
  } else {
    console.log("Ohh nooos! "+title+"Does not allow tagging.")
  }
</script>
```

As it turns out, Theme creator does allow tags to be used, so if I check the console

![53|559x93, 75%](/assets/beginners-guide-57.PNG) 

So, I'll say this one more time for good measure, if you're lost at any point use

```javascript
console.log($(this))
```

and check the console to see what you have to work with.  

So, with all of that out of the way, here are the methods currently in the pluginAPI

##### getCurrentUser()

This method allows you get information about the current user. if we try something like this

```xml
<script type="text/discourse-plugin" version="0.8">
  const user = api.getCurrentUser();
  
  console.log(user)
</script>
```
We can easily find things like the current user's username. Now let's try to do something with that information on our previous "hello world!" banner.

```xml
<script type="text/discourse-plugin" version="0.8">
  $( document ).ready(function() {
    const user = api.getCurrentUser(),
      username = user.username;

    $('h1.hello-world').html('Hello there '+username+"!")
  });
</script>
``` 

![image|579x499](/assets/beginners-guide-58.png)

Where `username` will be dynamic and will match the current user's username.

There's a lot more than username for you to use, but I wanted to keep it simple. Use

```xml
<script type="text/discourse-plugin" version="0.8">
  const user = api.getCurrentUser();
  
  console.log(user)
</script>
```

Check the console and see what else you can use. 

##### replaceIcon()

```javascript
api.replaceIcon(source, destination)
```

With this method, you can easily replace any Discourse icon with another. For example, we have a theme component that replaces the heart icon for like with a thumbs-up icon 

https://meta.discourse.org/t/change-the-like-icon/87748

that uses something like this

```javascript
api.replaceIcon('heart', 'thumbs-up');
```

And it looks like this

![55|413x78, 75%](/assets/beginners-guide-59.PNG)
 
##### modifyClass()

You can use this method to extend or overwrite methods in a class like a component or controller (read: [Ember Classes](https://guides.emberjs.com/release/object-model/classes-and-instances/)), but it's also a great way to get information and set variables. 

```xml
<script type="text/discourse-plugin" version="0.8">
  api.modifyClass('controller:composer', {
    actions: {
      newActionHere() { }
    }
  });
</script>
```
[quote="You,"]
WAIT! I'm so confused! components... controllers?! 
[/quote]

Don't get confused by all the new terms here.

> Ember components are used to encapsulate markup and style into reusable content. Components consist of two parts: a JavaScript component file that defines behavior, and its accompanying Handlebars template that defines the markup for the component's UI.

For the purposes of this guide, Think of controllers in the same way.

Let's pick a controller and play around and see what we can achieve. In the Discourse repository, all controllers live here 

 https://github.com/discourse/discourse/tree/master/app/assets/javascripts/discourse/app/controllers

I'm going to pick the [composer controller](https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/controllers/composer.js) and we're going to try to capture every keypress in the editor. First, let's take a look at what's available for us to use. 

https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/controllers/composer.js#L578

This looks very close to what I want to achieve, so we start with this 

```xml
<script type="text/discourse-plugin" version="0.8">
api.modifyClass("controller:composer", {

});
</script>
```

Then add the action we want to overwrite as is

```xml
<script type="text/discourse-plugin" version="0.8">
api.modifyClass("controller:composer", {
  actions: {
    typed() {
      this.checkReplyLength();
      this.get("model").typing();
    }
  }
});
</script>
```

And then we finally add our change 

```javascript
console.log("typed a letter");
```

Which should leave a message in the console at every keystroke

```xml
<script type="text/discourse-plugin" version="0.8">
api.modifyClass("controller:composer", {
  actions: {
    typed() {
      console.log("typed a letter");
      this.checkReplyLength();
      this.get("model").typing();
    }
  }
});
</script>
```

And we test it

![56|690x147, 75%](/assets/beginners-guide-60.PNG) 

Since this is also a thing you might be doing a lot of, let's go through another example. 

This time we will try to capture when the user enters / loads the categories page. The categories page is a component. All the components in the Discourse repository live here

 https://github.com/discourse/discourse/tree/master/app/assets/javascripts/discourse/app/components

and we can find the one we're after here

 https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/components/discovery-categories.js


so we're going to need something like this

```xml
<script type="text/discourse-plugin" version="0.8">
api.modifyClass("component:discovery-categories", {

});
</script>
```

If you want to fire scripts when a component is loaded you can use something like this 

```javascript
didInsertElement: function() {
  this._super();
  // do your work here
}
```

So we end up with this 

```xml
<script type="text/discourse-plugin" version="0.8">
api.modifyClass("component:discovery-categories", {
  didInsertElement: function() {
    this._super();
    console.log("Welcome to the categories page!")
  }
});
</script>
```

Now all that's left is to check and see if it works

![57|690x428, 75%](/assets/beginners-guide-61.PNG) 

et voilà :tada:

We can now move on to doing something similar with widgets.


I mentioned earlier, that we'll cover widgets and so here's what you need to know about them before we move on to the next few methods. 

[quote="eviltrout, post:1, topic:40347"]
A `Widget` is a class with a function called `html()` that produces the virtual dom necessary to render itself. Here’s an example of a simple `Widget` :
[/quote]
```javascript
import { createWidget } from 'discourse/widgets/widget';

createWidget('my-widget', {
  tagName: 'div.hello',

  html() {
    return "hello world";
  }
});
```
[quote="eviltrout, post:1, topic:40347"]
The above code registers a widget called `my-widget` , which will be rendered in the browser as `<div class='hello'>`
[/quote]

With this basic understanding, we can move on to the things you can do with widgets. There are three things you can do to widgets in Discourse themes.
1. Modify them - like we did with controllers  and components
2. Decorate them - as in add elements before or after them
3. Create them from scratch 

Well, it turns out the pluginAPI has a method for each of these. So let's have a look at those methods, but before we start. Here's where all the widgets live in the Discourse repository 

 https://github.com/discourse/discourse/tree/master/app/assets/javascripts/discourse/app/widgets

##### reopenWidget()

Let's start with the reopen widget method. This method is similar to what we did with controllers and components. I have a bit of a lengthy example, but it does demonstrate how much flexibility the pluginAPI offers you as theme developer. The example is the [Alternative Logo theme component](https://meta.discourse.org/t/alternative-logo-for-dark-themes/88502)

> This is a theme component that will allow you to add alternative logos for dark / light themes.

At its heart, this theme only overwrites one of the functions of the [home-logo widget](https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/widgets/home-logo.js)

So, we already know the name of the widget we want to reopen. it's `home-logo` and so we start with this

```xml
<script type="text/discourse-plugin" version="0.8.13">
api.reopenWidget("home-logo", {

});
</script>
```

then find the function that we want to overwrite in that widget. Here I want to change the logo image so this looks promising.

https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/widgets/home-logo.js#L31

So we copy that function as is first


[details="Expand snippet"]
```xml
<script type="text/discourse-plugin" version="0.8.13">
api.reopenWidget("home-logo", {
  logo() {
    const { siteSettings } = this;
    const mobileView = this.site.mobileView;

    const mobileLogoUrl = siteSettings.mobile_logo_url || "";
    const showMobileLogo = mobileView && mobileLogoUrl.length > 0;

    const logoUrl = siteSettings.logo_url || "";
    const title = siteSettings.title;

    if (!mobileView && this.attrs.minimized) {
      const logoSmallUrl = siteSettings.logo_small_url || "";
      if (logoSmallUrl.length) {
        return h("img#site-logo.logo-small", {
          key: "logo-small",
          attributes: {
            src: Discourse.getURL(logoSmallUrl),
            width: 33,
            height: 33,
            alt: title
          }
        });
      } else {
        return iconNode("home");
      }
    } else if (showMobileLogo) {
      return h("img#site-logo.logo-big", {
        key: "logo-mobile",
        attributes: { src: Discourse.getURL(mobileLogoUrl), alt: title }
      });
    } else if (logoUrl.length) {
      return h("img#site-logo.logo-big", {
        key: "logo-big",
        attributes: { src: Discourse.getURL(logoUrl), alt: title }
      });
    } else {
      return h("h1#site-text-logo.text-logo", { key: "logo-text" }, title);
    }
  }
});
</script>
```
[/details]

And then adjust it according to the desired behavior. In my case it was like this

[details="Expand snippet"]
```xml
<script type="text/discourse-plugin" version="0.8.13">
api.reopenWidget("home-logo", {
  logo() {
    const { siteSettings } = this,
      { iconNode } = require("discourse/helpers/fa-icon-node"),
      h = require("virtual-dom").h,
      altLogo = settings.Alternative_logo_url,
      altLogoSmall = settings.Alternative_small_logo_url,
      mobileView = this.site.mobileView,
      mobileLogoUrl = siteSettings.mobile_logo_url || "",
      showMobileLogo = mobileView && mobileLogoUrl.length > 0;
    (logoUrl = altLogo || ""),
    (title = siteSettings.title);
    if (!mobileView && this.attrs.minimized) {
      const logoSmallUrl = altLogoSmall || "";
      if (logoSmallUrl.length) {
        return h("img#site-logo.logo-small", {
          key: "logo-small",
          attributes: { src: logoSmallUrl, width: 33, height: 33, alt: title }
        });
      } else {
        return iconNode("home");
      }
    } else if (showMobileLogo) {
      return h("img#site-logo.logo-big", {
        key: "logo-mobile",
        attributes: { src: mobileLogoUrl, alt: title }
      });
    } else if (logoUrl.length) {
      return h("img#site-logo.logo-big", {
        key: "logo-big",
        attributes: { src: logoUrl, alt: title }
      });
    } else {
      return h("h1#site-text-logo.text-logo", { key: "logo-text" }, title);
    }
  }
});
</script>
```
[/details]

A quick summary of the changes in the above snippet

1. Replace the variables for the URL of the logo
3. Pull the value of those variables from the theme's settings - we'll talk about theme settings a bit later on. 

You can do the same for any function in any widget using the `reopenWidget()` pluginAPI method.

We can now move on to another thing you can do to widgets


##### decorateWidget()

 With this method you will be able to add html before or after a widget. You use it like this

```xml
<script type="text/discourse-plugin" version="0.8">
  api.decorateWidget('NAME:LOCATION', helper => {

  });
</script>
```
Where name is the NAME of the widget and LOCATION is either `before` or `after` depending on where you want your HTML to show up - before or after the widget.

So this

```xml
<script type="text/discourse-plugin" version="0.8">
  api.decorateWidget('post:after', helper => {
    return helper.h('p', 'Hello');
  });
</script>
```

Would add `<p>Hello</p>` after every "post" widget like so

![58|549x500, 75%](/assets/beginners-guide-62.PNG) 

and this 

```xml
<script type="text/discourse-plugin" version="0.8">
  const { iconNode } = require("discourse-common/lib/icon-library");
  api.decorateWidget('header-icons:before', helper => {
      return helper.h('li', [
          helper.h('a.icon', {
              href:'https://foo.bar.com/',
              title: 'Foobar'
          }, iconNode('heart')),
      ]);
  });
</script>
```

would add 

```xml
<li>
  <a href="https://foo.bar.com/" title="Foobar" class="icon">
    <svg class="fa d-icon d-icon-heart svg-icon svg-node" aria-hidden="true">
      <use xlink:href="#heart"></use>
    </svg>
  </a>
</li>
```

right before the header icons widget.

![59|518x500](/assets/beginners-guide-63.PNG) 

This leaves us with one last things you can do with widgets. Create them! 

##### createWidget()

Now that you have a basic understanding of widgets, you're in a good place to create one! The pluginAPI has a method that makes this super easy.

Here's a basic example

```xml
<script type="text/discourse-plugin" version="0.8">
  const h = require("virtual-dom").h;

  api.createWidget("my-first-widget", {
    tagName: "div.my-widget",

    html() {
      return h('h1', "Hello World!");
    }
  });
</script>
```

Start by requiring the relevant bit from the virtual dom library 

```javascript
const h = require("virtual-dom").h;
```

This allows you to add html element in a more efficient way. 

```javascript
h('h1', "Hello World!")
```
Is the exact same as 

```xml
<h1>Hello World!</h1>
```
And while it may look like the same amount of code for one element, it scales a lot better. 

For a quick example, this - when set up to loop
```javascript
return h(
  "li.headerLink." + seg[3] + "." + seg[5],
  helper.h(
    "a",
    {
      href: seg[2],
      title: seg[1],
      target: seg[4]
    },
    seg[0]
  )
);
```

can produce 


[details="Expand snippet"]
```xml
<li class="headerLink vdo">
  <a href="/c/tech" title="Discussions about technology" target="">Tech</a>
</li>
<li class="headerLink vdo">
  <a href="https://www.vat19.com/" title="Buy some cool stuff" target="_blank">Shop</a>
</li>
<li class="headerLink vdo">
   <a href="/t/284" title="Mobile OS poll" target="">Your Vote Counts!</a>
</li>
<li class="headerLink vdo keep">
  <a href="/latest/?order=op_likes" title="Posts with the most amount of likes" target="">Most Liked</a>
</li>
<li class="headerLink vdm keep">
  <a href="/privacy" title="Our Privacy Policy" target="">Privacy</a>
</li>
```
[/details]

But is a lot more maintainable

[quote="You,"]
again with the blabbering... :roll_eyes:
[/quote]

Ok...fine let's go back to creating a widget. So now we have this

```xml
<script type="text/discourse-plugin" version="0.8">
  const h = require("virtual-dom").h;

  api.createWidget("my-first-widget", {
    tagName: "div.my-widget",

    html() {
      return h('h1', "Hello World!");
    }
  });
</script>
```

Which creates the widget.  and if you remember, we can mount widgets in Handlebars template. So we can do something like this

```xml
<script type="text/x-handlebars" data-template-name="/connectors/above-footer/inject-widget">
  {{mount-widget widget="my-first-widget"}}
</script>
```

and add bit of SCSS 

```scss
@import "common/foundation/variables";

.my-widget {
  display: flex;
  align-items: center;
  justify-content: center;
  background: $primary-high;
  h1 {
  padding: .5em;
  color: $secondary;
  margin: 0;
  }
}
``` 
And we're done, your first Discourse Widget! 

![60|546x499, 75%](/assets/beginners-guide-64.PNG) 

Here are a couple more examples that you can look at to see `createWidget` in action 

Brand header theme component:

[https://github.com/discourse/discourse-brand-header/blob/master/common/header.html](https://github.com/discourse/discourse-brand-header/blob/master/common/header.html)

Discourse Category banners theme component:

[https://github.com/awesomerobot/discourse-category-banners/blob/master/common/header.html](https://github.com/awesomerobot/discourse-category-banners/blob/master/common/header.html)

This covers creating, modifying and decorating widgets. The three things I said you can do to widget with Discourse themes, but I lied :lying_face:

There's actually one more thing you can do with some widgets, change their settings

##### changeWidgetSetting()

Some widgets like the `home-logo` or the `post-avatar` widgets have settings. If a widget has settings, you can easily change those settings with the pluginAPI

For example, the `post-avatar` widget has these

https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/widgets/post.js#L157

and the `home-logo` widget has this

https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/app/widgets/home-logo.js#L10

To, change a setting you can do something like this

```xml
<script type="text/discourse-plugin" version="0.8">
  api.changeWidgetSetting('WIDGET-NAME', 'SETTING-NAME', 'VALUE');
</script>
```

So to change the avatar `size` setting in the `post-avatar` widget we can use 

```xml
<script type="text/discourse-plugin" version="0.8">
  api.changeWidgetSetting('post-avatar', 'size', '90');
</script>
```

and to change the `href` setting in the `home-logo` widget we would use 

```xml
<script type="text/discourse-plugin" version="0.8">
  api.changeWidgetSetting('home-logo', 'href', 'https://some.url.com');
</script>
```

##### addNavigationBarItem()

You use this method to add new items to the navigation bar here

![61|545x499, 75%](/assets/beginners-guide-65.PNG) 

To add a new link you use something like this

```xml
<script type="text/discourse-plugin" version="0.8">
  api.addNavigationBarItem({
    name: "link-to-movies-category",
    displayName: "movies",
    href: "/c/movies",
    title: "link title"
  })
</script>
```

To add a link to the "movies" category in the navigation menu like so

![62|547x500, 75%](/assets/beginners-guide-66.PNG) 

##### addUserMenuGlyph()

You use this method to add a new linked icon to the user menu

![63|690x239, 60%](/assets/beginners-guide-67.PNG) 

Here's an example, let's say you want to add a link to the users mentions page, you would then use something like

```xml
<script type="text/discourse-plugin" version="0.8">
api.addUserMenuGlyph({
  label: 'Mentions',
  className: 'mention-link',
  icon: 'at',
  href: '/my/notifications/mentions'
});
</script>
```

Which creates a new icon that takes the user to their mentions page when clicked 

![64|690x226, 60%](/assets/beginners-guide-68.PNG) 

##### decorateCooked()

Posts in Discourse are widgets, as such, the contents of a post will not be available for you to target with JS or jQuery. Luckily though, the pluginAPI provides you with a method to reach those contents.  The basic usage for this method is

```xml
<script type="text/discourse-plugin" version="0.8">
  api.decorateCooked($elem => $elem.children('p').addClass('foo-class'));
</script>
```

This will find all `<p>` tags in the cooked content of a post and add the class `foo-class` to them

![66|690x339, 60%](/assets/beginners-guide-69.PNG) 

That's the basics of it, but if you need to do something a little bit more complicated, I suggest [writing your own jQuery mini plugin](https://learn.jquery.com/plugins/basic-plugin-creation/) like so 

```javascript
var tiles_selector = '.cooked div[data-theme-tiles="1"]';
$.fn.dtiles = function() {
  this.each(function() {
    var update = function() {
      $(this).masonry({
        itemSelector: ".lightbox-wrapper",
        transitionDuration: 0
      });
    };
    this.addEventListener("load", update, true);
  });
  return this;
};

api.decorateCooked($elem =>
  $elem
    .children(tiles_selector)
    .dtiles()
    .addClass("tiles-initialized")
);
```

This is how the [Tiles image gallery ](https://meta.discourse.org/t/tiles-image-gallery/81950) theme component works. 

##### onToolbarCreate()

This is the method that you would use to add new buttons to the composer toolbar.

![67|690x234, 70%](/assets/beginners-guide-70.PNG) 

You would use it like this

```xml
<script type="text/discourse-plugin" version="0.8">
  const currentLocale = I18n.currentLocale();
  if (!I18n.translations[currentLocale].js.composer) {
    I18n.translations[currentLocale].js.composer = {};
  }
  I18n.translations[currentLocale].js.composer.my_button_text = "Hey there!";
  I18n.translations[currentLocale].js.my_button_title = "My Button!";

  api.onToolbarCreate(function(toolbar) {
    toolbar.addButton({
      trimLeading: true,
      id: "buttonID",
      group: "insertions",
      icon: 'heart',
      title: "my_button_title",
      perform: function(e) {
        return e.applySurround(
          '<div data-theme="foo">\n\n',
          "\n\n</div>",
          "my_button_text"
        );
      }
    });
  });
</script>
```

Note that the translation strings at the top are **required** and kudos to Simon Cossar for coming up with a way to [dynamically setting them based on the user's locale](https://meta.discourse.org/t/what-should-i18n-be-replaced-with-in-new-versions/90944/2?u=johani) 

To add a button with a heart icon that wraps selected text with `<div data-theme="foo"></div>`

![68|690x185, 70%](/assets/beginners-guide-71.png) 

<hr>

The pluginAPI has over 40 methods in it and so we'll stop here because I think the methods above are enough for the purposes of this guide.

However, this doesn't mean that you should not be aware of them. As mentioned before, you can find all the methods in the pluginAPI here in the Discourse repository

 https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs

#### Theme settings

I won't be covering theme settings in the guide since we already have a very good guide detailing how to use them in your themes. 

https://meta.discourse.org/t/how-to-add-settings-to-your-discourse-theme/82557

#### Theme translations

The theme translations system makes sure your theme is ready for a global audience. You can supply text in multiple languages, and Discourse will automatically substitute it in the right place, depending on the users' selected language. For more information, see

https://meta.discourse.org/t/adding-localizable-strings-to-themes-and-theme-components/109867

### Best practices

Now that you are familiar with Discourse theme basics, let's move on to a few recommendations that will make your life as a Discourse theme developer a lot easier. 

##### Use Prettier

Prettier is a code formatting tool. The files on the Discourse repository are Prettified for consistent code formatting. It makes your code easier to read and...wait for it....pretty!

You can read more about Prettier here:

https://meta.discourse.org/t/prettier-code-formatting-tool/93212

##### How to ask for help

If you're stuck on something that relates to themes, feel free to create a post in the #dev category. Be sure to include as much information as you can and anything you've tried. The more effort you put into your question, the more likely you'll get an answer.

You'll get extra attention if you make it clear that the help you need is for a theme you intend to release here on Meta. 

##### Include a license

Including a license with your theme makes it clear that it's intended to be shared. I recommend the MIT license or equivalent for open source themes.  

##### Creating a topic for your theme on Meta

If you'd like to share your theme here on Meta, please consider including the following if applicable

1. Short description at the top
2. Screenshots
3. Preview on theme creator 
4. Instructions for theme settings
5. Link to theme installation guide

<hr>

While we covered a lot of subjects, this guide barely scratches the surface and there's obviously things I may have missed.

If you have any questions, please don't hesitate to ask.

This guide is a wiki, if you have any improvements, please go ahead and make them by editing the topic.

<div data-theme-toc="true"></div>
