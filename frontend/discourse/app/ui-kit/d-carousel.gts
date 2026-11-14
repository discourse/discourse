import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { isDestroying } from "@ember/destroyable";
import { getOwner } from "@ember/owner";
import { schedule, throttle } from "@ember/runloop";
import curryComponent from "ember-curry-component";
import { modifier } from "ember-modifier";
import { isTesting } from "discourse/lib/environment";
import Controls from "discourse/ui-kit/d-carousel/-internals/parts/controls";
import Counter from "discourse/ui-kit/d-carousel/-internals/parts/counter";
import Dot from "discourse/ui-kit/d-carousel/-internals/parts/dot";
import Dots from "discourse/ui-kit/d-carousel/-internals/parts/dots";
import NavButton from "discourse/ui-kit/d-carousel/-internals/parts/nav-button";
import Slide from "discourse/ui-kit/d-carousel/-internals/parts/slide";
import Track from "discourse/ui-kit/d-carousel/-internals/parts/track";
import type {
  DCarouselBag,
  DCarouselEngine,
  DCarouselSignature,
  DCarouselSlideKey,
} from "discourse/ui-kit/d-carousel/types";

export type {
  DCarouselBag,
  DCarouselSignature,
  DCarouselSlideKey,
} from "discourse/ui-kit/d-carousel/types";

/** Past this many slides, one dot per slide stops being a usable control. */
const MAX_DOTS = 10;

/** A held arrow key would otherwise queue one scroll per key repeat. */
const KEYBOARD_THROTTLE_MS = isTesting() ? 0 : 150;

/** Settle delay standing in for `scrollend` where the browser lacks it. */
const SCROLL_SETTLE_MS = 150;

type ArrowKey = "ArrowLeft" | "ArrowRight";

/**
 * A horizontal, scroll-snapping slideshow of arbitrary content, with the
 * navigation composed from yielded parts. The component owns the active
 * slide, paging and wrap-around, arrow-key handling along the reading
 * direction, and the scroll tracking that keeps the active slide in step
 * with swipes. Consumers own the markup around it: what each slide holds,
 * which controls appear and where, and any attributes those parts carry.
 *
 * Slides are identified by a consumer-supplied key, and track order is read
 * from the DOM, so inserting, removing, or reordering slides never desyncs
 * the controls from the track.
 *
 * ```gjs
 * <DCarousel @label={{i18n "gallery.label"}} as |carousel|>
 *   <carousel.Track>
 *     {{#each @photos key="id" as |photo|}}
 *       <carousel.Slide @key={{photo.id}}>
 *         <img alt={{photo.alt}} src={{photo.url}} />
 *       </carousel.Slide>
 *     {{/each}}
 *   </carousel.Track>
 *   <carousel.Controls>
 *     <carousel.Previous @label={{i18n "carousel.previous"}} />
 *     <carousel.Dots>
 *       {{#each @photos key="id" as |photo index|}}
 *         <carousel.Dot @key={{photo.id}} @label={{this.dotLabel index}} />
 *       {{/each}}
 *     </carousel.Dots>
 *     <carousel.Counter />
 *     <carousel.Next @label={{i18n "carousel.next"}} />
 *   </carousel.Controls>
 * </DCarousel>
 * ```
 */
