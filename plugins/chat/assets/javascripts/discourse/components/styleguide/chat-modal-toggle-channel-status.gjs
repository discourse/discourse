import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ChatModalToggleChannelStatus from "discourse/plugins/chat/discourse/components/chat/modal/toggle-channel-status";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import DButton from "discourse/components/d-button";

export default class ChatStyleguideChatModalToggleChannelStatus extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalToggleChannelStatus, {
      model: new ChatFabricators(getOwner(this)).channel(),
    });
  }
<template><StyleguideExample @title="<Chat::Modal::ToggleChannelStatus>">
  <Row>
    <DButton @translatedLabel="Open modal" @action={{this.openModal}} />
  </Row>
</StyleguideExample></template>}
