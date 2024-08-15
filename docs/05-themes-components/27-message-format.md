---
title: Message Format support for localization
short_title: Message format
id: message-format

---
## Guidelines for Translators

In Discourse all Message Format strings have a key that ends with "_MF". The Crowdin Editor has a preview that allows you to experiment with various values which is quite helpful for checking your translations.

![image|493x446, 80%](/assets/message-format-1.png)

**Important:** You need to modify the plural forms of your translation if your language uses forms other than "one" and "other". You can add or remove forms within a `{ FOO, plural, ... }` block in order to make it work for your languages. The preview in the Crowdin Editor will show you a "Syntax error" in the preview when there's a problem with your translation.

The available plural forms are:
* zero
* one
* two
* few
* many
* other (required — general plural form — also used for languages with no distinction between singular and plural forms)

Sometimes you might see an empty `=0 {}` block in an English source string which means that the variable can't have a value of 0.

## Guidelines for Developers

Message Format strings are currently only available only for client-side translations. They are useful if your string contains more than one number or many variables which would lead to a high amount of permutations.

* The keys of Message Format strings need to end with "**_MF**"

* Use the following format for **numbers** (`#` will be replaced with the number):
   ```
   { variable_name, plural,
       one: {# singular text}
     other: {# plural text}
   }
   ```

* Use the following format for **choices**:
   ```
   { variable_name, select,
     foo: {This is foo}
     bar: {This is bar}
     baz: {This is baz}
   }
   ```

* This is how you use it in JavaScript:
   ```javascript
   I18n.messageFormat("key_MF", {
     variable1: "foo",
     variable2: 42
   })
   ```

* :loudspeaker:  **Recommendation:** If possible, use complex arguments as the outermost structure of a message, and write **full sentences** in their sub-messages. If you have nested select and plural arguments, place the **select** arguments (with their fixed sets of choices) on the **outside** and nest the plural arguments (hopefully at most one) inside. See https://unicode-org.github.io/icu/userguide/format_parse/messages/

* Make them **readable** -- see existing examples in [client.en.yml](https://github.com/discourse/discourse/blob/main/config/locales/client.en.yml)

   ❌ **Bad**
   ```
   There {currentTopics, plural, one {is <strong>#</strong> topic} other {are <strong>#</strong> topics}}. Visitors need more to read and reply to – we recommend at least { requiredTopics, plural, one {<strong>#</strong> topic} other {<strong>#</strong> topics}}. Only staff can see this message.
   ```

   💚 **Good**
   ```
   There { currentTopics, plural,
       one {is <strong>#</strong> topic}
     other {are <strong>#</strong> topics}
   }. Visitors need more to read and reply to – we recommend at least { requiredTopics, plural,
       one {<strong>#</strong> topic}
     other {<strong>#</strong> topics}
   }. Only staff can see this message.
   ```

## Tools and further information

* https://format-message.github.io/icu-message-format-for-translators/editor.html allows you to test a Message Format string in case there's a problem with the Crowdin Editor. Please disable the "Parse simple xml/html tags" option, otherwise you might see an error message.

* https://format-message.github.io/icu-message-format-for-translators/
