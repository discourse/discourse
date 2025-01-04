---
title: Add settings to your Discourse theme
short_title: Theme settings
id: theme-settings

---
Discourse has the ability for themes to have "settings" that can be added by theme developers to allow site owners to customize themes through UI without having to change any line of code and worry about losing their changes with future updates for the theme.
 
## :heavy_plus_sign: Adding settings to your theme

Adding settings to your theme is a bit different from adding CSS and JS code, that is there is no way to do it via the UI.

The way to add settings is to create a [repository for your theme](https://meta.discourse.org/t/how-to-develop-custom-themes/60848?u=osama), and in the root folder of your repository create a new `settings.yaml` (or `settings.yml`) file. In this file you'll use the [YAML](https://en.wikipedia.org/wiki/YAML) language to define your theme settings.

>:loudspeaker:  **Note:** You may find it helpful to make use of the [Theme CLI](https://meta.discourse.org/t/discourse-theme-cli-console-app-to-help-you-build-themes/82950?u=osama), which tremendously simplifies the development process.

Now if you're familiar with plugin development, this shouldn't be a new thing to you - it mostly works the same way as adding site settings to your plugin. Just dump some valid YAML in your settings file and you'll be good to go.

A valid theme setting must have a name and default value, that's the bare minimum and it looks like this:

```yaml
simple_setting: true
```

As you can probably tell, that will create a setting with the name `simple_setting` and it'll have `true` as its default value.

Similarly, you can add something like this:

```yaml
site_name: My Forums
max_avatars: 7
```
And you'll have two more settings, `site_name` which will be a string setting with "My Forums" as the default value, and `max_avatars` as an integer setting with default value of 7.

![image|690x318](/assets/theme-settings-1.jpg)

You can access your settings in your JS code like this: `settings.your_setting_key`.

So until this point we've covered the simplest way to define settings. In the next section we'll dive a bit deeper into the various types of settings and how you can use them.

## :symbols: Supported types

There are 8 types of settings:
1. `integer`
2. `float`
3. `string`
4. `bool` (for boolean)
5. `list`
6. `enum`
7. `objects` (replacement for `json_schema`)
8. `upload` (for images)

And you can specify type by adding a `type` attribute to your setting like this:

```yaml
float_setting:
  type: float
  default: 3.14
```
I should say that you don't always have to explicitly set a `type` attribute because Discourse is smart enough to work out the setting type from the setting's default value. So you can reduce the above example to this:

```yaml
float_setting:
  default: 3.14
```

That said, you _need_ to set a type attribute when working with **`list`** and **`enum`** settings, otherwise Discourse will not recognize them correctly.

**List Setting:**
```yaml
whitelisted_fruits:
  default: apples|oranges
  type: list
```

**Enum Setting:**
```yaml
favorite_fruit:
  default: orange
  type: enum
  choices:
    - apple
    - banana
```

![image|613x181](/assets/theme-settings-2.jpg)

In case the difference between list and enum settings is not clear to you: enum settings allow your theme users to select only _one_ value from a set of values defined by you (see the `choices` attribute).

On the other hand, list settings allow your users to create their own _list_ (i.e. an array) of values. They can add to or remove from the setting's default list of values.
You can set the default list of values for the setting by joining the values with a vertical bar <kbd>|</kbd> character. See the list setting in the example above.

You can see a real-world use case for list settings here: https://meta.discourse.org/t/linkify-words-in-post-theme-component/82193?u=osama.

> :loudspeaker:  **Note**: Pay attention to indentation when working with YAML because YAML is very picky about spaces and will throw a syntax error if your code indentation is incorrect.

### `objects` type

The `objects` setting type is a special type that allows you to accomplish advanced settings with custom structure and validations. We have a [separate documentation](https://meta.discourse.org/t/objects-type-for-theme-setting/305009) for this type.

## :capital_abcd: Setting description and localizations

You can add description text to your theme setting and it'll be shown as a label directly under the setting. To do that simply add a `description` attribute to your setting like so:

```yaml
whitelisted_fruits:
  default: apples|oranges
  type: list
  description: "This text will be displayed under this setting and it explains what the setting does!"
```

And you'll get this:

![image|609x105](/assets/theme-settings-4.jpg)

### Multiple languages support

If you know more than one language, and you'd like to add support for those languages to your theme, then you can totally do that provided that Discourse supports said languages. 

First of all, make sure the language you want to support is in this list:


[details="Languages list"]

|  Code  |   |   |   |       Name      |
|:------:|---|---|---|:---------------:|
|   ar   |   |   |   |  اللغة العربية  |
| bs_BA  |   |   |   |  bosanski jezik |
|   ca   |   |   |   |      català     |
|   cs   |   |   |   |     čeština     |
|   da   |   |   |   |      dansk      |
|   de   |   |   |   |     Deutsch     |
|   el   |   |   |   |     ελληνικά    |
|   en   |   |   |   |     English     |
|   es   |   |   |   |     Español     |
|   et   |   |   |   |      eesti      |
| fa_IR  |   |   |   |      فارسی      |
|   fi   |   |   |   |      suomi      |
|   fr   |   |   |   |     Français    |
|   gl   |   |   |   |      galego     |
|   he   |   |   |   |      עברית      |
|   id   |   |   |   |    Indonesian   |
|   it   |   |   |   |     Italiano    |
|   ja   |   |   |   |      日本語     |
|   ko   |   |   |   |      한국어     |
|   lv   |   |   |   | latviešu valoda |
| nb_NO  |   |   |   |   Norsk bokmål  |
|   nl   |   |   |   |    Nederlands   |
| pl_PL  |   |   |   |   język polski  |
|   pt   |   |   |   |    Português    |
| pt_BR  |   |   |   |  Português (BR) |
|   ro   |   |   |   |   limba română  |
|   ru   |   |   |   |     Русский     |
|   sk   |   |   |   |    slovenčina   |
|   sq   |   |   |   |      Shqip      |
|   sr   |   |   |   |   српски језик  |
|   sv   |   |   |   |     svenska     |
|   te   |   |   |   |      తెలుగు      |
|   th   |   |   |   |       ไทย       |
| tr_TR  |   |   |   |      Türkçe     |
|   uk   |   |   |   | українська мова |
|   ur   |   |   |   |       اردو      |
|   vi   |   |   |   |     Việt Nam    |
| zh_CN  |   |   |   |       中文      |
| zh_TW  |   |   |   |    中文 (TW)    |

[/details]

(If you can't see your language in the list then you might want to take a look at https://meta.discourse.org/t/how-to-add-a-new-language/14970?u=osama) 

Then you'll need find your language code from the above list and use the language code as a key under the `description` attribute and translation as a value for the key like so:

```yaml
whitelisted_fruits:
  default: apples|oranges
  type: list
  description:
    en: English text
    ar: نص باللغة العربية
    fr: Texte français
```

And now you have support for 3 languages: English, Arabic and French.

## :arrow_up_down: Min and max attributes

Sometimes you may need to specify limits that a setting value can't exceed to prevent your users from accidentally breaking the theme or possibly the whole site.

To specify limits, simply add a `min` or `max` or both attributes to your setting like so:

```yaml
integer_setting:
  default: 10
  min: 5
  max: 100
```

You can specify limits to `integer`, `float` and `string` type settings. For `integer` and `float` settings, the value of the setting itself is checked against the limits. And for `string` settings, the length of the value is checked against the specified limits.

If your user tries to enter a value that's not within the allowed range, they'll see an error telling them what the min and max values are.

<h3 id='heading--settings-js-css'>Access to settings in your JS/CSS/Handlebars</h3>

To have access to setting in your theme JS code, the `script` tag that wraps your code must have a `type="text/discourse-plugin"` attribute as well as `version` specified like so:

```handlebars
<script type="text/discourse-plugin" version="0.8.13">
  alert(settings.integer_setting + 1);
  console.log(settings.string_setting);
</script>
```

In CSS, you'll get a variable created for every setting of your theme and each variable will have the same name as the setting it represents.

So if you had a float setting called `global_font_size` and a string setting called `site_background`, you could do something like this in your theme CSS:

```scss
html {
  font-size: #{$global-font-size}px;
  background: $site-background;
}
```

Similarly, theme settings are available in handlebars templates that you define in your theme whether you're overriding a core template, or creating your own. For example if you have something like this in your theme:

```handlebars
<script type='text/x-handlebars' data-template-name='my-template'>
  <h1>{{theme-setting 'your_setting_key'}}</h1>
</script>
```
It'll render with your setting value.

You may want to use a boolean setting as a condition for an `{{#if}}` block in your template, this is how you can do that:

```handlebars
<script type='text/x-handlebars' data-template-name='my-template'>
  {{#if (theme-setting 'my_boolean_setting')}}
    <h1>Value is true!</h1>
  {{else}}
    <h1>Value is false!</h1>
  {{/if}}
</script>
```

-------

If you have a question about this or there is something unclear, feel free to ask - I'll try to answer/clarify as much as I can. Also this is a wiki post, so contributions to improve this are greatly appreciated! :sunflower:

--------

## :question: Frequently Asked Questions

[quote="p0fi, post:27, topic:82557"]
Can I combine javascript and handlebars in there somehow too? I would like to get the current year using javascript to put it in the string too.
[/quote]

Not directly; you’ll need to use the `registerConnectorClass` plugin API to add an attribute that has the current year to the connector instance behind your connector template. See an [example](https://github.com/OsamaSayegh/discourse-tab-bar-theme/blob/c05adce3274ffee821eadac8f81ffb54b85e5045/mobile/head_tag.html#L91) from my theme.


My theme sets the `tabs` attributes which is then referenced in the Handlebars template at the end of the file. You can do something like `this.set("year", compute current year here)` in the `setupComponent` method and then in your template you can access the year value like this `{{year}}`.

[quote="Jay Pfaffman, post:29, topic:82557, full:true, username:pfaffman"]
What if I have a setting like

```yaml
my_text:
  type: string  
  default: "<a href='https://google.com/'>Google!</a>"
```

and then want to do

```handlebars
<script type='text/x-handlebars' data-template-name='my-template'>
   {{theme-setting 'my_text'}}
</script>
```

It doesn’t give me my link but instead displays all the HTML. Is there a way to fix that?
[/quote]

You can use the Ember's `html-safe` helper here and it will render the HTML instead of the text.
```handlebars
{{html-safe (theme-setting "my_text")}}
```

[quote="Alex P., post:33, topic:82557, full:true, username:Alex_P"]
[quote]
the `script` tag that wraps your code must have a `type="text/discourse-plugin"` attribute as well as `version` specified like so:
[/quote]

What’s that version value? Is it supposed to be the version of my plugin?
[/quote]

No, that’s the version of our [Plugin API](https://github.com/discourse/discourse/blob/e6b5b6eae348aa0f6148589a07e9ade0f08bae59/app/assets/javascripts/discourse/app/lib/plugin-api.js#L112)

We bump that every time a new method is added to the API so that themes / plugins which relay on methods that were recently added to the plugin API don’t end up breaking sites which haven’t been updated.

You don’t really need to worry about this a lot because:

1. We don’t add new methods very often
2. Most sites that use Discourse are updated very frequently.

[quote="Marcus Baw, post:44, topic:82557, username:pacharanero"]
Is it possible to access the theme settings from within the Ruby code as opposed to the JS?
[/quote]

To access theme settings in Ruby you need to call the `settings` method on a theme like so: `Theme.find(<id>).settings` . It will return an array which contains a [`ThemeSettingsManager` ](https://github.com/discourse/discourse/blob/66151d805609839a333500248149da4cc5e9cae3/lib/theme_settings_manager.rb#L1) instance for each setting and from it you can get the setting name and value by calling the `name` and `value` methods respectively.

[quote="Heddson, post:47, topic:82557"]
Could things break if I don’t prefix my setting names with something like my theme name?
[/quote]

In JavaScript and hbs templates, there is no way this can happen. The `settings` variable that you use to access your theme settings is local to your theme and only contains your theme settings. In hbs templates, the settings of each theme are namespaced with their theme’s primary key in the database, so conflicts are impossible.

[quote="Manuel, post:50, topic:82557, full:true, username:nolo"]
When I use a list in settings, I get the values as:

```
value1,value2,value3|value1,value2,value3
```

Is it possible to modify this output by declaring a different list_type? I’d like to use values from a list in Scss, but I think I could only de-structure the list if the output is formatted as

```
value1 value2 value3,
value1 value2 value3;
```
[/quote]

You can create custom SCSS functions to transform settings values into whatever format you want. E.g., in your case I think all you need is a string replace function that replaces commas with whitespace and pipes with commas? Here is an implementation of a string replace function in SCSS: [Str-replace Function | CSS-Tricks ](https://css-tricks.com/snippets/sass/str-replace-function/)

[quote="Jonathan Shaw, post:60, topic:82557, full:true, username:JonathanShaw"]
Is it possible to access settings from another theme or component. e.g. if you have the category icons theme component installed, can you access information about the icons defined in its settings in a different custom theme component?
[/quote]

There is not a supported way to access the settings of another theme/component.

[quote="Alex, post:62, topic:82557, username:daemon"]
Is it possible to divide the settings into sections, e.g. with horizontal lines in between?

And is it possible to integrate some kind of heading?
[/quote]

No, neither of those things are possible at the moment. 

--------

## :link: Related Topics

- https://meta.discourse.org/t/developer-s-guide-to-discourse-themes/93648

------


*Last Reviewed by @keegan on [date=2022-10-06 timezone="America/Vancouver"]*
