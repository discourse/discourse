import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { bind } from "discourse/lib/decorators";
import { isDocumentRTL } from "discourse/lib/text-direction";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";

interface DOverflowControlsSignature {
  Args: {
    /** Extra class(es) added to the outer wrapper element. */
    wrapperClass?: string;
    /** Extra class(es) added to the scrollable content element. */
    class?: string;
    /** Extra class(es) added to each edge scroll button. */
    buttonClass?: string;
  };

  Element: HTMLDivElement;

  Blocks: {
    default: [];
  };
}

/**
 * Wraps scrollable content and shows chevron + gradient-fade buttons on whichever
 * edges can still be scrolled. Works on both axes: a horizontally-overflowing
 * child gets left/right buttons, a vertically-overflowing one gets up/down. State
 * is recomputed on insert, resize, and scroll.
 *
 * Consumers can theme the buttons with the `--fade-color` and `--fade-width` CSS
 * custom properties, and augment the generated classes via `@wrapperClass`,
 * `@class` (scrollable content) and `@buttonClass`. Any `...attributes` land on
 * the scrollable content element.
 */
export default class DOverflowControls extends Component<DOverflowControlsSignature> {
  @tracked hasTopScroll = false;
  @tracked hasBottomScroll = false;
  @tracked hasLeftScroll = false;
  @tracked hasRightScroll = false;

  #scrollable: HTMLElement | null = null;
  #canScrollX = false;
  #canScrollY = false;
  #mutationObserver?: MutationObserver;

  @action
  setup(element: HTMLElement) {
    this.#scrollable = element;
    this.#refreshScrollableAxes(element);
    this.#checkScroll(element);

    // content added/removed (e.g. async-loaded items) changes overflow without
    // resizing the scroll box, which a ResizeObserver wouldn't catch
    this.#mutationObserver = new MutationObserver(() =>
      this.#checkScroll(element)
    );
    this.#mutationObserver.observe(element, { childList: true });
    registerDestructor(this, () => this.#mutationObserver?.disconnect());
  }

  @bind
  onResize(entries: ResizeObserverEntry[]) {
    // overflow can flip axis at a breakpoint, so re-read it on resize
    const element = entries[0].target as HTMLElement;
    this.#refreshScrollableAxes(element);
    this.#checkScroll(element);
  }

  @action
  onScroll(event: Event) {
    this.#checkScroll(event.target as HTMLElement);
  }

  @action
  scrollLeft() {
    this.#scrollByViewport(-1, 0);
  }

  @action
  scrollRight() {
    this.#scrollByViewport(1, 0);
  }

  @action
  scrollUp() {
    this.#scrollByViewport(0, -1);
  }

  @action
  scrollDown() {
    this.#scrollByViewport(0, 1);
  }

  @action
  preventFocusGrab(event: MouseEvent) {
    event.preventDefault();
  }

  #refreshScrollableAxes(element: HTMLElement) {
    const { overflowX, overflowY } = getComputedStyle(element);
    this.#canScrollX = overflowX === "auto" || overflowX === "scroll";
    this.#canScrollY = overflowY === "auto" || overflowY === "scroll";
  }

  #checkScroll(element: HTMLElement) {
    const {
      scrollWidth,
      scrollLeft,
      offsetWidth,
      scrollHeight,
      scrollTop,
      offsetHeight,
    } = element;

    const hasHorizontalOverflow = this.#canScrollX && scrollWidth > offsetWidth;
    const canScrollBack = hasHorizontalOverflow && Math.abs(scrollLeft) > 2;
    const canScrollForward =
      hasHorizontalOverflow &&
      scrollWidth - Math.abs(scrollLeft) - offsetWidth > 2;

    // Buttons stay in physical positions (rtl:ignore in CSS), but in RTL
    // the scroll direction is reversed, so swap which button shows
    if (isDocumentRTL()) {
      this.hasLeftScroll = canScrollForward;
      this.hasRightScroll = canScrollBack;
    } else {
      this.hasLeftScroll = canScrollBack;
      this.hasRightScroll = canScrollForward;
    }

    const hasVerticalOverflow = this.#canScrollY && scrollHeight > offsetHeight;
    this.hasTopScroll = hasVerticalOverflow && scrollTop > 2;
    this.hasBottomScroll =
      hasVerticalOverflow && scrollHeight - scrollTop - offsetHeight > 2;
  }

  #scrollByViewport(dx: number, dy: number) {
    const element = this.#scrollable;
    if (!element) {
      return;
    }

    element.scrollBy({
      left: dx * element.offsetWidth,
      top: dy * element.offsetHeight,
      behavior: "smooth",
    });
  }

  <template>
    <div class={{dConcatClass "d-overflow-controls" @wrapperClass}}>
      {{#if this.hasTopScroll}}
        {{! eslint-disable ember/template-no-pointer-down-event-binding }}
        <button
          type="button"
          aria-hidden="true"
          class={{dConcatClass "d-overflow-controls__btn --up" @buttonClass}}
          tabindex="-1"
          {{on "mousedown" this.preventFocusGrab}}
          {{on "click" this.scrollUp}}
        >
          {{dIcon "chevron-up"}}
        </button>
      {{/if}}

      {{#if this.hasLeftScroll}}
        {{! eslint-disable ember/template-no-pointer-down-event-binding }}
        <button
          type="button"
          aria-hidden="true"
          class={{dConcatClass "d-overflow-controls__btn --left" @buttonClass}}
          tabindex="-1"
          {{on "mousedown" this.preventFocusGrab}}
          {{on "click" this.scrollLeft}}
        >
          {{dIcon "chevron-left"}}
        </button>
      {{/if}}

      <div
        class={{dConcatClass "d-overflow-controls__content" @class}}
        {{didInsert this.setup}}
        {{dOnResize this.onResize}}
        {{on "scroll" this.onScroll}}
        ...attributes
      >
        {{yield}}
      </div>

      {{#if this.hasRightScroll}}
        {{! eslint-disable ember/template-no-pointer-down-event-binding }}
        <button
          type="button"
          aria-hidden="true"
          class={{dConcatClass "d-overflow-controls__btn --right" @buttonClass}}
          tabindex="-1"
          {{on "mousedown" this.preventFocusGrab}}
          {{on "click" this.scrollRight}}
        >
          {{dIcon "chevron-right"}}
        </button>
      {{/if}}

      {{#if this.hasBottomScroll}}
        {{! eslint-disable ember/template-no-pointer-down-event-binding }}
        <button
          type="button"
          aria-hidden="true"
          class={{dConcatClass "d-overflow-controls__btn --down" @buttonClass}}
          tabindex="-1"
          {{on "mousedown" this.preventFocusGrab}}
          {{on "click" this.scrollDown}}
        >
          {{dIcon "chevron-down"}}
        </button>
      {{/if}}
    </div>
  </template>
}
