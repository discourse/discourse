import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and } from "truth-helpers";
import resizableNode from "../modifiers/chat/resizable-node";
import ChatSidePanelResizer from "./chat-side-panel-resizer";

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

  <template>
    {{#if this.chatStateManager.isSidePanelExpanded}}
      <div
        class="chat-side-panel"
        {{didInsert this.setupSize}}
        {{resizableNode
          ".chat-side-panel-resizer"
          this.didResize
          (hash
            position=false vertical=false mutate=false resetOnWindowResize=true
          )
        }}
        style={{if
          (and this.site.desktopView this.chatStateManager.isFullPageActive)
          this.widthStyle
        }}
      >
        {{yield}}

        {{#if this.site.desktopView}}
          <ChatSidePanelResizer />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
