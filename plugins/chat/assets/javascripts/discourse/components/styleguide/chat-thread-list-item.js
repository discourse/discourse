import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatThreadListItem extends Component {
  @service currentUser;
  @tracked thread;

  constructor() {
    super(...arguments);

    next(() => {
      this.thread = new ChatFabricators(getOwner(this)).thread();
    });
  }
}
