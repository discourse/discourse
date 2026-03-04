---
title: Repackaging a markdown-it extension as a Discourse plugin
short_title: markdown-it extension
id: markdown-it-extension
---

[markdown.it](https://github.com/markdown-it/markdown-it) the CommonMark engine used by Discourse has a [wide array of plugins](https://www.npmjs.com/search?q=keywords:markdown-it-plugin)

Header anchors, definition lists, smart-arrows and the list goes on and on.

> #### First a warning
>
> :warning: CommonMark is meant to be… Common. The further you move away from the spec the less Common your Markdown becomes. It can make it harder to port to other solutions and, if not careful, cause internal inconsistencies in parsing. Before repackaging anything be sure to answer the question "do I really want to repackage this?"

I just finished repackaging https://meta.discourse.org/t/discourse-footnote/84533 and have some lessons to share about how to do this right.

#### Steps for the lazy

If you are lazy and just want to get started the easiest way is just to fork footnotes and swap files and var names. I was pretty careful to make sure it follows best practices so you should have solid example.

#### Opening moves, a minimal repackage

From what I can tell the majority of markdown.it plugins are shipped as vanilla js files. In many cases plugins are simply shipped as a single js file, like this: [markdown-it-mark.js](https://github.com/markdown-it/markdown-it-mark/blob/00a122a726d91316fab66a452b495d3b14cf1615/dist/markdown-it-mark.js).

Ideally you want to leave the **original** intact, that means you can simply copy an updated version of the file into your plugin without needing to mess with the existing plugin.

The first problem you will hit is that you have to teach your plugin to load this JavaScript on the server cause the Markdown engine runs on the server as well. To do though you can simply copy the file as is into `assets/javascripts/vendor/original-plugin.js` then in your `plugin.rb` file you would add:

```rb
# this teaches our markdown engine to load your vanilla js file
register_asset "javascripts/vendor/original-plugin.js", :vendored_pretty_text
```

Once you have the actual body of the plugin included you need to teach our pipeline how to load and initialize it:

Create a file called `assets/javascripts/lib/discourse-markdown/your-extension.js`

This file will be auto loaded cause it ends with `.js` AND in the `discourse-markdown` directory.

A simple example can be:

```js
export function setup(helper) {
  // this allows you only to load your extension if a site setting is enabled
  helper.registerOptions((opts, siteSettings) => {
    opts.features["your-extension"] = !!siteSettings.enable_my_plugin;
  });

  // whitelist any attributes that you need to support,
  // otherwise our sanitizer will strip them
  helper.whiteList(["div.amazingness"]);

  // you can also do fancy stuff like this
  helper.whiteList({
    custom(tag, name, value) {
      if ((tag === "a" || tag === "li") && name === "id") {
        return !!value.match(/^fn(ref)?\d+$/);
      }
    },
  });

  // finally this is the magic that you would use to register the extension in
  // our pipeline. whateverGlobal is the name of global the plugin exposes
  // it takes in a single (md) var that is then used to amend the pipeline
  helper.registerPlugin(window.whateverGlobal);
}
```

### Always be testing

Discourse's `bin/rake autospec` is plugin aware :innocent:

This means that when you add the file `spec/pretty_text_spec.rb` every time you save it the plugin test file will run.

I use this extensively cause it makes work so much faster.

Say you added a plugin that changes every number in a post to 8 circle, you can call it discourse-magic-8-ball.

Here is how I would structure the tests:

```rb
require "rails_helper"

describe PrettyText do
  it "can be disabled" do
    SiteSetting.enable_magic_8_ball = false

    markdown = <<~MD
      1 thing
    MD

    html = <<~HTML
      <p>1 thing</p>
    HTML

    cooked = PrettyText.cook markdown.strip
    expect(cooked).to eq(html.strip)
  end

  it "supports magic 8 ball" do
    markdown = <<~MD
      1 thing
    MD

    html = <<~HTML
      <p>8 circle thing</p>
    HTML

    cooked = PrettyText.cook markdown.strip
    expect(cooked).to eq(html.strip)
  end
end
```

### You may need to "decorate posts"

In some cases plugins work best when they add extra "dynamic" features to your posts. Examples of that are the `poll` plugin or the `footnotes` plugin that adds a "..." that dynamically shows a tooltip.

if you need to "decorate" posts add `assets/javascripts/api-initializers/your-initializer.js`

```js
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.enable_magic_8_ball) {
    return;
  }

  api.decorateCookedElement((elem) => {
    // your amazing magic goes here
  });
});
```

### You may need to "post process" the posts

In some cases you may need to "post process" posts, the markdown rendering engine, by-design is not aware of certain information like, for example `post_id`. In some cases you may want server side access to the post and "cooked" html, this can let you do things like trigger background jobs, synchronized custom fields or "correct" auto generated HTML.

For footnotes I needed a distinct `id` for each footnote, which meant I needed access to post_id, so I was forced to make changes to the HTML in the post processor (which runs in sidekiq)

To hook in you would add the following to your `plugin.rb` file:

```rb
DiscourseEvent.on(:before_post_process_cooked) do |doc, post|
  doc.css("a.always-bing").each do |a|
    # this should always go to bing
    a["href"] = "https://bing.com"
  end
end
```

### You may need some custom CSS

If you want to ship custom css, be sure to register the file in `plugin.rb`

Add your css to `assets/stylesheets/magic.scss` and then run

```rb
register_asset "stylesheets/magic.scss"
```

Remember that we "auto-reload" changes so you can amend your plugin CSS and see changes on the fly in development.

Good luck with your repackaging adventures :four_leaf_clover:
