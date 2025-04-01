import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ChatModalDeleteChannel from "discourse/plugins/chat/discourse/components/chat/modal/delete-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import DButton from "discourse/components/d-button";

export default class ChatStyleguideChatModalDeleteChannel extends Component {
  @service modal;

  channel = new ChatFabricators(getOwner(this)).channel();

  @action
  openModal() {
    return this.modal.show(ChatModalDeleteChannel, {
      model: { channel: this.channel },
    });
  }
<template><StyleguideExample @title="<Chat::Modal::DeleteChannel>">
  <Row>
    <DButton @translatedLabel="Open modal" @action={{this.openModal}} />
  </Row>
</StyleguideExample></template>}
