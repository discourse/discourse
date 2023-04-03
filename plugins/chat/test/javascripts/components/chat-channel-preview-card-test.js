import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import fabricators from "../helpers/fabricators";

module(
  "Discourse Chat | Component | chat-channel-preview-card",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set(
        "channel",
        fabricators.chatChannel({ chatable_type: "Category" })
      );
      this.channel.setProperties({
        description: "Important stuff is announced here.",
        title: "announcements",
      });
      this.currentUser.set("has_chat_enabled", true);
      this.siteSettings.chat_enabled = true;
    });

    test("channel title", async function (assert) {
      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert.strictEqual(
        query(".chat-channel-title__name").innerText,
        this.channel.title,
        "it shows the channel title"
      );

      assert.true(
        exists(query(".chat-channel-title__category-badge")),
        "it shows the category hashtag badge"
      );
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
      this.channel.set("description", null);

      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert.false(
        exists(".chat-channel-preview-card__description"),
        "no line is left for the channel description if there is none"
      );

      assert.true(
        exists(".chat-channel-preview-card.-no-description"),
        "it adds a modifier class for styling"
      );
    });

    test("join", async function (assert) {
      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert.true(
        exists(".toggle-channel-membership-button.-join"),
        "it shows the join channel button"
      );
    });

    test("browse all", async function (assert) {
      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert.true(
        exists(".chat-channel-preview-card__browse-all"),
        "it shows a link to browse all channels"
      );
    });

    test("closed channel", async function (assert) {
      this.channel.set("status", "closed");
      await render(hbs`<ChatChannelPreviewCard @channel={{this.channel}} />`);

      assert.false(
        exists(".chat-channel-preview-card__join-channel-btn"),
        "it does not show the join channel button"
      );
    });
  }
);
