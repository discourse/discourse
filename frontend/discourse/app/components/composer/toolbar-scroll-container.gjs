import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { isDocumentRTL } from "discourse/lib/text-direction";
import onResize from "discourse/modifiers/on-resize";

export default class ToolbarScrollContainer extends Component {
  @tracked hasLeftScroll = false;
  @tracked hasRightScroll = false;
  scrollable = null;

  @action
  setup(element) {
    this.scrollable = element;
    this.checkScroll(element);
  }

  @bind
  onResize(entries) {
    this.checkScroll(entries[0].target);
  }

  @action
  onScroll(event) {
    this.checkScroll(event.target);
  }

  checkScroll(element) {
    const { scrollWidth, scrollLeft, offsetWidth } = element;
    const hasOverflow = scrollWidth > offsetWidth;
    const canScrollBack = hasOverflow && Math.abs(scrollLeft) > 2;
    const canScrollForward =
      hasOverflow && scrollWidth - Math.abs(scrollLeft) - offsetWidth > 2;

    // Buttons stay in physical positions (rtl:ignore in CSS), but in RTL
    // the scroll direction is reversed, so swap which button shows
    if (isDocumentRTL()) {
      this.hasLeftScroll = canScrollForward;
      this.hasRightScroll = canScrollBack;
    } else {
      this.hasLeftScroll = canScrollBack;
      this.hasRightScroll = canScrollForward;
    }
  }

  @action
  scrollLeft() {
    this.scrollable?.scrollBy({
      left: -this.scrollable.offsetWidth,
      behavior: "smooth",
    });
  }

  @action
  scrollRight() {
    this.scrollable?.scrollBy({
      left: this.scrollable.offsetWidth,
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
