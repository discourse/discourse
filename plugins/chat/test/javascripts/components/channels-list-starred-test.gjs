import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChannelsListStarred from "discourse/plugins/chat/discourse/components/channels-list-starred";
import { CHAT_CHANNEL_LIST_FILTERS } from "discourse/plugins/chat/discourse/lib/chat-constants";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";

module("Integration | Component | ChannelsListStarred", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.manager = getOwner(this).lookup("service:chat-channels-manager");
    this.preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );
    this.fabricators = new ChatFabricators(getOwner(this));
  });

  test("shows the filtered empty state when the starred filter hides every channel", async function (assert) {
    this.preferences.starredFilter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;

    const channel = this.fabricators.channel({
      id: 1,
      chatable: this.fabricators.coreFabricators.category({ slug: "alpha" }),
    });
    channel.currentUserMembership = UserChatChannelMembership.create({
      following: true,
      starred: true,
    });
    this.manager.store(channel);

    await render(<template><ChannelsListStarred /></template>);

    assert
      .dom(".empty-state .empty-state__title")
      .hasText(
        i18n("chat.channel_list.empty.filtered"),
        "the filtered empty state explains the filter"
      );

    await click(".empty-state__cta .btn");

    assert
      .dom(".chat-channel-row")
      .exists("the temporary override reveals the starred channel");
    assert
      .dom(".empty-state")
      .doesNotExist("the filtered empty state is removed");
    assert.strictEqual(
      this.preferences.filterFor("starred"),
      CHAT_CHANNEL_LIST_FILTERS.UNREAD,
      "the preferred starred filter is retained"
    );
    assert
      .dom(".chat-channel-list-filter-toggle .d-icon-filter")
      .exists("the header offers to reapply the filter");

    await click(".chat-channel-list-filter-toggle");

    assert
      .dom(".chat-channel-row")
      .doesNotExist("reapplying the filter hides the read starred channel");
    assert
      .dom(".empty-state .empty-state__title")
      .hasText(
        i18n("chat.channel_list.empty.filtered"),
        "the filtered empty state returns"
      );
  });

  test("keeps the plain empty message when there are no starred channels", async function (assert) {
    await render(<template><ChannelsListStarred /></template>);

    assert
      .dom(".chat-channel-list__empty-message")
      .exists("the no-starred-channels message is shown");
    assert
      .dom(".empty-state")
      .doesNotExist("the filtered empty state is not shown without channels");
  });
});
