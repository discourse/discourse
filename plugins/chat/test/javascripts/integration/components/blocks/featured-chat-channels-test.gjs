import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import { resetBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import FeaturedChatChannels from "discourse/plugins/chat/discourse/blocks/featured-channels";

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

module("Integration | Blocks | chat featured-channels", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    resetBlockData();
  });

  test("renders a card per resolved channel, in the configured order", async function (assert) {
    // Server returns them in a different order than configured.
    pretender.get("/chat/api/channels", () =>
      response({
        channels: [channelJson(7, "Bug"), channelJson(9, "Site")],
        meta: {},
      })
    );

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: FeaturedChatChannels, args: { channels: "9|7" } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-featured-chat-channels__grid");
    await settled();

    assert
      .dom(".d-block-featured-chat-channels__grid .chat-channel-card")
      .exists({ count: 2 }, "renders one card per resolved channel");

    const cards = [...document.querySelectorAll(".chat-channel-card")];
    assert
      .dom(cards[0])
      .includesText("Site", "honors the configured order (9 first)");
    assert
      .dom(cards[1])
      .includesText("Bug", "honors the configured order (7 second)");
    assert
      .dom(".d-block-featured-chat-channels__browse")
      .exists("renders the browse-all footer link");
  });

  test("renders the empty state when no channels resolve", async function (assert) {
    pretender.get("/chat/api/channels", () =>
      response({ channels: [], meta: {} })
    );

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: FeaturedChatChannels, args: { channels: "9|7" } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-featured-chat-channels__empty");
    await settled();

    assert.dom(".d-block-featured-chat-channels__empty").exists();
    assert.dom(".d-block-featured-chat-channels__grid").doesNotExist();
  });
});
