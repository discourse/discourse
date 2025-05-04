import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { optionalRequire } from "discourse/lib/utilities";
import ChatModalCreateChannel from "discourse/plugins/chat/discourse/components/chat/modal/create-channel";

const Row = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls/row"
);
const StyleguideExample = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide-example"
);

export default class ChatStyleguideChatModalCreateChannel extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalCreateChannel);
  }

  <template>
    <StyleguideExample @title="<Chat::Modal::CreateChannel>">
      <Row>
        <DButton @translatedLabel="Open modal" @action={{this.openModal}} />
      </Row>
    </StyleguideExample>
  </template>
}
