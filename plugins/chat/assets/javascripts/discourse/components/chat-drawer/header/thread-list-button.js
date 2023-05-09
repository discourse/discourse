import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
export default class ChatDrawerThreadListButton extends Component {
  @service chat;

  @action
  stopPropagation(event) {
    event.stopPropagation();
  }
}
