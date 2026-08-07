import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatChannelPreviewCard from "discourse/plugins/chat/discourse/components/chat-channel-preview-card";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Component | ChatChannelPreviewCard", function (hooks) {
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

  test("card", async function (assert) {
    await render(
      <template><ChatChannelPreviewCard @channel={{this.channel}} /></template>
    );

    assert
      .dom(".chat-channel-preview-card")
      .exists("shows the channel preview card");
  });

  test("join", async function (assert) {
    await render(
      <template><ChatChannelPreviewCard @channel={{this.channel}} /></template>
    );

    assert
      .dom(".toggle-channel-membership-button.-join")
      .exists("shows the join channel button");
  });

  test("closed channel", async function (assert) {
    this.channel.status = "closed";
    await render(
      <template><ChatChannelPreviewCard @channel={{this.channel}} /></template>
    );

    assert
      .dom(".toggle-channel-membership-button.-join")
      .doesNotExist("it does not show the join channel button");
  });
});
