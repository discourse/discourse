import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ChatStyleguideChatComposer extends Component {
  @service chatChannelComposer;
  @service chatChannelPane;

  channel = new ChatFabricators(getOwner(this)).channel({ id: -999 });

  @action
  toggleDisabled() {
    if (this.channel.status === CHANNEL_STATUSES.open) {
      this.channel.status = CHANNEL_STATUSES.readOnly;
    } else {
      this.channel.status = CHANNEL_STATUSES.open;
    }
  }

  @action
  toggleSending() {
    this.chatChannelPane.sending = !this.chatChannelPane.sending;
  }

  @action
  onSendMessage() {
    this.chatChannelComposer.reset();
  }
}

<StyleguideExample @title="<ChatComposer>">
  <Styleguide::Component>
    <Chat::Composer::Channel
      @channel={{this.channel}}
      @onSendMessage={{this.onSendMessage}}
    />
  </Styleguide::Component>

  <Styleguide::Controls>
    <Styleguide::Controls::Row @name="Disabled">
      <DToggleSwitch
        @state={{this.channel.isReadOnly}}
        {{on "click" this.toggleDisabled}}
      />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="Sending">
      <DToggleSwitch
        @state={{this.chatChannelPane.sending}}
        {{on "click" this.toggleSending}}
      />
    </Styleguide::Controls::Row>
  </Styleguide::Controls>
</StyleguideExample>