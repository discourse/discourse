import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Item from "discourse/plugins/chat/discourse/components/chat/thread-list/item";

export default class ChatStyleguideChatThreadListItem extends Component {
  @service currentUser;

  @tracked thread;

  constructor() {
    super(...arguments);

    next(() => {
      this.thread = new ChatFabricators(getOwner(this)).thread();
    });
  }
<template><StyleguideExample @title="<Chat::ThreadList::Item>">
  <StyleguideComponent>
    {{#if this.thread}}
      <Item @thread={{this.thread}} />
    {{/if}}
  </StyleguideComponent>
</StyleguideExample></template>}
