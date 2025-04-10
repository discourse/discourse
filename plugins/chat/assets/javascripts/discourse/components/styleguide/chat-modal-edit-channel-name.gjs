import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { optionalRequire } from "discourse/lib/utilities";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

const Row = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls/row"
);
const StyleguideExample = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide-example"
);

export default class ChatStyleguideChatModalEditChannelName extends Component {
  @service modal;

  channel = new ChatFabricators(getOwner(this)).channel();

  @action
  openModal() {
    return this.modal.show(ChatModalEditChannelName, {
      model: this.channel,
    });
  }

  <template>
    <StyleguideExample @title="<Chat::Modal::EditChannelName>">
      <Row>
        <DButton @translatedLabel="Open modal" @action={{this.openModal}} />
      </Row>
    </StyleguideExample>
  </template>
}
