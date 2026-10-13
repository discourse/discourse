import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";
import I18n, { i18n } from "discourse-i18n";
import { CORE_TOOLS } from "./tools";

export default class Toolbar extends Component {
  @tracked activeDragOffset: number | null = null;
  @tracked ownSize = 0;
  @tracked top = 250;

  /**
   * Not the offset's truthiness: a grab exactly at the top edge gives 0, which
   * would read as "not dragging" for the whole gesture.
   */
  get dragging() {
    return this.activeDragOffset !== null;
  }

  get style() {
    const clampedTop = Math.max(this.top, 0);
    return trustHTML(`top: min(100dvh - ${this.ownSize}px, ${clampedTop}px);`);
  }

  @action
  disableDevTools() {
    I18n.disableVerboseLocalizationSession();
    window.disableDevTools();
  }

  @action
  didStartDrag(event: PointerEvent) {
    // The gripper renders inside the toolbar, so the press always has an
    // ancestor to measure against.
    const toolbar = (event.target as Element).closest(".dev-tools-toolbar")!;

    this.activeDragOffset = event.pageY - toolbar.getBoundingClientRect().top;
  }

  @action
  didEndDrag() {
    this.activeDragOffset = null;
  }

  @action
  dragMove(event: PointerEvent) {
    // Only ever called between a drag starting and ending, so the offset the
    // start captured is always there.
    this.top = event.pageY - this.activeDragOffset!;
  }

  @action
  onResize(entries: ResizeObserverEntry[]) {
    this.ownSize = entries[0].contentRect.height;
  }

  <template>
    <div
      class={{dConcatClass "dev-tools-toolbar" (if this.dragging "--dragging")}}
      style={{this.style}}
      {{dOnResize this.onResize}}
    >
      <button
        class="gripper"
        title={{i18n "dev_tools.drag_to_move"}}
        type="button"
        {{! An interrupted drag leaves the toolbar where it was dragged to,
            rather than snapping back to where the grab started. }}
        {{dPointerDrag
          onDragStart=this.didStartDrag
          onDrag=this.dragMove
          onDragEnd=this.didEndDrag
          cancelCommits=true
          bodyClass="dragging"
        }}
      >
        {{dIcon "grip-vertical"}}
      </button>
      {{#each CORE_TOOLS key="id" as |tool|}}
        <tool.component />
      {{/each}}
      <button
        class="disable-dev-tools"
        title={{i18n "dev_tools.disable_dev_tools"}}
        type="button"
        {{on "click" this.disableDevTools}}
      >
        {{dIcon "xmark"}}
      </button>
    </div>
  </template>
}
