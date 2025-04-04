import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { optionalRequire } from "discourse/lib/utilities";
import ChatModalToggleChannelStatus from "discourse/plugins/chat/discourse/components/chat/modal/toggle-channel-status";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

const Row = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls/row"
);
const StyleguideExample = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide-example"
);

export default class ChatStyleguideChatModalToggleChannelStatus extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalToggleChannelStatus, {
      model: new ChatFabricators(getOwner(this)).channel(),
    });
  }

  <template>
    <StyleguideExample @title="<Chat::Modal::ToggleChannelStatus>">
      <Row>
        <DButton @translatedLabel="Open modal" @action={{this.openModal}} />
      </Row>
    </StyleguideExample>
  </template>
}
