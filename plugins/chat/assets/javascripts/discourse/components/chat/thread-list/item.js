import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatThreadListItem extends Component {
  @service router;

  get title() {
    return this.args.thread.escapedTitle;
  }

  @action
  openThread(thread) {
    this.router.transitionTo("chat.channel.thread", ...thread.routeModels);
  }
}
