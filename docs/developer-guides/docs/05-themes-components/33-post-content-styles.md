---
title: Customize posts' contents with your own styles
short_title: Post content styles
id: post-content-styles
---

<div data-theme-toc="true"> </div>

## Requirements

:information_source: To be able to use these tips and tricks, you need to be an administrator of either a self-hosted Discourse instance or a [Discourse-hosted plan](https://discourse.org/pricing) higher than **Basic**.

## Introduction

Discourse supports several methods to format and customize a post's contents. You can find the list here:
https://meta.discourse.org/t/supported-formatting-in-posts-markdown-bbcode-and-html/239348?u=canapin

But sometimes, you'll want something more specific, for example, a link that looks like a button.

![Green button|275x62](/assets/post-content-styles-1.png)

This is the kind of modification we'll learn here.

## The logic

I'll briefly explain the logic behind but you can go to the next step and jump into a practical example :)

Discourse allows any HTML attribute starting with `data-` in a post's content.
Those are the attributes we'll target with CSS to customize our content.

I'll call them **`data-` attributes** in this tutorial :)

One way to create elements with these attributes is a BBcode-like tag: `[wrap]`, to which we'll add a value of our choice. Here we choose "button" (that could be anything else, even the name of your dog :dog:):

```md
[wrap=button]some text[/wrap]
```

This will output an HTML element having the following attribute: `data-wrap="button"`.

## First example: a pink background

Let's start with a practical example. We'll create text with a pink background.

### As a _block_ element

In your post, on an empty line, write:

```md
[wrap=pink]pink text[/wrap]
```

![block wrap|259x110](/assets/post-content-styles-2.png)

It will create a `div` element having the attribute `data-wrap="pink"`.

Then, add the following CSS to your theme.
Go to Admin panel -> Customize -> Themes -> your theme -> Edit CSS/HTML -> CSS.

Put the following CSS code inside:

```css
[data-wrap="pink"] {
  background: pink;
}
```

Then click the Save button.

![wrap css|355x214](/assets/post-content-styles-3.png)

Go back to your post, and see the result:
![image|690x287](/assets/post-content-styles-4.png)

Yes, it is already beautiful :cherry_blossom:

You'll notice that the background covers the whole post width. Because our wrap is the only element on its line, it outputs a **block** element.
You can learn more about the difference between **blocks** and **inline** HTML elements here: https://www.w3schools.com/html/html_blocks.asp.

If you want your pink background on multiple lines (still as a **block**), you'll need both your `[wrap]` tags having no other content or text on the same line:

```md
[wrap=pink]
pink text
pink text
pink text
pink text
[/wrap]
```

This will look like this:

![image|690x286](/assets/post-content-styles-5.png)

### As an _inline_ element

Now, let's add some text before the `[wrap]`, or after, or both :smile:. For example:

`Here is some [wrap=pink]pink text[/wrap] and it's awesome ✨`

Here's the result:
![image|690x286](/assets/post-content-styles-6.png)

If text or other elements are on the same line as one of your `[wrap]` tags, it will output an **inline** element.

## Second example: a link with a button's appearance.

Fiddling with the `[wrap]` tag can sometimes lead to unwanted results for various reasons, one being that it can be a block or an inline element depending on the context.
So, we'll describe two different methods that achieve the same result, but you'll be able to pick the one that suits you the most :v:

### An inline button link with `[wrap]`

The syntax to create a link using markdown is: `[some text](https://some-link.etc)`.
To customize the text and make it appear like a button, we'll insert the wrap inside the square brackets. Here's an example:

```md
This [[wrap=button]nice link[/wrap]](https://discourse.org/) is a blue button 🐳 !
```

We won't comment on what this code outputs. You know that because you wrote `[wrap=button]`, you'll have to target `[data-wrap="button"]` in your CSS.

So, let's go, let's add some fancy CSS to make it pretty! :sparkles:

```css
[data-wrap="button"] {
  display: inline-block;
  padding: 0.5em 1em;
  background: DodgerBlue;
  color: White;
}
```

We won't detail the CSS rules here. There are many CSS resources on the Internet, so if you want to do more specific modifications, you'll have to learn about it first. :slight_smile:

The result :magic_wand: :
![Blue button|690x279](/assets/post-content-styles-7.png)

That looks good, right?

### An inline button link with regular HTML content

Since Discourse accepts HTML code, we can decide not to use the `[wrap]` tags and use HTML with a `data-` attribute. In this example, we'll use the regular Markdown syntax for the link and surround it with `<span>` tags.
:information_source: We can't directly use a link `<a>` tag because it's an exception and won't allow any `data-` attribute.

Write:

```md
This <span data-button>[link](https://discourse.org/)</span> is a green button 🐸 !
```

It will output a link **inside** a `<span>` tag having a `data-button` attribute, which means the CSS will be a bit more complicated. We will have to target both `data-button` and the link:

```css
[data-button] {
  display: inline-block;
  padding: 0.5em 1em;
  background: ForestGreen;
  a {
    color: White;
  }
}
```

And here's the result!
![image|690x280](/assets/post-content-styles-8.png)

## To go further

### A customized list using `[wrap]`

`[wrap]` tags and `data-` attributes can be used in many contexts and you can customize more advanced content. The limit is mostly your CSS knowledge (and HTML to a lesser extent).

I'll give a single example without explanation by customizing a list in which each element will be prepended with a cat emoji:

Text:

```md
[wrap=cat]

- Felix
- Garfield
- Nat's cat
  [/wrap]
```

CSS:

```css
[data-wrap="cat"] ul {
  list-style: none;
  li:before {
    content: "🐈";
    margin-right: 0.25em;
  }
}
```

Result:

![Cat list|690x280](/assets/post-content-styles-9.png)

### Using your own theme's colors variables

If you allow users to use different themes or colors, your modifications may not look good for each one, especially if they have choices between light and dark color schemes.

A good practice is using Discourse's color variables instead of "hardcoded" colors such as `red`, `#FF0000` or `rgb(255,0,0)`.

Here's an example in which the button's background color will use the primary color of the current palette, and the text will use the secondary color:

Text:

```md
This [[wrap=button]nice link[/wrap]](https://discourse.org/) is a button 🌈 !
```

CSS:

```css
[data-wrap="button"] {
  display: inline-block;
  padding: 0.5em 1em;
  background: var(--primary);
  color: var(--secondary);
}
```

Here's how it will look for a user using the Solarized Light color scheme:

![Solarized Light button|690x280](/assets/post-content-styles-10.png)

And if they use the Solarized Dark color scheme:

![Solarized Dark button|690x280](/assets/post-content-styles-11.png)

## Conclusion

You now have the basics to create custom elements using the `[wrap]` element and the `data-` attributes.

To make more advanced customizations, learning CSS is primordial. You'll find many tutorials on the Internet.

The following Discourse's guide can also be of some help: https://meta.discourse.org/t/make-css-changes-on-your-site/168101?u=canapin.
Using the developer's tools of your Internet Browser will also easily show you the list of your Discourse's color variables and what each looks like:
![image|244x500](/assets/post-content-styles-12.png)

---

:raised_hand_with_fingers_splayed: Feel free to suggest any modification for this guide!
