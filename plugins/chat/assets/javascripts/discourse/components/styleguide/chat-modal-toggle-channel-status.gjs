import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import ChatModalToggleChannelStatus from "discourse/plugins/chat/discourse/components/chat/modal/toggle-channel-status";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row" with {
  discourseImport: "optional",
};
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example" with {
  discourseImport: "optional",
};

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
