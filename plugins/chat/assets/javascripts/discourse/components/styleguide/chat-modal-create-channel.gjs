import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import ChatModalCreateChannel from "discourse/plugins/chat/discourse/components/chat/modal/create-channel";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row" with {
  discourseImport: "optional",
};
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example" with {
  discourseImport: "optional",
};

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
