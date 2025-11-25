import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AddTranslation from "discourse/components/post/menu/buttons/add-translation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | Post Menu Add Translation Button",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      const store = getOwner(this).lookup("service:store");
      const post = store.createRecord("post", {
        id: 1,
        topic_id: 1,
        post_localizations_count: 0,
        can_localize_post: true,
      });

      this.post = post;
      this.set("post", post);

      // positive case for menu to always show
      this.siteSettings.content_localization_enabled = true;
      this.currentUser.admin = true;

      pretender.get("/posts/1.json", () => {
        return [200, {}, { raw: "Test post content" }];
      });
      pretender.get("/t/1.json", () => {
        return [200, {}, { raw: "Test post content" }];
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
  }
);
