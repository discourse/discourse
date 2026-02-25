import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import draggable from "discourse/modifiers/draggable";
import onResize from "discourse/modifiers/on-resize";
import I18n, { i18n } from "discourse-i18n";
import BlockDebugButton from "./block-debug/button";
import MobileViewButton from "./mobile-view/button";
import PluginOutletDebugButton from "./plugin-outlet-debug/button";
import SafeModeButton from "./safe-mode/button";
import VerboseLocalizationButton from "./verbose-localization/button";

export default class Toolbar extends Component {
  @service siteSettings;

  @tracked activeDragOffset;
  @tracked ownSize = 0;
  @tracked top = 250;

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
      class={{concatClass
        "dev-tools-toolbar"
        (if this.activeDragOffset "--dragging")
      }}
      style={{this.style}}
      {{onResize this.onResize}}
    >
      <button
        type="button"
        title={{i18n "dev_tools.drag_to_move"}}
        class="gripper"
        {{draggable
          didStartDrag=this.didStartDrag
          didEndDrag=this.didEndDrag
          dragMove=this.dragMove
        }}
      >
        {{icon "grip-lines"}}
      </button>
      <PluginOutletDebugButton />
      <BlockDebugButton />
      <SafeModeButton />
      <VerboseLocalizationButton />
      {{#unless this.siteSettings.viewport_based_mobile_mode}}
        <MobileViewButton />
      {{/unless}}
      <button
        type="button"
        title={{i18n "dev_tools.disable_dev_tools"}}
        class="disable-dev-tools"
        {{on "click" this.disableDevTools}}
      >
        {{icon "xmark"}}
      </button>
    </div>
  </template>
}
