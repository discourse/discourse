import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import Component0 from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Channel from "discourse/plugins/chat/discourse/components/chat/composer/channel";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { on } from "@ember/modifier";

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
<template><StyleguideExample @title="<ChatComposer>">
  <Component0>
    <Channel @channel={{this.channel}} @onSendMessage={{this.onSendMessage}} />
  </Component0>

  <Controls>
    <Row @name="Disabled">
      <DToggleSwitch @state={{this.channel.isReadOnly}} {{on "click" this.toggleDisabled}} />
    </Row>
    <Row @name="Sending">
      <DToggleSwitch @state={{this.chatChannelPane.sending}} {{on "click" this.toggleSending}} />
    </Row>
  </Controls>
</StyleguideExample></template>}
