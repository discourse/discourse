import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached, tracked } from "@glimmer/tracking";
import type { TOC } from "@ember/component/template-only";
import { assert } from "@ember/debug";
import { isDestroying } from "@ember/destroyable";
import { get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel, schedule } from "@ember/runloop";
import type { ModifierLike } from "@glint/template";
import { modifier } from "ember-modifier";
import discourseLater from "discourse/lib/later";
import { isDocumentRTL } from "discourse/lib/text-direction";
import {
  type ScrollAxis,
  type ScrollEdgesSnapshot,
  ScrollEdgesWatcher,
} from "discourse/ui-kit/-internals/scroll-strip/edges";
import {
  revealInScroller,
  type RevealOptions,
} from "discourse/ui-kit/-internals/scroll-strip/reveal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/** The axis a strip scrolls on. */
export type DOverflowControlsAxis = ScrollAxis;

/** The physical edges a chevron can sit on. */
export type DOverflowControlsEdge = "left" | "right" | "up" | "down";

/** What the default block receives. Consumers of the default mode may ignore it. */
export interface DOverflowControlsBag {
  /**
   * Marks the consumer's own element as the scroller. Owned mode only; apply
   * it to exactly one element, which may mount later inside a conditional.
   */
  scroller: ModifierLike<{ Element: HTMLElement; Args: { Positional: [] } }>;

  /**
   * Scrolls the strip, and only the strip, until `element` lies fully inside
   * it, clear of the fade band. Instant. The page never moves.
   */
  reveal: (element: HTMLElement, options?: RevealOptions) => void;
}

interface DOverflowControlsSignature {
  Args: {
    /** Extra class(es) added to the outer wrapper element. */
    wrapperClass?: string;

    /** Default mode only: extra class(es) added to the generated scroller. */
    class?: string;

    /** Extra class(es) added to every chevron button. */
    buttonClass?: string;

    /**
     * Extra class(es) per physical edge, for stylesheets and specs that
     * address one chevron.
     */
    edgeButtonClasses?: Partial<Record<DOverflowControlsEdge, string>>;

    /**
     * The consumer renders the scrolling element itself and applies the
     * yielded `scroller` modifier to it. No content element is generated,
     * and `...attributes` land on the wrapper instead.
     */
    ownedScroller?: boolean;

    /**
     * The axis the chevrons and the fade follow. When omitted it is detected
     * from the scroller's computed overflow on both axes, re-read on resize,
     * and both axes may show chevrons at once while the fade follows the
     * one that overflows. Either way, an axis whose computed overflow is
     * not scrollable never shows a chevron.
     */
    axis?: DOverflowControlsAxis;
  };

  /**
   * The generated scroller in the default mode; the wrapper in owned mode,
   * where the consumer's own element is the scroller.
   */
  Element: HTMLDivElement;

  Blocks: {
    /** The scrolled content, with the strip's controls as the block param. */
    default: [strip: DOverflowControlsBag];
  };
}

/** How long a press must last before it starts scrolling continuously. */
const HOLD_DELAY_MS = 300;

/** Viewports scrolled per second while a chevron stays pressed. */
const HOLD_VELOCITY = 3;

const EDGE_ICONS: Record<DOverflowControlsEdge, string> = {
  left: "chevron-left",
  right: "chevron-right",
  up: "chevron-up",
  down: "chevron-down",
};

