import type { ComponentLike, ModifierLike } from "@glint/template";

/** Identity of one slide, unique among the slides of the same carousel. */
export type DCarouselSlideKey = string | number;

/**
 * The live state and controls one `DCarousel` instance shares with its parts.
 *
 * Internal contract between the core and its `-internals` parts; consumers
 * never see it because the curried parts erase the `carousel` argument.
 */
export interface DCarouselEngine {
  /** The key of the slide in view, or `null` until a slide has registered. */
  readonly activeKey: DCarouselSlideKey | null;

  /** Position of the active slide in track order, or `-1` with no slides. */
  readonly activeIndex: number;

  /** Number of registered slides. */
  readonly count: number;

  /** The track's accessible name, when the consumer gave one. */
  readonly label: string | undefined;

  /** Whether there is more than one slide to page between. */
  readonly pageable: boolean;

  /** Whether the slide count is small enough for one dot per slide. */
  readonly fitsDots: boolean;

  /** Whether a step backwards has somewhere to go. */
  readonly canGoPrevious: boolean;

  /** Whether a step forwards has somewhere to go. */
  readonly canGoNext: boolean;

  /** Brings the slide with the given key into view and makes it active. */
  scrollToKey(key: DCarouselSlideKey): void;

  /** Steps to the slide before the active one, wrapping when looping. */
  previous(): void;

  /** Steps to the slide after the active one, wrapping when looping. */
  next(): void;

  /** Keydown handler for the track: arrow keys page in reading direction. */
  onTrackKeyDown(event: KeyboardEvent): void;

  /** Element modifier a slide applies to join the registry under its key. */
  registerSlide: ModifierLike<{
    Element: HTMLElement;
    Args: { Positional: [key: DCarouselSlideKey] };
  }>;

  /** Element modifier the track applies so user scrolling updates the active slide. */
  registerTrack: ModifierLike<{
    Element: HTMLElement;
    Args: { Positional: [] };
  }>;
}

/**
 * What the default block receives: the parts to compose and the live state.
 *
 * Typed as the consumer surface. The curried engine argument is omitted,
 * not optional, so a consumer cannot wire a part into another carousel.
 */
export interface DCarouselBag {
  /**
   * The scroll-snapping viewport. Place the slides inside it, as direct
   * children, in display order.
   */
  Track: ComponentLike<{
    Element: DCarouselTrackSignature["Element"];
    Blocks: DCarouselTrackSignature["Blocks"];
  }>;

  /** One slide. Its `@key` is what the dots and the state refer to. */
  Slide: ComponentLike<{
    Element: DCarouselSlideSignature["Element"];
    Args: Omit<DCarouselSlideSignature["Args"], "carousel">;
    Blocks: DCarouselSlideSignature["Blocks"];
  }>;

  /**
   * The row holding the navigation. It renders nothing while there is a
   * single slide, so a consumer never has to guard it.
   */
  Controls: ComponentLike<{
    Element: DCarouselControlsSignature["Element"];
    Blocks: DCarouselControlsSignature["Blocks"];
  }>;

  /** Steps one slide backwards. Disabled at the first slide unless looping. */
  Previous: ComponentLike<{
    Element: DCarouselNavSignature["Element"];
    Args: Omit<DCarouselNavSignature["Args"], "carousel" | "direction">;
  }>;

  /** Steps one slide forwards. Disabled at the last slide unless looping. */
  Next: ComponentLike<{
    Element: DCarouselNavSignature["Element"];
    Args: Omit<DCarouselNavSignature["Args"], "carousel" | "direction">;
  }>;

  /**
   * The row of dots. Place one `Dot` per slide inside it, in slide order.
   * It renders nothing once there are too many slides for dots to stay
   * usable; pair it with a `Counter` to cover that case.
   */
  Dots: ComponentLike<{
    Element: DCarouselDotsSignature["Element"];
    Blocks: DCarouselDotsSignature["Blocks"];
  }>;

  /** One dot: jumps to the slide with the same `@key`. */
  Dot: ComponentLike<{
    Element: DCarouselDotSignature["Element"];
    Args: Omit<DCarouselDotSignature["Args"], "carousel">;
  }>;

