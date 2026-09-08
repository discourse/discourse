import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
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
    const setFilter = sinon.stub(this.preferences, "setFilter").resolves(true);
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
        "No channels match this filter.",
        "the filtered empty state explains the filter"
      );

    await click(".empty-state__cta .btn");

    assert.true(
      setFilter.calledWith("starred", "all"),
      "the show all action resets the starred filter"
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
