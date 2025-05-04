import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostMenu from "discourse/components/post/menu";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Unit | Component | post-menu", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.post_menu =
      "read|like|copyLink|share|flag|edit|bookmark|delete|admin|reply";
    this.siteSettings.post_menu_hidden_items = "";

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 123 });
    this.post = store.createRecord("post", {
      id: 1,
      post_number: 1,
      topic,
      like_count: 3,
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
    });
  });

  test("post-menu-collapsed value transformer", async function (assert) {
    this.siteSettings.post_menu_hidden_items = "bookmark|copyLink";

    // without the transformer
    const post = this.post; // using this inside the template does not correspond to the test `this` context
    await render(<template><PostMenu @post={{post}} /></template>);
    assert.dom(".post-action-menu__show-more").exists("show more is displayed");
    assert
      .dom(".post-action-menu__bookmark")
      .doesNotExist("bookmark is hidden");
    assert
      .dom(".post-action-menu__copy-link")
      .doesNotExist("copyLink is hidden");

    // with the transformer
    withPluginApi((api) => {
      api.registerValueTransformer("post-menu-collapsed", () => false);
    });

    await render(<template><PostMenu @post={{post}} /></template>);

    assert
      .dom(".post-action-menu__show-more")
      .doesNotExist("show more is hidden");
    assert.dom(".post-action-menu__bookmark").exists("bookmark is displayed");
    assert.dom(".post-action-menu__copy-link").exists("copyLink is displayed");
  });

  test("post-menu-toggle-like-action behavior transformer", async function (assert) {
    withPluginApi("2.0.0", (api) => {
      api.registerBehaviorTransformer("post-menu-toggle-like-action", () => {
        assert.step("transformer called");
      });
    });

    const post = this.post; // using this inside the template does not correspond to the test `this` context
    await render(<template><PostMenu @post={{post}} /></template>);

    await click(".post-action-menu__like");
    assert.verifySteps(
      ["transformer called"],
      "behavior transformer was called"
    );
  });

  module("post-menu value transformer", function () {
    test("context/collapsedButtons: allows handling which buttons are collapsed", async function (assert) {
      this.siteSettings.post_menu_hidden_items = "bookmark|copyLink";

      // without the transformer
      const post = this.post; // using this inside the template does not correspond to the test `this` context
      await render(<template><PostMenu @post={{post}} /></template>);
      assert
        .dom(".post-action-menu__show-more")
        .exists("show more is displayed");
      assert.dom(".post-action-menu__like").exists("like is displayed");
      assert
        .dom(".post-action-menu__bookmark")
        .doesNotExist("bookmark is hidden");
      assert
        .dom(".post-action-menu__copy-link")
        .doesNotExist("copyLink is hidden");
      assert.dom(".post-action-menu__share").exists("share is displayed");

      // with the transformer
      withPluginApi((api) => {
        api.registerValueTransformer(
          "post-menu-buttons",
          ({ context: { collapsedButtons } }) => {
            collapsedButtons.default("like");
            collapsedButtons.show("bookmark");
            collapsedButtons.hide("share");
            collapsedButtons.default("copy-link");
          }
        );
      });

      await render(<template><PostMenu @post={{post}} /></template>);
      assert
        .dom(".post-action-menu__show-more")
        .exists("show more is displayed");
      assert.dom(".post-action-menu__like").exists("like still is displayed");
      assert
        .dom(".post-action-menu__bookmark")
        .exists("bookmark is now displayed");
      assert
        .dom(".post-action-menu__copy-link")
        .doesNotExist("copyLink is still hidden");
      assert
        .dom(".post-action-menu__share")
        .doesNotExist("share is now hidden");
    });
  });
});
