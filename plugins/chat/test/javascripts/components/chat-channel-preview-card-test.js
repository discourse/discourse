import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | chat-channel-preview-card",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set(
        "channel",
        new ChatFabricators(getOwner(this)).channel({
          chatable_type: "Category",
        })
      );

      this.channel.description = "Important stuff is announced here.";
      this.channel.title = "announcements";
      this.channel.meta = { can_join_chat_channel: true };
      this.currentUser.set("has_chat_enabled", true);
      this.siteSettings.chat_enabled = true;
    });

    test("channel title", async function (assert) {
      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert.strictEqual(
        query(".chat-channel-name__label").innerText,
        this.channel.title,
        "it shows the channel title"
      );

      assert
        .dom(".chat-channel-icon.--category-badge")
        .exists("shows the category hashtag badge");
    });

    test("channel description", async function (assert) {
      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert.strictEqual(
        query(".chat-channel-preview-card__description").innerText,
        this.channel.description,
        "the channel description is shown"
      );
    });

    test("no channel description", async function (assert) {
      this.channel.description = null;

      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert
        .dom(".chat-channel-preview-card__description")
        .doesNotExist(
          "no line is left for the channel description if there is none"
        );

      assert
        .dom(".chat-channel-preview-card.-no-description")
        .exists("adds a modifier class for styling");
    });

    test("join", async function (assert) {
      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert
        .dom(".toggle-channel-membership-button.-join")
        .exists("shows the join channel button");
    });

    test("browse all", async function (assert) {
      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert
        .dom(".chat-channel-preview-card__browse-all")
        .exists("shows a link to browse all channels");
    });

    test("closed channel", async function (assert) {
      this.channel.status = "closed";
      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert
        .dom(".chat-channel-preview-card__join-channel-btn")
        .doesNotExist("it does not show the join channel button");
    });
  }
);
