import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const SELECTOR = ".translation-selector-dropdown";

acceptance(
  "Composer - Translation language with the new select controls",
  function (needs) {
    needs.user({ admin: true });
    needs.settings({
      content_localization_enabled: true,
      enable_new_select_controls: true,
      post_menu: "addTranslation|reply",
      available_locales: [
        { name: "English", value: "en" },
        { name: "French (Français)", value: "fr" },
        { name: "Japanese (日本語)", value: "ja" },
      ],
      available_content_localization_locales: [
        { name: "English", value: "en" },
        { name: "French", value: "fr" },
        { name: "Japanese", value: "ja" },
      ],
    });

    needs.pretender((server, helper) => {
      const topic = cloneJSON(topicFixtures["/t/280/1.json"]);
      Object.assign(topic.post_stream.posts[0], {
        can_localize_post: true,
        locale: "en",
      });

      server.get("/t/280.json", () => helper.response(topic));
      server.get("/t/280/:post_number.json", () => helper.response(topic));
      server.get("/posts/398.json", () =>
        helper.response({ raw: "The original post" })
      );
      server.get("/post_localizations/398", () =>
        helper.response({
          post_localizations: [
            { id: 1, post_id: 398, locale: "fr", raw: "Le message traduit" },
          ],
        })
      );
    });

    async function openTranslationComposer() {
      await visit("/t/internationalization-localization/280");
      await click("#post_1 .update-translations-menu");
      await click(".post-action-menu__add-translation");
    }

    test("offers the other languages and loads the picked one's translation", async function (assert) {
      await openTranslationComposer();

      assert
        .dom(dSelect(SELECTOR).element())
        .hasAria("label", i18n("composer.translations.language"));
      assert.dSelect(SELECTOR).hasLabel(i18n("composer.translations.select"));

      await dSelect(SELECTOR).open();

      assert
        .dSelect(SELECTOR)
        .hasOptions(["fr", "ja"], "the post's own language isn't offered");

      await dSelect(SELECTOR).select("fr");

      assert.dom(".d-editor-input").hasValue("Le message traduit");
    });

    test("keeps the typed translation when Backspace is pressed on the field", async function (assert) {
      await openTranslationComposer();
      await dSelect(SELECTOR).select("ja");
      await fillIn(".d-editor-input", "翻訳された投稿");
      await triggerKeyEvent(
        dSelect(SELECTOR).element(),
        "keydown",
        "Backspace"
      );

      assert.dSelect(SELECTOR).hasValue("ja");
      assert.dom(".d-editor-input").hasValue("翻訳された投稿");
    });
  }
);
