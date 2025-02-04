import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";
import resizableNode from "../modifiers/chat/resizable-node";
import ChatSidePanelResizer from "./chat-side-panel-resizer";

const MIN_PANEL_WIDTH = 250;
const STORE_NAMESPACE = "discourse_chat_side_panel_size_";

export default class ChatSidePanel extends Component {
  @service chatStateManager;
  @service site;

  store = new KeyValueStore(STORE_NAMESPACE);

  @action
  setupSize(element) {
    if (this.site.mobileView) {
      return;
    }

    if (!this.chatStateManager.isFullPageActive) {
      return;
    }

    const validWidth = Math.min(
      this.store.getObject("width") ?? MIN_PANEL_WIDTH,
      this.mainContainerWidth - MIN_PANEL_WIDTH
    );

    element.animate(
      [{ width: element.style.width }, { width: validWidth + "px" }],
      { duration: 0, fill: "forwards" }
    );
    this.storeWidth(validWidth);
  }

  @action
  didResize(element, size) {
    const mainPanelWidth = this.mainContainerWidth - size.width;

    if (size.width >= MIN_PANEL_WIDTH && mainPanelWidth >= MIN_PANEL_WIDTH) {
      element.animate(
        [{ width: element.style.width }, { width: size.width + "px" }],
        { duration: 0, fill: "forwards" }
      );
      this.storeWidth(size.width);
    }
  }

  get mainContainerWidth() {
    return document.getElementById("main-chat-outlet").clientWidth;
  }

  storeWidth(width) {
    this.store.setObject({
      key: "width",
      value: width,
    });
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
      >
        {{yield}}

        {{#if this.site.desktopView}}
          <ChatSidePanelResizer />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
