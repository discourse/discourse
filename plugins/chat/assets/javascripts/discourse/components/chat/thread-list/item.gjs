import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatThreadListItem extends Component {
  @service router;

  @action
  openThread(thread) {
    this.router.transitionTo("chat.channel.thread", ...thread.routeModels);
  }
}