  /**
   * A "position / total" readout. It renders only when there are too many
   * slides for dots, so it can sit next to `Dots` unconditionally.
   */
  Counter: ComponentLike<{ Element: DCarouselCounterSignature["Element"] }>;

  /** The key of the slide in view, or `null` until a slide has registered. */
  readonly activeKey: DCarouselSlideKey | null;

  /** Position of the active slide in track order, or `-1` with no slides. */
  readonly activeIndex: number;

  /** Number of registered slides. */
  readonly count: number;

  /** Brings the slide with the given key into view and makes it active. */
  scrollToKey(key: DCarouselSlideKey): void;
}

export interface DCarouselSignature {
  /** The widget root: a column of the track and the controls placed below it. */
  Element: HTMLDivElement;
  Args: {
    /**
     * Whether stepping past either end wraps around to the other. Defaults
     * to `true`. When off, the step button at a reached end is disabled.
     */
    loop?: boolean;

    /**
     * The track's accessible name, already translated. Without it the track
     * is a focusable group with no announced name.
     */
    label?: string;
  };
  Blocks: {
    /**
     * The parts, composed in whatever arrangement the consumer wants: a
     * `Track` holding `Slide`s, and usually `Controls` holding `Previous`,
     * `Dots` or a `Counter`, and `Next`.
     */
    default: [carousel: DCarouselBag];
  };
}

/** The signature of the curried `Track` part. */
export interface DCarouselTrackSignature {
  /** The scrolling viewport; splattributes and modifiers land on it. */
  Element: HTMLDivElement;
  Args: {
    /** The engine of the owning carousel, curried by the core. */
    carousel: DCarouselEngine;
  };
  Blocks: {
    /** The slides, as direct children. */
    default: [];
  };
}

/** The signature of the curried `Slide` part. */
export interface DCarouselSlideSignature {
  /** The slide element; splattributes and modifiers land on it. */
  Element: HTMLDivElement;
  Args: {
    /** The engine of the owning carousel, curried by the core. */
    carousel: DCarouselEngine;

    /**
     * Stable identity for this slide, unique within the carousel. A `Dot`
     * with the same key jumps to it. Keep it stable across re-renders so a
     * slide inserted or removed elsewhere never shifts this one's identity.
     */
    key: DCarouselSlideKey;
  };
  Blocks: {
    /** The slide content. */
    default: [];
  };
}

/** The signature of the curried `Controls` part. */
export interface DCarouselControlsSignature {
  /** The controls row; splattributes land on it. */
  Element: HTMLDivElement;
  Args: {
    /** The engine of the owning carousel, curried by the core. */
    carousel: DCarouselEngine;
  };
  Blocks: {
    /** The navigation parts, in display order. */
    default: [];
  };
}

/** The signature of the curried `Previous` and `Next` parts. */
export interface DCarouselNavSignature {
  /** The real button; splattributes and modifiers land on it. */
  Element: HTMLButtonElement;
  Args: {
    /** The engine of the owning carousel, curried by the core. */
    carousel: DCarouselEngine;

    /** Which way the button steps, curried by the core. */
    direction: "previous" | "next";

    /** The button's accessible name, already translated. */
    label: string;
  };
}

/** The signature of the curried `Dots` part. */
export interface DCarouselDotsSignature {
  /** The dots row; splattributes land on it. */
  Element: HTMLDivElement;
  Args: {
    /** The engine of the owning carousel, curried by the core. */
    carousel: DCarouselEngine;
  };
  Blocks: {
    /** One `Dot` per slide, in slide order. */
    default: [];
  };
}

/** The signature of the curried `Dot` part. */
export interface DCarouselDotSignature {
  /** The real button; splattributes and modifiers land on it. */
  Element: HTMLButtonElement;
  Args: {
    /** The engine of the owning carousel, curried by the core. */
    carousel: DCarouselEngine;

    /** The key of the slide this dot jumps to. */
    key: DCarouselSlideKey;

    /** The button's accessible name, already translated. */
    label: string;
  };
}

/** The signature of the curried `Counter` part. */
export interface DCarouselCounterSignature {
  /** The readout element; splattributes land on it. */
  Element: HTMLSpanElement;
  Args: {
    /** The engine of the owning carousel, curried by the core. */
    carousel: DCarouselEngine;
  };
}
