import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostMenu from "discourse/components/post/menu";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

const noop = () => {};

module("Unit | Component | PostMenu", function (hooks) {
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

  test("replies button renders in flat post menus but not nested reply menus", async function (assert) {
    this.post.set("reply_count", 2);
    const post = this.post;

    await render(
      <template>
        <PostMenu
          @post={{post}}
          @toggleReplies={{noop}}
          @repliesShown={{false}}
        />
      </template>
    );

    assert
      .dom(".post-action-menu__show-replies")
      .exists("flat post menus still render the replies button");

    await render(
      <template>
        <PostMenu
          @post={{post}}
          @nestedReplyView={{true}}
          @toggleReplies={{noop}}
          @repliesShown={{false}}
        />
      </template>
    );

    assert
      .dom(".post-action-menu__show-replies")
      .doesNotExist("nested post menus suppress the flat replies button");
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
    withPluginApi((api) => {
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

  test("share and copy link buttons use distinct icons", async function (assert) {
    const post = this.post;

    await render(<template><PostMenu @post={{post}} /></template>);

    assert
      .dom(
        ".post-action-menu__share svg.d-icon-d-post-share use[href='#arrow-up-from-bracket']"
      )
      .exists("share uses the share icon");

    assert
      .dom(".post-action-menu__copy-link svg.d-icon-link use[href='#link']")
      .exists("copy link uses the link icon");
  });

  test("show more does not request who liked the post", async function (assert) {
    this.siteSettings.post_menu_hidden_items = "bookmark|copyLink";

    let requested = false;
    pretender.get("/post_action_users", () => {
      requested = true;
      return response({ post_action_users: [] });
    });

    const post = this.post;
    await render(<template><PostMenu @post={{post}} /></template>);
    await click(".post-action-menu__show-more");

    assert.false(requested, "no request is sent to /post_action_users");
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
