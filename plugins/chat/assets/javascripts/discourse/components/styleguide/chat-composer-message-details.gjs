import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import ChatComposerMessageDetails from "discourse/plugins/chat/discourse/components/chat-composer-message-details";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import Component0 from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

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
  <Component0>
    <ChatComposerMessageDetails @message={{this.message}} />
  </Component0>

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
