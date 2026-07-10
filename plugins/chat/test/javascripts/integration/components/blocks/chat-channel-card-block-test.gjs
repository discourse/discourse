import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import { resetBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ChatChannelCardBlock from "discourse/plugins/chat/discourse/blocks/channel-card";

function channelJson(id, title) {
  return {
    id,
    chatable_id: 1,
    chatable_type: "Category",
    chatable_url: "/c/cat/1",
    title,
    unicode_title: title,
    description: `A place to chat about ${title}`,
    status: "open",
    slug: `channel-${id}`,
    memberships_count: 7,
    chatable: {
      id: 1,
      name: "Category",
      color: "0088CC",
      slug: "cat",
      read_restricted: false,
    },
    current_user_membership: { muted: false, following: true },
  };
}

module("Integration | Blocks | chat channel-card", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    resetBlockData();
  });

  test("renders the card for the configured channel", async function (assert) {
    pretender.get("/chat/api/channels/7", () =>
      response({ channel: channelJson(7, "Bug") })
    );

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: ChatChannelCardBlock, args: { channelId: 7 } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-chat-channel-card .chat-channel-card");
    await settled();

    assert.dom(".d-block-chat-channel-card .chat-channel-card").exists();
    assert
      .dom(".d-block-chat-channel-card")
      .includesText("Bug", "renders the resolved channel title");
    assert
      .dom(".chat-channel-card__cta")
      .exists("shows the membership button by default");
  });

  test("hides the membership button when showMembershipButton is false", async function (assert) {
    pretender.get("/chat/api/channels/7", () =>
      response({ channel: channelJson(7, "Bug") })
    );

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: ChatChannelCardBlock,
          args: { channelId: 7, showMembershipButton: false },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-chat-channel-card .chat-channel-card");
    await settled();

    assert
      .dom(".chat-channel-card__cta")
      .doesNotExist("hides the membership button when disabled");
  });

  test("renders the empty state when no channel is configured", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: ChatChannelCardBlock, args: {} },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-chat-channel-card__empty");
    await settled();

    assert.dom(".d-block-chat-channel-card__empty").exists();
    assert.dom(".d-block-chat-channel-card .chat-channel-card").doesNotExist();
  });
});
