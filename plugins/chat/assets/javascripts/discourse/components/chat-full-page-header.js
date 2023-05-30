import { inject as service } from "@ember/service";
import Component from "@glimmer/component";

export default class ChatFullPageHeader extends Component {
  @service site;
  @service chatStateManager;
  @service router;

  get displayed() {
    return this.args.displayed ?? true;
  }

  get showThreadsListButton() {
    return (
      this.args.channel.threadingEnabled &&
      this.router.currentRoute.name !== "chat.channel.threads" &&
      this.router.currentRoute.name !== "chat.channel.thread"
    );
  }
}
