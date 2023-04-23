import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";

export default class ChatSidePanel extends Component {
  @service chatStateManager;
  @service chatSidePanelSize;

  width = htmlSafe("width: " + this.chatSidePanelSize.width + "px");

  @action
  didResize(element, size) {
    const parentWidth = element.parentElement.getBoundingClientRect().width;
    const mainPanelWidth = parentWidth - size.width;

    if (mainPanelWidth > 300) {
      this.chatSidePanelSize.width = size.width;
      element.style.width = size.width + "px";
    }
  }
}
