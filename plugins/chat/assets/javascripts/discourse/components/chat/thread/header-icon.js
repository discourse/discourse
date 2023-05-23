import { inject as service } from "@ember/service";
import Component from "@glimmer/component";

export default class ChatThreadHeaderIcon extends Component {
  @service currentUser;

  get currentUserInDnD() {
    return this.currentUser.isInDoNotDisturb();
  }
}
