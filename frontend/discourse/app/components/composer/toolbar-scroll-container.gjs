import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { measureScrollBounds } from "discourse/lib/scroll-utils";
import { isDocumentRTL } from "discourse/lib/text-direction";
import onResize from "discourse/modifiers/on-resize";

export default class ToolbarScrollContainer extends Component {
  @tracked hasLeftScroll = false;
  @tracked hasRightScroll = false;
  scrollable = null;
  #minScrollLeft = 0;
  #maxScrollLeft = 0;

  @action
  setup(element) {
    this.scrollable = element;
    this.#updateScrollBounds(element);
    this.checkScroll(element);

    const observer = new MutationObserver(() => {
      this.#updateScrollBounds(element);
      this.checkScroll(element);
    });
    observer.observe(element, { childList: true });
    registerDestructor(this, () => observer.disconnect());
  }

  @bind
  onResize(entries) {
    const element = entries[0].target;
    this.#updateScrollBounds(element);
    this.checkScroll(element);
  }

  @action
  onScroll(event) {
    this.checkScroll(event.target);
  }

  #updateScrollBounds(element) {
    const { min, max } = measureScrollBounds(element);
    this.#minScrollLeft = min;
    this.#maxScrollLeft = max;
  }

  checkScroll(element) {
    const hasOverflow = element.scrollWidth > element.offsetWidth;
    const scrolledFromMin =
      hasOverflow && element.scrollLeft - this.#minScrollLeft > 2;
    const scrolledFromMax =
      hasOverflow && this.#maxScrollLeft - element.scrollLeft > 2;

    if (isDocumentRTL()) {
      // rtlcss swaps the physical positions of --left/--right buttons,
      // so we swap which condition controls which button
      this.hasLeftScroll = scrolledFromMax;
      this.hasRightScroll = scrolledFromMin;
    } else {
      this.hasLeftScroll = scrolledFromMin;
      this.hasRightScroll = scrolledFromMax;
    }
  }

  @action
  scrollLeft() {
    const direction = isDocumentRTL() ? 1 : -1;
    this.scrollable?.scrollBy({
      left: direction * this.scrollable.offsetWidth,
      behavior: "smooth",
    });
  }

  @action
  scrollRight() {
    const direction = isDocumentRTL() ? -1 : 1;
    this.scrollable?.scrollBy({
      left: direction * this.scrollable.offsetWidth,
      behavior: "smooth",
    });
  }

  @action
  preventFocusGrab(event) {
    event.preventDefault();
  }

  <template>
    <div class="d-editor-button-bar__wrap">
      {{#if this.hasLeftScroll}}
        {{! template-lint-disable no-pointer-down-event-binding }}
        <button
          type="button"
          class="d-editor-button-bar__scroll-btn --left"
          tabindex="-1"
          {{on "mousedown" this.preventFocusGrab}}
          {{on "click" this.scrollLeft}}
        >
          {{icon "chevron-left"}}
        </button>
      {{/if}}

      <div
        class={{concatClass "d-editor-button-bar" @class}}
        role="toolbar"
        {{didInsert this.setup}}
        {{onResize this.onResize}}
        {{on "scroll" this.onScroll}}
      >
        {{yield}}
      </div>

      {{#if this.hasRightScroll}}
        {{! template-lint-disable no-pointer-down-event-binding }}
        <button
          type="button"
          class="d-editor-button-bar__scroll-btn --right"
          tabindex="-1"
          {{on "mousedown" this.preventFocusGrab}}
          {{on "click" this.scrollRight}}
        >
          {{icon "chevron-right"}}
        </button>
      {{/if}}
    </div>
  </template>
}
