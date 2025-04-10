import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { optionalRequire } from "discourse/lib/utilities";
import ChatModalMoveMessageToChannel from "discourse/plugins/chat/discourse/components/chat/modal/move-message-to-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

const Row = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls/row"
);
const StyleguideExample = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide-example"
);

export default class ChatStyleguideChatModalMoveMessageToChannel extends Component {
  @service modal;

  channel = new ChatFabricators(getOwner(this)).channel();
  selectedMessageIds = [
    new ChatFabricators(getOwner(this)).message({ channel: this.channel }),
  ].mapBy("id");

  @action
  openModal() {
    return this.modal.show(ChatModalMoveMessageToChannel, {
      model: {
        sourceChannel: this.channel,
        selectedMessageIds: [
          new ChatFabricators(getOwner(this)).message({
            channel: this.channel,
          }),
        ].mapBy("id"),
      },
    });
  }

  <template>
    <StyleguideExample @title="<Chat::Modal::MoveMessageToChannel>">
      <Row>
        <DButton @translatedLabel="Open modal" @action={{this.openModal}} />
      </Row>
    </StyleguideExample>
  </template>
}
