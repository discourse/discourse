import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class ChatComposerDropdown extends Component {
  @action
  onButtonClick(button, closeFn) {
    closeFn();
    button.action();
  }
}
