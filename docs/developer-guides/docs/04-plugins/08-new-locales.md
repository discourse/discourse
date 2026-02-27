---
title: Add a new locale from plugin
short_title: New locales
id: new-locales
---

Usually the best way to add a new language to Discourse is by creating a pull request as described in "https://meta.discourse.org/t/how-to-add-a-new-language/14970".

The following guide is for you, if you want to use a language that can't be added to core right now.

---

### Adding a locale that extends an existing locale

Let's say you want to add a Spanish locale for Mexico (`es_MX`). Discourse already ships a Spanish locale (`es`), so this is quite easy.

Your plugin's directory structure should look like this:

```
custom-locales
├── assets
│   └── locales
│       └── es_MX.js.erb
├── config
│   └── locales
│       ├── client.es_MX.yml
│       └── server.es_MX.yml
└── plugin.rb
```

##### plugin.rb

You add the new locale by calling `register_locale`.

- The first parameter is required and must be the language code.

- `name` (the English name of the locale) and `nativeName` (the name shown in the user interface) can be omitted, if the language code exists in [`names.yml`](https://github.com/discourse/discourse/blob/master/config/locales/names.yml).

- `fallbackLocale` is the language code that should be used as fall back for missing translations and pluralization rules.

```rb
# name: custom-locales
# about: An example plugin for adding new locales.
# version: 1.0

register_locale("es_MX", name: "Spanish (Mexico)", nativeName: "Español (México)", fallbackLocale: "es")
```

##### \<locale\>.js.erb

The content of `assets/locales/es_MX.js.erb` is quite simple -- make sure you replace the locale code within that file with the one you need.

```js
//= require locales/i18n
<%= JsLocaleHelper.output_locale(:es_MX) %>
```

##### Translation files in config/locales

The files `config/locales/client.es_MX.yml` and `config/locales/server.es_MX.yml` contain the translations you want to use. You don't need to provide all translations needed by Discourse. The `fallbackLocale` and English will be used in case of missing translations.

---

### Adding a new locale

Adding a completely new locale, that shouldn't fall back to an existing locale, is a little bit more work.

Your plugin's directory structure should look like this:

```
custom-locales
├── assets
│   └── locales
│       └── foo.js.erb
├── config
│   └── locales
│       ├── client.foo.yml
│       └── server.foo.yml
├── lib
│   └── javascripts
│       └── locale
│           ├── message_format
│           │   └── foo.js
│           └── moment_js
│               └── foo.js
│           └── moment_js_timezones
│               └── foo.js
└── plugin.rb
```

##### plugin.rb

You add the new locale by calling `register_locale`.

- The first parameter is required and must be the language code.

- `name` (the English name of the locale) and `nativeName` (the name shown in the user interface) can be omitted, if the language code exists in [`names.yml`](https://github.com/discourse/discourse/blob/master/config/locales/names.yml), otherwise you should set them too.

- `plural` describes the language's pluralization rules. Take a look at [`plurals.rb`](https://github.com/discourse/discourse/blob/master/config/locales/plurals.rb) for inspiration. Also, you can omit this parameter if `plurals.rb` already contains your language code.

```rb
# name: custom-locales
# about: An example plugin for adding new locales.
# version: 1.0

register_locale(
  "foo",
  name: "Foo",
  nativeName: "Foo Bar",
  plural: {
    keys: [:one, :other],
    rule: lambda { |n| n == 1 ? :one : :other }
  }
)
```

##### \<locale\>.js.erb

The content of `assets/locales/foo.js.erb` is quite simple -- make sure you replace the locale code within that file with the one you need.

```js
//= require locales/i18n
<%= JsLocaleHelper.output_locale(:foo) %>
```

##### Translation files in config/locales

The files `config/locales/client.foo.yml` and `config/locales/server.foo.yml` contain the translations you want to use. You don't need to provide all translations needed by Discourse. The English translations will be used in case of missing translations.

##### message_format/\<locale\>.js

`lib/javascripts/locale/message_format/foo.js` contains the pluralization rules used by the client. The rules should be the same as the ones you used in the `register_locale` method. Take a look at the files in [lib/javascripts/locale](https://github.com/discourse/discourse/tree/master/lib/javascripts/locale) for some inspiration. You can omit this file if that directory already contains a file for your language code.

##### moment_js/\<locale\>.js

`lib/javascripts/locale/moment_js/foo.js` contains the locale file used by [moment.js](https://momentjs.com/). Take a look at the files in [vendor/assets/javascripts/moment-locale](https://github.com/discourse/discourse/tree/master/vendor/assets/javascripts/moment-locale) for some inspiration. You can omit this file if that directory already contains a file for your language code.

##### moment_js_timezones/\<locale\>.js

`lib/javascripts/locale/moment_js_timezones/foo.js` contains the locale file used in the timezone dropdown. Take a look at the files in [vendor/assets/javascripts/moment-timezone-names-locale](https://github.com/discourse/discourse/tree/master/vendor/assets/javascripts/moment-timezone-names-locale) for some inspiration. This file is optional.

---

### FAQ

##### Discourse doesn't load my locale. What is wrong?

Make sure that the plugin is enabled, that you registered the locale correctly and that all required files exist and have the correct language code in the filename. Discourse doesn't load locales when it detects missing files.
