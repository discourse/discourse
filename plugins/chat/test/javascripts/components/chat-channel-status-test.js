import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import I18n from "I18n";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";
import fabricators from "../helpers/fabricators";
import {
  CHANNEL_STATUSES,
  channelStatusIcon,
} from "discourse/plugins/chat/discourse/models/chat-channel";

module("Discourse Chat | Component | chat-channel-status", function (hooks) {
  setupRenderingTest(hooks);

  test("renders nothing when channel is opened", async function (assert) {
    this.channel = fabricators.chatChannel();

    await render(hbs`<ChatChannelStatus @channel={{this.channel}} />`);

    assert.dom(".chat-channel-status").doesNotExist();
  });

  test("defaults to long format", async function (assert) {
    this.channel = fabricators.chatChannel({ status: CHANNEL_STATUSES.closed });

    await render(hbs`<ChatChannelStatus @channel={{this.channel}} />`);

    assert
      .dom(".chat-channel-status")
      .hasText(I18n.t("chat.channel_status.closed_header"));
  });

  test("accepts a format argument", async function (assert) {
    this.channel = fabricators.chatChannel({
      status: CHANNEL_STATUSES.archived,
    });

    await render(
      hbs`<ChatChannelStatus @channel={{this.channel}} @format="short" />`
    );

    assert
      .dom(".chat-channel-status")
      .hasText(I18n.t("chat.channel_status.archived"));
  });

  test("renders the correct icon", async function (assert) {
    this.channel = fabricators.chatChannel({
      status: CHANNEL_STATUSES.archived,
    });

    await render(hbs`<ChatChannelStatus @channel={{this.channel}} />`);

    assert.dom(`.d-icon-${channelStatusIcon(this.channel.status)}`).exists();
  });

  test("renders archive status", async function (assert) {
    this.currentUser.admin = true;
    this.channel = fabricators.chatChannel({
      status: CHANNEL_STATUSES.archived,
      archive_failed: true,
    });

    await render(hbs`<ChatChannelStatus @channel={{this.channel}} />`);

    assert.dom(".chat-channel-retry-archive").exists();
  });
});
