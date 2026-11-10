import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import MoveMessageToChannel from "discourse/plugins/chat/discourse/components/chat/modal/move-message-to-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Component | <Chat::Modal::MoveMessageToChannel />", function (hooks) {
  setupRenderingTest(hooks);

  test("channel title is escaped in instructions correctly", async function (assert) {
    this.channel = new ChatFabricators(getOwner(this)).channel({
      title: "<script>someeviltitle</script>",
    });
    this.selectedMessageIds = [this.channel.id];

    await render(
      <template>
        <MoveMessageToChannel
          @inline={{true}}
          @model={{hash
            sourceChannel=this.channel
            selectedMessageIds=this.selectedMessageIds
          }}
        />
      </template>
    );

    assert
      .dom(".chat-modal-move-message-to-channel")
      .includesHtml("&lt;script&gt;someeviltitle&lt;/script&gt;");
  });

  test("moving sends the channel picked in the chooser as the destination", async function (assert) {
    const fabricators = new ChatFabricators(getOwner(this));
    const sourceChannel = fabricators.channel({ id: 11 });
    const destinationChannel = fabricators.channel({ id: 22 });
    const otherChannel = fabricators.channel({ id: 33 });
    const availableChannels = [sourceChannel, destinationChannel, otherChannel];
    const selectedMessageIds = [1, 2];
    const closeModal = () => {};
    let payload;

    sinon.stub(getOwner(this).lookup("service:router"), "transitionTo");
    pretender.post("/chat/api/channels/11/messages/moves", (request) => {
      payload = parsePostData(request.requestBody);
      return response({
        destination_channel_id: 22,
        first_moved_message_id: 1,
      });
    });

    await render(
      <template>
        <MoveMessageToChannel
          @closeModal={{closeModal}}
          @inline={{true}}
          @model={{hash
            sourceChannel=sourceChannel
            selectedMessageIds=selectedMessageIds
            availableChannels=availableChannels
          }}
        />
      </template>
    );

    assert
      .dom(".chat-modal-move-message-to-channel .btn-primary")
      .isDisabled("the move button waits for a destination");

    const chooser = selectKit(
      ".chat-modal-move-message-to-channel__channel-chooser"
    );
    await chooser.expand();
    await chooser.selectRowByValue(22);

    assert
      .dom(".chat-modal-move-message-to-channel .btn-primary")
      .isEnabled("the move button is enabled once a destination is picked");

    await click(".chat-modal-move-message-to-channel .btn-primary");

    assert.strictEqual(
      payload?.move?.destination_channel_id,
      "22",
      "sends the picked channel as destination_channel_id"
    );
  });
});
