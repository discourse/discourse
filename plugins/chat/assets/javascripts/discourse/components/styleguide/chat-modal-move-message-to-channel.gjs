import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import ChatModalMoveMessageToChannel from "discourse/plugins/chat/discourse/components/chat/modal/move-message-to-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row" with {
  discourseImport: "optional",
};
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example" with {
  discourseImport: "optional",
};

export default class ChatStyleguideChatModalMoveMessageToChannel extends Component {
  @service modal;

  channel = new ChatFabricators(getOwner(this)).channel();
  selectedMessageIds = [
    new ChatFabricators(getOwner(this)).message({ channel: this.channel }),
  ].map((item) => item.id);

  @action
  openModal() {
    return this.modal.show(ChatModalMoveMessageToChannel, {
      model: {
        sourceChannel: this.channel,
        selectedMessageIds: [
          new ChatFabricators(getOwner(this)).message({
            channel: this.channel,
          }),
        ].map((item) => item.id),
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
