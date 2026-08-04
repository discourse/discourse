import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { type ModifierLike } from "@glint/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDraggableUntyped from "discourse/ui-kit/modifiers/d-draggable";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import I18n, { i18n } from "discourse-i18n";
import { CORE_TOOLS } from "./tools";

/**
 * The pointer events `d-draggable` reports. Both forms reach the same handlers,
 * and either one may be the one carrying the coordinate.
 */
type DDraggableEvent = MouseEvent | TouchEvent;

// TODO(devxp-typescript-pending): drop once d-draggable is authored in
// TypeScript with a real Signature, then import it directly. Untyped today, so
// it carries no argument types of its own. `didEndDrag` is required because the
// modifier calls it unguarded.
const dDraggable = dDraggableUntyped as unknown as ModifierLike<{
  Element: HTMLElement;
  Args: {
    Named: {
      didStartDrag?: (event: DDraggableEvent) => void;
      didEndDrag: (event: DDraggableEvent, element: HTMLElement) => void;
      dragMove?: (event: DDraggableEvent, element: HTMLElement) => void;
    };
  };
}>;

// TODO(devxp-typescript-pending): `disableDevTools` is installed on `window` by
// the dev-tools initializer, which is untyped JavaScript. Drop this once that
// initializer declares the global itself.
type DevToolsWindow = Window & { disableDevTools?: () => void };

export default class Toolbar extends Component {
  @tracked activeDragOffset: number | null | undefined;
  @tracked ownSize = 0;
  @tracked top = 250;

  get style() {
    const clampedTop = Math.max(this.top, 0);
    return trustHTML(`top: min(100dvh - ${this.ownSize}px, ${clampedTop}px);`);
  }

  @action
  disableDevTools() {
    I18n.disableVerboseLocalizationSession();
    (window as DevToolsWindow).disableDevTools!();
  }

  @action
  didStartDrag(event: DDraggableEvent) {
    const realTop = (event.target as HTMLElement)
      .closest(".dev-tools-toolbar")
      .getBoundingClientRect().top;
    const dragStartedAtY =
      (event as MouseEvent).pageY || (event as TouchEvent).touches[0].pageY;
    this.activeDragOffset = dragStartedAtY - realTop;
  }

  @action
  didEndDrag() {
    this.activeDragOffset = null;
  }

  @action
  dragMove(event: DDraggableEvent) {
    const dragY =
      (event as MouseEvent).pageY || (event as TouchEvent).touches[0].pageY;
    this.top = dragY - this.activeDragOffset!;
  }

  @action
  onResize(entries: ResizeObserverEntry[]) {
    this.ownSize = entries[0].contentRect.height;
  }

  <template>
    <div
      class={{dConcatClass
        "dev-tools-toolbar"
        (if this.activeDragOffset "--dragging")
      }}
      style={{this.style}}
      {{dOnResize this.onResize}}
    >
      <button
        type="button"
        title={{i18n "dev_tools.drag_to_move"}}
        class="gripper"
        {{dDraggable
          didStartDrag=this.didStartDrag
          didEndDrag=this.didEndDrag
          dragMove=this.dragMove
        }}
      >
        {{dIcon "grip-lines"}}
      </button>
      {{#each CORE_TOOLS key="id" as |tool|}}
        <tool.component />
      {{/each}}
      <button
        type="button"
        title={{i18n "dev_tools.disable_dev_tools"}}
        class="disable-dev-tools"
        {{on "click" this.disableDevTools}}
      >
        {{dIcon "xmark"}}
      </button>
    </div>
  </template>
}
