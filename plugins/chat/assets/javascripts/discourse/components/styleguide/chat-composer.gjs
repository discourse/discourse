import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { optionalRequire } from "discourse/lib/utilities";
import Channel from "discourse/plugins/chat/discourse/components/chat/composer/channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";

const StyleguideComponent = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/component"
);
const Controls = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls"
);
const Row = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls/row"
);
const StyleguideExample = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide-example"
);

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

  <template>
    <StyleguideExample @title="<ChatComposer>">
      <StyleguideComponent>
        <Channel
          @channel={{this.channel}}
          @onSendMessage={{this.onSendMessage}}
        />
      </StyleguideComponent>

      <Controls>
        <Row @name="Disabled">
          <DToggleSwitch
            @state={{this.channel.isReadOnly}}
            {{on "click" this.toggleDisabled}}
          />
        </Row>
        <Row @name="Sending">
          <DToggleSwitch
            @state={{this.chatChannelPane.sending}}
            {{on "click" this.toggleSending}}
          />
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
