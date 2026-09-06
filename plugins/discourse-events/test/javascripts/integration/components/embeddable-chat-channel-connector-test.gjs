import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import EmbeddableChatChannelConnector from "../../discourse/connectors/before-main-outlet/embeddable-chat-channel-connector";

module(
  "Integration | Component | Livestream | embeddable chat channel connector",
  function (hooks) {
    setupRenderingTest(hooks);

    function stubEmbeddableChat(context, useLivestreamLayout) {
      const owner = getOwner(context);
      owner.unregister("service:embeddable-chat");
      owner.register(
        "service:embeddable-chat",
        {
          useLivestreamLayout,
          chatChannelId: 9,
          canRenderChatChannel: () => false,
        },
        { instantiate: false }
      );
    }

    test("applies the livestream body class from outside the post stream", async function (assert) {
      stubEmbeddableChat(this, true);

      await render(<template><EmbeddableChatChannelConnector /></template>);

      assert.dom(document.body).hasClass("livestream-topic");
    });

    test("omits the livestream body class when the layout does not apply", async function (assert) {
      stubEmbeddableChat(this, false);

      await render(<template><EmbeddableChatChannelConnector /></template>);

      assert.dom(document.body).doesNotHaveClass("livestream-topic");
    });
  }
);
