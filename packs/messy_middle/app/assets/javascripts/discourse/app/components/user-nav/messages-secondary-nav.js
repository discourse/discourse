import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class extends Component {
  @service currentUser;

  get messagesNav() {
    return document.getElementById("user-navigation-secondary__horizontal-nav");
  }
}
