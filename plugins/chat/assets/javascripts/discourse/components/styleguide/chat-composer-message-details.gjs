import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import ChatComposerMessageDetails from "discourse/plugins/chat/discourse/components/chat-composer-message-details";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import DButton from "discourse/components/d-button";

export default class ChatStyleguideChatComposerMessageDetails extends Component {
  @service site;
  @service session;
  @service keyValueStore;
  @service currentUser;

  @cached
  get message() {
    return new ChatFabricators(getOwner(this)).message({
      user: this.currentUser,
    });
  }

  @action
  toggleMode() {
    if (this.message.editing) {
      this.message.editing = false;
      this.message.inReplyTo = new ChatFabricators(getOwner(this)).message();
    } else {
      this.message.editing = true;
      this.message.inReplyTo = null;
    }
  }
<template><StyleguideExample @title="<ChatComposerMessageDetails>">
  <StyleguideComponent>
    <ChatComposerMessageDetails @message={{this.message}} />
  </StyleguideComponent>

  <Controls>
    <Row @name="Mode">
      {{#if this.message.editing}}
        <DButton @action={{this.toggleMode}} @translatedLabel="Reply" />
      {{else}}
        <DButton @action={{this.toggleMode}} @translatedLabel="Editing" />
      {{/if}}
    </Row>
  </Controls>
</StyleguideExample></template>}