function prefersReducedMotion() {
  return (
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

function preventFocusGrab(event: MouseEvent) {
  event.preventDefault();
}

interface EdgeButtonSignature {
  Args: {
    edge: DOverflowControlsEdge;
    class: string | undefined;
    onClick: () => void;
    hold: ModifierLike<{
      Element: HTMLElement;
      Args: { Positional: [edge: DOverflowControlsEdge] };
    }>;
  };
}

/**
 * One chevron. Hidden from assistive technology and out of the tab order:
 * a keyboard user already reaches every item with Tab or the arrow keys, so
 * the button is a pointer shortcut only. The mousedown handler keeps a
 * click from moving focus off whatever the user was working in.
 */
const EdgeButton: TOC<EdgeButtonSignature> = <template>
  {{! eslint-disable ember/template-no-pointer-down-event-binding }}
  <button
    type="button"
    aria-hidden="true"
    class={{dConcatClass "d-overflow-controls__btn" (concat "--" @edge) @class}}
    tabindex="-1"
    {{on "mousedown" preventFocusGrab}}
    {{on "click" @onClick}}
    {{@hold @edge}}
  >
    {{dIcon (get EDGE_ICONS @edge)}}
  </button>
</template>;

function concat(prefix: string, edge: string) {
  return `${prefix}${edge}`;
}

/**
 * Wraps scrollable content and shows chevron buttons on whichever edges can
 * still be scrolled, over an edge fade painted by the scroller's stylesheet.
 * Works on both axes: a horizontally-overflowing scroller gets left and
 * right buttons, a vertically-overflowing one gets up and down. A click
 * scrolls one viewport; holding a chevron scrolls continuously.
 *
 * In the default mode the component renders the scroller itself and any
 * `...attributes` land on it. With `@ownedScroller` the consumer's own
 * element is the scroller (the consumer applies the yielded `scroller`
 * modifier to it) and `...attributes` land on the wrapper.
 *
 * The scroller carries `data-d-scroll-*` attributes describing its edge
 * state; the `scroll-strip` stylesheet mixin reads them for the fade. Themes
 * can colour the buttons with the `--fade-color` custom property and size
 * the fade with `--fade-width`.
 */
export default class DOverflowControls extends Component<DOverflowControlsSignature> {
  @tracked hasTopScroll = false;
  @tracked hasBottomScroll = false;
  @tracked hasLeftScroll = false;
  @tracked hasRightScroll = false;

  /**
   * Adopts an element as the strip's scroller and keeps its edge state
   * current for as long as it stays mounted. One stable definition, so a
   * scroller that survives a re-render keeps its watcher.
   */
  scroller = modifier((element: HTMLElement) => {
    if (DEBUG) {
      assert(
        "d-overflow-controls: strip.scroller was applied to a second element while another scroller is still mounted",
        !this.#scroller ||
          this.#scroller === element ||
          !this.#scroller.isConnected
      );
    }
    this.#scroller = element;
    const watcher = new ScrollEdgesWatcher(element, {
      axis: this.args.axis ?? "auto",
      onChange: (snapshot) => this.#applyEdges(snapshot),
    });

    return () => {
      watcher.disconnect();
      if (this.#scroller === element) {
        this.#scroller = null;
      }
    };
  });

  /**
   * Press-and-hold on a chevron. State lives in the install closure, so a
   * chevron unmounted at its edge mid-hold takes its hold with it.
   *
   * The click that ends a real hold is swallowed once, so a plain click
   * still scrolls exactly one viewport.
   */
  hold = modifier((button: HTMLElement, [edge]: [DOverflowControlsEdge]) => {
    let held = false;
    let timer: ReturnType<typeof discourseLater> | null = null;
    let frame: number | null = null;
    let lastFrameAt = 0;
    let pointerId: number | null = null;

    const step = (now: number) => {
      const scroller = this.#scroller;
      if (!scroller) {
        return;
      }
      held = true;
      const seconds = Math.max(0, now - lastFrameAt) / 1000;
      lastFrameAt = now;
      const horizontal = edge === "left" || edge === "right";
      const viewport = horizontal
        ? scroller.clientWidth
        : scroller.clientHeight;
      const direction = edge === "left" || edge === "up" ? -1 : 1;
      const distance = direction * HOLD_VELOCITY * viewport * seconds;
      scroller.scrollBy({
        left: horizontal ? distance : 0,
        top: horizontal ? 0 : distance,
        behavior: "instant",
      });
      frame = requestAnimationFrame(step);
    };

    const stop = () => {
      if (timer) {
        cancel(timer);
        timer = null;
      }
      if (frame !== null) {
        cancelAnimationFrame(frame);
        frame = null;
      }
      window.removeEventListener("blur", stop);
      if (pointerId !== null) {
        if (button.hasPointerCapture(pointerId)) {
          button.releasePointerCapture(pointerId);
        }
        pointerId = null;
      }
    };

    const onPointerDown = (event: PointerEvent) => {
      if (
        pointerId !== null ||
        event.button !== 0 ||
        event.isPrimary === false ||
        event.pointerType === "touch"
      ) {
        return;
      }
      held = false;
      stop();
      pointerId = event.pointerId;
      button.setPointerCapture(event.pointerId);
      // Losing window focus ends a press without a pointerup.
      window.addEventListener("blur", stop);
      timer = discourseLater(() => {
        timer = null;
        lastFrameAt = performance.now();
        frame = requestAnimationFrame(step);
      }, HOLD_DELAY_MS);
    };

    const onClick = (event: MouseEvent) => {
      if (!held) {
        return;
      }
      held = false;
      event.preventDefault();
      event.stopImmediatePropagation();
    };

    // Only the pointer that started the hold may end it: a second pointer
    // resting on the same button must not cut a mouse hold short.
    const onPointerEnd = (event: PointerEvent) => {
      if (event.pointerId === pointerId) {
        stop();
      }
    };

    button.addEventListener("pointerdown", onPointerDown);
    button.addEventListener("pointerup", onPointerEnd);
    button.addEventListener("pointercancel", onPointerEnd);
    button.addEventListener("lostpointercapture", onPointerEnd);
    button.addEventListener("click", onClick, { capture: true });

    return () => {
      stop();
      button.removeEventListener("pointerdown", onPointerDown);
      button.removeEventListener("pointerup", onPointerEnd);
      button.removeEventListener("pointercancel", onPointerEnd);
      button.removeEventListener("lostpointercapture", onPointerEnd);
      button.removeEventListener("click", onClick, { capture: true });
    };
  });
  #scroller: HTMLElement | null = null;

  /** Built without reading tracked state, so its identity never changes. */
  @cached
  get strip(): DOverflowControlsBag {
    return { scroller: this.scroller, reveal: this.reveal };
  }

  @action
  reveal(element: HTMLElement, options?: RevealOptions) {
    if (this.#scroller) {
      revealInScroller(this.#scroller, element, options);
    }
  }

  @action
  scrollDown() {
    this.#scrollByViewport(0, 1);
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

  /**
   * Tracked writes are deferred one hop: the first measurement runs inside
   * the scroller's modifier install, still within the render transaction.
   */
  #applyEdges(snapshot: ScrollEdgesSnapshot) {
    schedule("afterRender", () => {
      if (isDestroying(this)) {
        return;
      }

      const { horizontal, vertical } = snapshot;
      const canScrollBack = !!horizontal?.overflowing && !horizontal.atStart;
      const canScrollForward = !!horizontal?.overflowing && !horizontal.atEnd;

      // Buttons stay in physical positions (rtl:ignore in CSS), but in RTL
      // the scroll direction is reversed, so swap which button shows.
      if (isDocumentRTL()) {
        this.hasLeftScroll = canScrollForward;
        this.hasRightScroll = canScrollBack;
      } else {
        this.hasLeftScroll = canScrollBack;
        this.hasRightScroll = canScrollForward;
      }
      this.hasTopScroll = !!vertical?.overflowing && !vertical.atStart;
      this.hasBottomScroll = !!vertical?.overflowing && !vertical.atEnd;
    });
  }

  #scrollByViewport(dx: number, dy: number) {
    const element = this.#scroller;
    if (!element) {
      return;
    }

    // iOS Safari doesn't clamp smooth programmatic scrolls, so an
    // out-of-bounds target rubber-bands into blank overscroll space
    const options: ScrollToOptions = {
      behavior: prefersReducedMotion() ? "instant" : "smooth",
    };

    if (dx) {
      const max = element.scrollWidth - element.offsetWidth;
      const target = element.scrollLeft + dx * element.offsetWidth;
      const [lower, upper] = isDocumentRTL() ? [-max, 0] : [0, max];
      options.left = Math.max(lower, Math.min(target, upper));
    } else {
      const max = element.scrollHeight - element.offsetHeight;
      const target = element.scrollTop + dy * element.offsetHeight;
      options.top = Math.max(0, Math.min(target, max));
    }

    element.scrollTo(options);
  }

  <template>
    {{#if @ownedScroller}}
      <div
        class={{dConcatClass
          "d-overflow-controls"
          "--owned-scroller"
          @wrapperClass
        }}
        ...attributes
      >
        {{#if this.hasTopScroll}}
          <EdgeButton
            @edge="up"
            @class={{dConcatClass @buttonClass (get @edgeButtonClasses "up")}}
            @onClick={{this.scrollUp}}
            @hold={{this.hold}}
          />
        {{/if}}
        {{#if this.hasLeftScroll}}
          <EdgeButton
            @edge="left"
            @class={{dConcatClass @buttonClass (get @edgeButtonClasses "left")}}
            @onClick={{this.scrollLeft}}
            @hold={{this.hold}}
          />
        {{/if}}

        {{yield this.strip}}

        {{#if this.hasRightScroll}}
          <EdgeButton
            @edge="right"
            @class={{dConcatClass
              @buttonClass
              (get @edgeButtonClasses "right")
            }}
            @onClick={{this.scrollRight}}
            @hold={{this.hold}}
          />
        {{/if}}
        {{#if this.hasBottomScroll}}
          <EdgeButton
            @edge="down"
            @class={{dConcatClass @buttonClass (get @edgeButtonClasses "down")}}
            @onClick={{this.scrollDown}}
            @hold={{this.hold}}
          />
        {{/if}}
      </div>
    {{else}}
      <div class={{dConcatClass "d-overflow-controls" @wrapperClass}}>
        {{#if this.hasTopScroll}}
          <EdgeButton
            @edge="up"
            @class={{dConcatClass @buttonClass (get @edgeButtonClasses "up")}}
            @onClick={{this.scrollUp}}
            @hold={{this.hold}}
          />
        {{/if}}
        {{#if this.hasLeftScroll}}
          <EdgeButton
            @edge="left"
            @class={{dConcatClass @buttonClass (get @edgeButtonClasses "left")}}
            @onClick={{this.scrollLeft}}
            @hold={{this.hold}}
          />
        {{/if}}

        <div
          class={{dConcatClass "d-overflow-controls__content" @class}}
          ...attributes
          {{this.scroller}}
        >
          {{yield this.strip}}
        </div>

        {{#if this.hasRightScroll}}
          <EdgeButton
            @edge="right"
            @class={{dConcatClass
              @buttonClass
              (get @edgeButtonClasses "right")
            }}
            @onClick={{this.scrollRight}}
            @hold={{this.hold}}
          />
        {{/if}}
        {{#if this.hasBottomScroll}}
          <EdgeButton
            @edge="down"
            @class={{dConcatClass @buttonClass (get @edgeButtonClasses "down")}}
            @onClick={{this.scrollDown}}
            @hold={{this.hold}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
