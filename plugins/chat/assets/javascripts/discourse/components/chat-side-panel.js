import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { tracked } from "@glimmer/tracking";

const MIN_CHAT_CHANNEL_WIDTH = 250;

export default class ChatSidePanel extends Component {
  @service chatStateManager;
  @service chatSidePanelSize;
  @service site;

  @tracked sidePanel;

  @action
  setSidePanel(element) {
    this.sidePanel = element;
  }

  get width() {
    if (!this.sidePanel) {
      return;
    }

    const maxWidth = Math.min(
      this.#maxWidth(this.sidePanel),
      this.chatSidePanelSize.width
    );

    return htmlSafe(`width:${maxWidth}px`);
  }

  @action
  didResize(element, size) {
    const parentWidth = element.parentElement.getBoundingClientRect().width;
    const mainPanelWidth = parentWidth - size.width;

    if (mainPanelWidth > MIN_CHAT_CHANNEL_WIDTH) {
      this.chatSidePanelSize.width = size.width;
      element.style.width = size.width + "px";
    }
  }

  #maxWidth(element) {
    const parentWidth = element.parentElement.getBoundingClientRect().width;
    return parentWidth - MIN_CHAT_CHANNEL_WIDTH;
  }
}
