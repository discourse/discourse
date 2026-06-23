import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import ChatModalEditChannelDescription from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-description";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row" with {
  discoursePlugin: "optional",
};
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example" with {
  discoursePlugin: "optional",
};

export default class ChatStyleguideChatModalEditChannelDescription extends Component {
  @service modal;

  channel = new ChatFabricators(getOwner(this)).channel();

  @action
  openModal() {
    return this.modal.show(ChatModalEditChannelDescription, {
      model: this.channel,
    });
  }

  <template>
    <StyleguideExample @title="<Chat::Modal::EditChannelDescription>">
      <Row>
        <DButton @translatedLabel="Open modal" @action={{this.openModal}} />
      </Row>
    </StyleguideExample>
  </template>
}
