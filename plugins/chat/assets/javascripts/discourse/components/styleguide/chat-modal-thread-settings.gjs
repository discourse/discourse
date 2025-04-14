import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ChatModalThreadSettings from "discourse/plugins/chat/discourse/components/chat/modal/thread-settings";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatModalThreadSettings extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalThreadSettings, {
      model: new ChatFabricators(getOwner(this)).thread(),
    });
  }
}

<StyleguideExample @title="<Chat::Modal::ThreadSettings>">
  <Styleguide::Controls::Row>
    <DButton @translatedLabel="Open modal" @action={{this.openModal}} />
  </Styleguide::Controls::Row>
</StyleguideExample>