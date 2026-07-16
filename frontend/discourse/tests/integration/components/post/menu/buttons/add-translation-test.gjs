import { getOwner } from "@ember/owner";
import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostTranslationsModal from "discourse/components/modal/post-translations";
import AddTranslation from "discourse/components/post/menu/buttons/add-translation";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | Post Menu Add Translation Button",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 1,
        locale: null,
      });
      const post = store.createRecord("post", {
        id: 1,
        topic_id: 1,
        post_number: 1,
        locale: null,
        post_localizations_count: 0,
        can_localize_post: true,
        topic,
      });

      this.post = post;
      this.set("post", post);

      // positive case for menu to always show
      this.siteSettings.content_localization_enabled = true;
      this.siteSettings.available_content_localization_locales = [
        { name: "English", value: "en" },
        { name: "French (Français)", value: "fr" },
      ];
      this.siteSettings.available_locales = [
        { name: "English", value: "en" },
        { name: "French (Français)", value: "fr" },
        { name: "German (Deutsch)", value: "de" },
      ];
      this.currentUser.admin = true;

      pretender.get("/posts/1.json", () => {
        return [200, {}, { raw: "Test post content" }];
      });
      pretender.get("/t/1.json", () => {
        return [200, {}, { raw: "Test post content" }];
      });
      pretender.get("/post_localizations/1", () => {
        return [
          200,
          {},
          {
            post_localizations: [{ id: 1, locale: "fr", raw: "Bonjour" }],
          },
        ];
      });
      this.postLocaleUpdates = 0;
      pretender.put("/post_localizations/1/locale", () => {
        this.postLocaleUpdates += 1;
        return response({ locale: "de" });
      });
      pretender.put("/topic_localizations/1/locale", () => {
        return response({ locale: "de" });
      });
    });

    test("renders menu button when user can localize", async function (assert) {
      await render(<template><AddTranslation @post={{this.post}} /></template>);

      assert
        .dom(".update-translations-menu")
        .exists("Menu button rendered when user can localize");
    });

    test("does not render when post cannot be localized", async function (assert) {
      this.post.can_localize_post = false;

      await render(<template><AddTranslation @post={{this.post}} /></template>);

      assert
        .dom(".update-translations-menu")
        .doesNotExist("No menu when user cannot localize");
    });

    test("shows both view and add buttons when localizations exist", async function (assert) {
      this.post.post_localizations_count = 2;

      await render(<template><AddTranslation @post={{this.post}} /></template>);

      await click(".update-translations-menu");

      assert
        .dom(".update-translations-menu__view")
        .exists("View button shown when localizations exist");
      assert
        .dom(".update-translations-menu__add")
        .exists("Add button always shown");
    });

    test("shows only add button when no localizations", async function (assert) {
      this.post.post_localizations_count = 0;
      await render(<template><AddTranslation @post={{this.post}} /></template>);

      await click(".update-translations-menu");

      assert
        .dom(".update-translations-menu__view")
        .doesNotExist("View button hidden when no localizations");
      assert
        .dom(".update-translations-menu__add")
        .exists("Add button always shown");
    });

    test("view translation label includes count", async function (assert) {
      this.post.post_localizations_count = 5;
      await render(<template><AddTranslation @post={{this.post}} /></template>);

      await click(".update-translations-menu");

      assert
        .dom(".post-action-menu__view-translation")
        .hasText(i18n("post.localizations.view", { count: 5 }));
    });

    test("manages original languages in the translations modal", async function (assert) {
      this.post.locale = "en";
      this.post.topic.locale = "fr";
      this.model = { post: this.post };
      await render(
        <template>
          <PostTranslationsModal
            @model={{this.model}}
            @closeModal={{noop}}
            @inline={{true}}
          />
        </template>
      );

      assert
        .dom(".post-translations-modal .d-modal__title-text")
        .hasText(
          i18n("post.localizations.modal.title"),
          "the modal has a general title"
        );
      assert
        .dom(
          ".post-translations-modal__post-language .form-kit__container-help-text"
        )
        .hasText(
          i18n("post.localizations.modal.language_notice"),
          "the source language requirement is explained below its selector"
        );
      assert
        .dom(".post-translations-modal__section-title")
        .doesNotExist("the language fields have no redundant section heading");
      assert
        .dom(".post-translations-modal__topic-language")
        .includesText(
          i18n("post.localizations.modal.topic_language"),
          "first posts include a separate topic title language"
        );
      assert.true(
        findAll(
          ".post-translations-modal__language-form"
        )[0].classList.contains("post-translations-modal__topic-language"),
        "the topic title language is shown before the post language"
      );
      assert
        .dom(".post-translations-modal__locale")
        .hasText(
          "French (Français) (fr)",
          "translation locales use readable names"
        );
      assert.deepEqual(
        formKit(".post-translations-modal__post-language")
          .field("locale")
          .options(),
        ["__NONE__", "en", "fr", "de"],
        "the selector includes locales outside the content localization list"
      );
      assert
        .dom(
          ".post-translations-modal__post-language .post-translations-modal__language-actions"
        )
        .hasClass(
          "is-hidden",
          "save controls are hidden before the value changes"
        );

      await formKit(".post-translations-modal__post-language")
        .field("locale")
        .select("de");

      assert
        .dom(
          ".post-translations-modal__post-language .post-translations-modal__language-actions"
        )
        .doesNotHaveClass(
          "is-hidden",
          "save controls appear after the value changes"
        );
      assert
        .dom(".post-translations-modal__post-language .--save")
        .hasAttribute(
          "aria-label",
          i18n("post.localizations.modal.save_post_language"),
          "the save control has an accessible name"
        );
      assert
        .dom(".post-translations-modal__post-language .--discard")
        .hasAttribute(
          "aria-label",
          i18n("post.localizations.modal.discard_language_change"),
          "the discard control has an accessible name"
        );

      await click(".post-translations-modal__post-language .--discard");

      assert
        .dom(
          ".post-translations-modal__post-language .post-translations-modal__language-actions"
        )
        .hasClass("is-hidden", "discarding restores the unchanged state");
    });

    test("closes the translations menu when opening the modal", async function (assert) {
      this.post.post_localizations_count = 1;
      await render(<template><AddTranslation @post={{this.post}} /></template>);

      await click(".update-translations-menu");
      await click(".post-action-menu__view-translation");

      assert
        .dom(
          "[data-content][data-identifier='post-action-menu-edit-translations']"
        )
        .doesNotExist("the translations menu closes behind the modal");
    });

    test("hides language actions after saving", async function (assert) {
      this.post.locale = "en";
      this.model = { post: this.post };

      await render(
        <template>
          <PostTranslationsModal
            @model={{this.model}}
            @closeModal={{noop}}
            @inline={{true}}
          />
        </template>
      );

      await formKit(".post-translations-modal__post-language")
        .field("locale")
        .select("de");
      await click(".post-translations-modal__post-language .--save");

      assert.strictEqual(this.postLocaleUpdates, 1, "the post locale is saved");
      assert.strictEqual(
        this.post.locale,
        "de",
        "the saved locale updates the post"
      );
      assert
        .dom(
          ".post-translations-modal__post-language .post-translations-modal__language-actions"
        )
        .hasClass("is-hidden", "saving clears the changed state");

      await formKit(".post-translations-modal__post-language")
        .field("locale")
        .select("en");
      await click(".post-translations-modal__post-language .--discard");

      assert.strictEqual(
        formKit(".post-translations-modal__post-language")
          .field("locale")
          .value(),
        "de",
        "discarding after a save restores the latest saved value"
      );

      await formKit(".post-translations-modal__topic-language")
        .field("locale")
        .select("de");
      await click(".post-translations-modal__topic-language .--save");

      assert
        .dom(
          ".post-translations-modal__topic-language .post-translations-modal__language-actions"
        )
        .hasClass("is-hidden", "saving the topic clears its changed state");
    });

    test("does not show topic title language for replies", async function (assert) {
      this.post.post_number = 2;
      this.model = { post: this.post };

      await render(
        <template>
          <PostTranslationsModal
            @model={{this.model}}
            @closeModal={{noop}}
            @inline={{true}}
          />
        </template>
      );

      assert
        .dom(".post-translations-modal__post-language")
        .exists("the reply language can be changed");
      assert
        .dom(".post-translations-modal__topic-language")
        .doesNotExist("topic title language is limited to the first post");
    });
  }
);
