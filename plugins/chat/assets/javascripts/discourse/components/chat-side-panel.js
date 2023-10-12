import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";

const MIN_CHAT_CHANNEL_WIDTH = 250;

export default class ChatSidePanel extends Component {
  @service chatStateManager;
  @service chatSidePanelSize;
  @service site;

  @tracked widthStyle;

  @action
  setupSize() {
    this.widthStyle = htmlSafe(`width:${this.chatSidePanelSize.width}px`);
  }

  @action
  didResize(element, size) {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const parentWidth = element.parentElement.getBoundingClientRect().width;
    const mainPanelWidth = parentWidth - size.width;

    if (mainPanelWidth >= MIN_CHAT_CHANNEL_WIDTH) {
      this.chatSidePanelSize.width = size.width;
      element.style.width = size.width + "px";
      this.widthStyle = htmlSafe(`width:${size.width}px`);
    }
  }

  #maxWidth(element) {
    const parentWidth = element.parentElement.getBoundingClientRect().width;
    return parentWidth - MIN_CHAT_CHANNEL_WIDTH;
  }
}