export default class DCarousel extends Component<DCarouselSignature> {
  /**
   * Joins a slide to the registry under its key. The tracked bump is
   * deferred because a modifier installs inside the render that already
   * read the registry; the cleanup checks identity because destructors run
   * deferred too, so a replaced slide's teardown must not evict its successor.
   */
  #registerSlide = modifier(
    (element: HTMLElement, [key]: [DCarouselSlideKey]) => {
      this.#slides.set(key, element);
      this.#deferTrackedWrite(() => {
        if (this.#slides.get(key) === element) {
          this._slidesVersion++;
        }
      });

      return () => {
        if (this.#slides.get(key) === element) {
          this.#slides.delete(key);
          this.#deferTrackedWrite(() => this._slidesVersion++);
        }
      };
    }
  );

  /**
   * Follows user scrolling so a swipe updates the active slide. The slide is
   * reconciled only once scrolling settles: the positions passed through
   * during a smooth scroll would otherwise flip it back and forth.
   */
  #registerTrack = modifier((element: HTMLElement) => {
    this.#trackDirection =
      getComputedStyle(element).direction === "rtl" ? -1 : 1;

    const reconcile = () => {
      const key = this.#nearestKey(element);
      if (key !== null && key !== this._currentKey) {
        this._currentKey = key;
      }
    };
    const supportsScrollEnd = "onscrollend" in window;
    let settleTimer: ReturnType<typeof setTimeout> | undefined;
    const onScroll = () => {
      if (!supportsScrollEnd) {
        clearTimeout(settleTimer);
        settleTimer = setTimeout(reconcile, SCROLL_SETTLE_MS);
      }
    };

    element.addEventListener("scroll", onScroll, { passive: true });
    if (supportsScrollEnd && !isTesting()) {
      element.addEventListener("scrollend", reconcile);
    }

    return () => {
      element.removeEventListener("scroll", onScroll);
      element.removeEventListener("scrollend", reconcile);
      clearTimeout(settleTimer);
    };
  });

  #slides = new Map<DCarouselSlideKey, HTMLElement>();
  #trackDirection = 1;

  #engine: DCarouselEngine = (() => {
    /* eslint-disable-next-line @typescript-eslint/no-this-alias */
    const self = this;

    return {
      get activeKey() {
        return self.#activeKey;
      },
      get activeIndex() {
        return self.#activeIndex;
      },
      get count() {
        return self.#count;
      },
      get label() {
        return self.args.label;
      },
      get pageable() {
        return self.#count > 1;
      },
      get fitsDots() {
        return self.#count <= MAX_DOTS;
      },
      get canGoPrevious() {
        return self.#loop ? self.#count > 1 : self.#activeIndex > 0;
      },
      get canGoNext() {
        return self.#loop
          ? self.#count > 1
          : self.#activeIndex < self.#count - 1;
      },
      scrollToKey: (key: DCarouselSlideKey) => this.#scrollToKey(key),
      previous: () => this.#step(-1),
      next: () => this.#step(1),
      onTrackKeyDown: (event: KeyboardEvent) => this.#onTrackKeyDown(event),
      registerSlide: this.#registerSlide,
      registerTrack: this.#registerTrack,
    };
  })();

  /** The key last navigated or scrolled to; resolved against the registry. */
  @tracked _currentKey: DCarouselSlideKey | null = null;

  /**
   * Bumped whenever the slide registry changes. The registry is a plain Map,
   * so a getter that reads it must consume this tag to recompute; the `void`
   * reads below are load-bearing, not dead statements.
   */
  @tracked _slidesVersion = 0;

  get #loop() {
    return this.args.loop ?? true;
  }

  get #count() {
    void this._slidesVersion;
    return this.#slides.size;
  }

  /**
   * Slide keys in track order. Read from the DOM rather than registration
   * order, so a slide inserted between two others, or a reordered one, pages
   * in its visible position.
   */
  get #orderedKeys(): DCarouselSlideKey[] {
    void this._slidesVersion;
    return [...this.#slides.entries()]
      .sort(([, a], [, b]) =>
        a.compareDocumentPosition(b) === Node.DOCUMENT_POSITION_FOLLOWING
          ? -1
          : 1
      )
      .map(([key]) => key);
  }

  get #activeKey(): DCarouselSlideKey | null {
    void this._slidesVersion;
    if (this._currentKey !== null && this.#slides.has(this._currentKey)) {
      return this._currentKey;
    }
    return this.#orderedKeys[0] ?? null;
  }

  get #activeIndex() {
    const key = this.#activeKey;
    return key === null ? -1 : this.#orderedKeys.indexOf(key);
  }

  /**
   * The yielded parts, curried once. Nothing here reads tracked state, so
   * the cache never invalidates and part identity survives re-renders; the
   * state getters read the engine lazily, at the consumer's render.
   */
  @cached
  get parts(): DCarouselBag {
    const owner = getOwner(this)!;
    const carousel = this.#engine;

    return {
      Track: curryComponent(
        Track,
        { carousel },
        owner
      ) as DCarouselBag["Track"],
      Slide: curryComponent(
        Slide,
        { carousel },
        owner
      ) as DCarouselBag["Slide"],
      Controls: curryComponent(
        Controls,
        { carousel },
        owner
      ) as DCarouselBag["Controls"],
      Previous: curryComponent(
        NavButton,
        { carousel, direction: "previous" as const },
        owner
      ) as DCarouselBag["Previous"],
      Next: curryComponent(
        NavButton,
        { carousel, direction: "next" as const },
        owner
      ) as DCarouselBag["Next"],
      Dots: curryComponent(Dots, { carousel }, owner) as DCarouselBag["Dots"],
      Dot: curryComponent(Dot, { carousel }, owner) as DCarouselBag["Dot"],
      Counter: curryComponent(
        Counter,
        { carousel },
        owner
      ) as DCarouselBag["Counter"],
      get activeKey() {
        return carousel.activeKey;
      },
      get activeIndex() {
        return carousel.activeIndex;
      },
      get count() {
        return carousel.count;
      },
      scrollToKey: (key: DCarouselSlideKey) => carousel.scrollToKey(key),
    };
  }

  #scrollToKey(key: DCarouselSlideKey) {
    const slide = this.#slides.get(key);
    if (!slide) {
      return;
    }

    this._currentKey = key;
    slide.scrollIntoView({
      behavior: prefersReducedMotion() ? "auto" : "smooth",
      block: "nearest",
      inline: "start",
    });
  }

  #step(delta: 1 | -1) {
    const keys = this.#orderedKeys;
    if (keys.length < 2) {
      return;
    }

    let target = this.#activeIndex + delta;
    if (target < 0 || target >= keys.length) {
      if (!this.#loop) {
        return;
      }
      target = (target + keys.length) % keys.length;
    }

    const key = keys[target];
    if (key !== undefined) {
      this.#scrollToKey(key);
    }
  }

  #onTrackKeyDown(event: KeyboardEvent) {
    const { key } = event;
    if (key !== "ArrowLeft" && key !== "ArrowRight") {
      return;
    }
    // Arrow keys inside editable content move the caret, not the carousel.
    if (isEditable(event.target)) {
      return;
    }

    event.preventDefault();
    throttle(this, this.#stepFromKey, key, KEYBOARD_THROTTLE_MS);
  }

  #stepFromKey(key: ArrowKey) {
    const forwards = (key === "ArrowRight") === (this.#trackDirection === 1);
    this.#step(forwards ? 1 : -1);
  }

  #nearestKey(track: HTMLElement): DCarouselSlideKey | null {
    const center = track.scrollLeft + track.clientWidth / 2;
    let best: DCarouselSlideKey | null = null;
    let min = Infinity;
    for (const [key, slide] of this.#slides) {
      const distance = Math.abs(
        slide.offsetLeft + slide.offsetWidth / 2 - center
      );
      if (distance < min) {
        min = distance;
        best = key;
      }
    }
    return best;
  }

  /**
   * Runs a tracked write after the current render transaction closes. The
   * callback re-checks its own precondition, because a teardown can land
   * between the schedule and the flush.
   */
  #deferTrackedWrite(write: () => void) {
    schedule("afterRender", () => {
      if (isDestroying(this)) {
        return;
      }

      write();
    });
  }

  <template>
    <div class="d-carousel" ...attributes>
      {{yield this.parts}}
    </div>
  </template>
}

function isEditable(target: EventTarget | null): boolean {
  return (
    target instanceof HTMLElement &&
    (target.isContentEditable ||
      /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName))
  );
}

function prefersReducedMotion(): boolean {
  return !!window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
}
