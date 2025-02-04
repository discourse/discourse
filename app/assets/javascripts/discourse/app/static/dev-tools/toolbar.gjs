import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import draggable from "discourse/modifiers/draggable";
import onResize from "discourse/modifiers/on-resize";
import I18n from "discourse-i18n";
import PluginOutletDebugButton from "./plugin-outlet-debug/button";
import SafeModeButton from "./safe-mode/button";
import VerboseLocalizationButton from "./verbose-localization/button";

export default class Toolbar extends Component {
  @tracked top = 250;
  @tracked ownSize = 0;

  activeDragOffset;

  get style() {
    const clampedTop = Math.max(this.top, 0);
    return htmlSafe(`top: min(100dvh - ${this.ownSize}px, ${clampedTop}px);`);
  }

  @action
  disableDevTools() {
    I18n.disableVerboseLocalizationSession();
    window.disableDevTools();
  }

  @action
  didStartDrag(event) {
    const realTop = event.target
      .closest(".dev-tools-toolbar")
      .getBoundingClientRect().top;
    const dragStartedAtY = event.pageY || event.touches[0].pageY;
    this.activeDragOffset = dragStartedAtY - realTop;
  }

  @action
  didEndDrag() {
    this.activeDragOffset = null;
  }

  @action
  dragMove(event) {
    const dragY = event.pageY || event.touches[0].pageY;
    this.top = dragY - this.activeDragOffset;
  }

  @action
  onResize(entries) {
    this.ownSize = entries[0].contentRect.height;
  }

  <template>
    <div
      class="dev-tools-toolbar"
      style={{this.style}}
      {{onResize this.onResize}}
    >
      <PluginOutletDebugButton />
      <SafeModeButton />
      <VerboseLocalizationButton />
      <button
        title="Disable dev tools"
        class="disable-dev-tools"
        {{on "click" this.disableDevTools}}
      >
        {{icon "xmark"}}
      </button>
      <button
        class="gripper"
        title="Drag to move"
        {{draggable
          didStartDrag=this.didStartDrag
          didEndDrag=this.didEndDrag
          dragMove=this.dragMove
        }}
      >
        {{icon "grip-lines"}}
      </button>
    </div>
  </template>
}
