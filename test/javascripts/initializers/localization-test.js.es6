import PreloadStore from 'preload-store';
import LocalizationInitializer from 'discourse/initializers/localization';

module("initializer:localization", {
  _locale: I18n.locale,
  _translations: I18n.translations,

  setup() {
    I18n.locale = "fr";

    I18n.translations = {
      "fr": {
        "js": {
          "composer": {
            "reply": "Répondre"
          }
        }
      },
      "en": {
        "js": {
          "topic": {
            "reply": {
              "help": "begin composing a reply to this topic"
            }
          }
        }
      }
    };
  },

  teardown() {
    I18n.locale = this._locale;
    I18n.translations = this._translations;
  }
});

test("translation overrides", function() {
  PreloadStore.store('translationOverrides', {"js.composer.reply":"WAT","js.topic.reply.help":"foobar"});
  LocalizationInitializer.initialize(this.registry);

  equal(I18n.t("composer.reply"), "WAT", "overrides existing translation in current locale");
  equal(I18n.t("topic.reply.help"), "foobar", "overrides translation in default locale");
});
