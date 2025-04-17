import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { optionalRequire } from "discourse/lib/utilities";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";

const Row = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls/row"
);
const StyleguideExample = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide-example"
);

export default class ChatStyleguideChatModalNewMessage extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalNewMessage);
  }

  <template>
    <StyleguideExample @title="<Chat::Modal::NewMessage>">
      <Row>
        <DButton @translatedLabel="Open modal" @action={{this.openModal}} />
      </Row>
    </StyleguideExample>
  </template>
}
