import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { createTweenFunction } from "./animation";
import AnimationTravel from "./animation-travel";
import {
  placementToCssClass,
  resolveTracksAndPlacement,
} from "./config-normalizer";
import DetentManager from "./detent-manager";
import DimensionCalculator from "./dimensions-calculator";
import DOMAttributes from "./dom-attributes";
import FocusManagement from "./focus-management";
import InertManagement from "./inert-management";
import ObserverManager from "./observer-manager";
import ScrollProgressCalculator from "./scroll-progress-calculator";
import StackingAdapter from "./stacking-adapter";
import StateHelper from "./state-helper";
import StateMachine from "./state-machine";
import {
  ANIMATION_STATES,
  GUARDS,
  LONG_RUNNING_STATES,
  POSITION_STATES,
  SHEET_STATES,
} from "./states";
import ThemeColorAdapter from "./theme-color-adapter";
import TimeoutManager from "./timeout-manager";
import { TouchHandler } from "./touch-handler";

/**
 * Controller for d-sheet component managing lifecycle, animations, and user interactions.
 *
 * @class Controller
 */
export default class Controller {
  /**
   * Browser feature detection for scroll-snap and IntersectionObserver.
   *
   * @type {boolean}
   * @static
   */
  static get browserSupportsRequiredFeatures() {
    const supportsScrollSnap =
      typeof CSS !== "undefined" && CSS.supports("scroll-snap-align: start");

    const supportsIntersectionObserver =
      typeof window !== "undefined" &&
      "IntersectionObserver" in window &&
      "IntersectionObserverEntry" in window &&
      "intersectionRatio" in window.IntersectionObserverEntry.prototype;

    return supportsScrollSnap && supportsIntersectionObserver;
  }

  /** @type {HTMLElement|null} */
  @tracked view = null;

  /** @type {HTMLElement|null} */
  @tracked content = null;

  /** @type {HTMLElement|null} */
  @tracked contentWrapper = null;

  /** @type {HTMLElement|null} */
  @tracked scrollContainer = null;

  /** @type {HTMLElement|null} */
  @tracked backdrop = null;

  /** @type {boolean} */
  @tracked isPresented = false;

  /** @type {boolean} */
  @tracked safeToUnmount = true;

  /** @type {boolean} */
  @tracked inertOutside = true;

  /** @type {Array|null} */
  @tracked detentsConfig = null;

  /** @type {boolean} */
  @tracked swipeOvershoot = true;

  /** @type {boolean} */
  @tracked backdropSwipeable = true;

  /**
   * Whether scroll is currently ongoing.
   * @type {boolean}
   */
  @tracked isScrollOngoing = false;
  /** @type {TrackedArray<HTMLElement>} */
  detentMarkers = new TrackedArray();

  /** @type {string} */
  id = guidFor(this);

  /** @type {string} */
  role = "dialog";

  /** @type {string} */
  tracks = "bottom";

  /** @type {string} */
  contentPlacement = "bottom";

  /** @type {StateMachine} */
  stateMachine = new StateMachine(SHEET_STATES, SHEET_STATES.initial, {
    guards: GUARDS,
  });

  /** @type {StateMachine} */
  animationStateMachine = new StateMachine(
    ANIMATION_STATES,
    ANIMATION_STATES.initial,
    { guards: GUARDS }
  );

  /** @type {StateMachine} */
  positionMachine = new StateMachine(POSITION_STATES, POSITION_STATES.initial, {
    guards: GUARDS,
  });

  /** @type {StateMachine} */
  touchMachine = new StateMachine(
    {
      initial: "ended",
      states: {
        ended: { on: { TOUCH_START: "ongoing" } },
        ongoing: { on: { TOUCH_END: "ended" } },
      },
    },
    "ended",
    { guards: null }
  );

  /** @type {StateMachine} */
  longRunningMachine = new StateMachine(
    LONG_RUNNING_STATES,
    LONG_RUNNING_STATES.initial,
    { guards: null }
  );

  /** @type {Object|null} */
  dimensions = null;

  /** @type {number} */
  activeDetent = 0;

  /** @type {number} */
  targetDetent = 1;

  /** @type {Array<number>} */
  currentSegment = [0, 0];

  /** @type {boolean} */
  frontStuck = false;

  /** @type {boolean} */
  backStuck = false;

  /** @type {number} */
  travelProgress = 0;

  /** @type {string} */
  travelStatus = "idleOutside";

  /** @type {{start: number, end: number}} */
  travelRange = { start: 0, end: 0 };

  /** @type {string} */
  previousTravelStatus = "idleOutside";

  /** @type {number|null} */
  lastProcessedProgress = null;

  /** @type {number|null} */
  lastScrollTop = null;

  /**
   * Whether swipe is currently ongoing.
   * @type {boolean}
   */
  isSwipeOngoing = false;

  /**
   * Whether move is currently ongoing.
   * @type {boolean}
   */
  isMoveOngoing = false;

  /**
   * Progress smoother function like Silk's nB.
   * Initialized when sheet opens with expected detent progress.
   * Prevents large jumps in progress values (e.g., from expected value to spurious 0).
   * @type {Function|null}
   */
  progressSmoother = null;

  /** @type {Array<Object>} */
  travelAnimations = [];

  /** @type {Array<Object>} */
  stackingAnimations = [];

  /** @type {Array<Controller>} */
  belowSheetsInStack = [];

  /** @type {number} */
  stackingIndex = -1;

  /** @type {string|null} */
  stackId = null;

  /** @type {number} */
  myStackPosition = 0;

  /** @type {boolean} */
  viewHiddenByObserver = false;

  /** @type {boolean} */
  closingWithoutAnimation = false;

  /** @type {Object|null} */
  sheetStackRegistry = null;

  /** @type {Object|null} */
  sheetRegistry = null;

  /** @type {Object|null} */
  themeColorManager = null;

  /** @type {Set} */
  outlets = new Set();

  /** @type {Function|null} */
  onTravelStatusChange = null;

  /** @type {Function|null} */
  onTravelRangeChange = null;

  /** @type {Function|null} */
  onTravel = null;

  /** @type {Function|null} */
  onTravelStart = null;

  /** @type {Function|null} */
  onTravelEnd = null;

  /** @type {Function|null} */
  onActiveDetentChange = null;

  /** @type {Function|null} */
  onTravelProgressChange = null;

  /** @type {Function|null} */
  onSwipeFromEdgeToGoBackAttempt = null;

  /** @type {boolean} */
  swipe = true;

  /** @type {boolean} */
  swipeDismissal = true;

  /** @type {boolean|Object} */
  swipeTrap = true;

  /** @type {boolean} */
  nativeEdgeSwipePrevention = false;

  /** @type {boolean} */
  nativeFocusScrollPrevention = true;

  /** @type {boolean} */
  pageScroll = false;

  /** @type {string|Object|null} */
  enteringAnimationSettings = null;

  /** @type {string|Object|null} */
  exitingAnimationSettings = null;

  /** @type {string|Object|null} */
  steppingAnimationSettings = null;

  /** @type {string|number} */
  snapOutAcceleration = "auto";

  /** @type {string|number} */
  snapToEndDetentsAcceleration = "auto";

  /** @type {Object} */
  onClickOutside = {
    dismiss: true,
    stopOverlayPropagation: true,
  };

  /** @type {Object|Function} */
  onEscapeKeyDown = {
    nativePreventDefault: true,
    dismiss: true,
    stopOverlayPropagation: true,
  };

  /** @type {Object|Function} */
  onPresentAutoFocus = { focus: true };

  /** @type {Object|Function} */
  onDismissAutoFocus = { focus: true };

  /** @type {FocusManagement|null} */
  focusManagement = null;

  /** @type {InertManagement|null} */
  inertManagement = null;

  /**
   * state machines
   */
  #subscriptionDefinitions = [
    {
      machine: "stateMachine",
      state: "preparing-opening",
      handler: "handlePreparingOpening",
    },
    { machine: "stateMachine", state: "opening", handler: "handleOpening" },
    {
      machine: "stateMachine",
      state: "open",
      guard: () => {
        const msg = this.stateMachine.lastMessageTreated;
        return ["ANIMATION_COMPLETE", "PREPARED", "STEP"].includes(msg?.type);
      },
      callback: (message) => this.handleOpen(message),
    },
    { machine: "stateMachine", state: "closing", handler: "handleClosing" },
    {
      machine: "stateMachine",
      state: "closed.pending",
      handler: "handleClosedPending",
    },
    {
      machine: "stateMachine",
      state: "closed.safe-to-unmount",
      handler: "handleClosedSafeToUnmount",
    },
    {
      machine: "stateMachine",
      state: "closed.flushing-to-preparing-opening",
      timing: "before-paint",
      callback: () => {
        this.timeoutManager.clear("pendingFlush");
        this.stateHelper.flushComplete();
      },
    },
    {
      machine: "stateMachine",
      state: "closed.flushing-to-preparing-open",
      timing: "before-paint",
      callback: () => {
        this.timeoutManager.clear("pendingFlush");
        this.stateHelper.flushComplete();
      },
    },
    {
      machine: "stateMachine",
      state: "preparing-open",
      handler: "handlePreparingOpen",
    },
    {
      machine: "positionMachine",
      state: "covered-going-down",
      callback: () => this.stateHelper.goDown(),
    },
    {
      machine: "positionMachine",
      state: "covered-idle",
      callback: () => {
        if (
          this.stateHelper.isInAnimationState("going-down") ||
          this.stateHelper.isInAnimationState("go-down")
        ) {
          this.stateHelper.advanceAnimation();
        }
      },
    },
    {
      machine: "positionMachine",
      state: "covered-going-up",
      callback: () => this.stateHelper.goUp(),
    },
    {
      machine: "positionMachine",
      state: "covered-indeterminate",
      callback: () => {
        if (this.stateHelper.isInAnimationState("going-up")) {
          this.stateHelper.advanceAnimation();
        }

        const stackId = this.stackId;
        if (stackId && this.sheetStackRegistry) {
          const topmostSheet =
            this.sheetStackRegistry.getTopmostSheetInStack(stackId);
          if (topmostSheet === this) {
            this.stateHelper.goToFrontIdle();
          } else {
            this.stateHelper.goToCoveredIdle();
          }
        } else {
          this.stateHelper.goToFrontIdle();
        }
      },
    },
    {
      machine: "animationStateMachine",
      state: [
        "none",
        "opening",
        "open",
        "stepping",
        "closing",
        "going-down",
        "go-down",
        "going-up",
      ],
      handler: "updateAnimatingAttribute",
    },
    // Scroll state caching via refs (like Silk's n2.current)
    {
      machine: "stateMachine",
      state: "open.scroll.ongoing",
      guard: () => !this.isScrollOngoing,
      callback: () => {
        // eslint-disable-next-line no-console
        console.log("[state] ENTER open.scroll.ongoing");
        this.isScrollOngoing = true;
      },
    },
    {
      machine: "stateMachine",
      state: "open.scroll.ended",
      guard: () => this.isScrollOngoing,
      callback: () => {
        this.isScrollOngoing = false;
      },
    },
    {
      machine: "stateMachine",
      state: "open.scroll.ongoing",
      type: "exit",
      callback: () => {
        this.isScrollOngoing = false;
      },
    },
    // Swipe state caching via refs (like Silk's n4.current)
    {
      machine: "stateMachine",
      state: "open.swipe.ongoing",
      guard: () => !this.isSwipeOngoing,
      callback: () => {
        this.isSwipeOngoing = true;
      },
    },
    {
      machine: "stateMachine",
      state: "open.swipe.ended",
      guard: () => this.isSwipeOngoing,
      callback: () => {
        this.isSwipeOngoing = false;
      },
    },
    {
      machine: "stateMachine",
      state: "open.swipe.ongoing",
      type: "exit",
      callback: () => {
        this.isSwipeOngoing = false;
      },
    },
    // Move state caching via refs (like Silk's n3.current)
    {
      machine: "stateMachine",
      state: "open.move.ongoing",
      guard: () => !this.isMoveOngoing,
      callback: () => {
        this.isMoveOngoing = true;
      },
    },
    {
      machine: "stateMachine",
      state: "open.move.ended",
      guard: () => this.isMoveOngoing,
      callback: () => {
        this.isMoveOngoing = false;
      },
    },
    {
      machine: "stateMachine",
      state: "open.move.ongoing",
      type: "exit",
      callback: () => {
        this.isMoveOngoing = false;
      },
    },
  ];

  /**
   * Initialize the controller with helpers.
   * Use configure() to set options after construction.
   */
  constructor() {
    this.touchHandler = new TouchHandler(this);
    this.focusManagement = new FocusManagement(this);
    this.inertManagement = new InertManagement(this);
    this.timeoutManager = new TimeoutManager();
    this.detentManager = new DetentManager(this);
    this.domAttributes = new DOMAttributes(this);
    this.observerManager = new ObserverManager(this);
    this.scrollProgressCalculator = new ScrollProgressCalculator(this);
    this.stackingAdapter = new StackingAdapter(this);
    this.stateHelper = new StateHelper(this);
    this.animationTravel = new AnimationTravel(this);
    this.themeColorAdapter = new ThemeColorAdapter(this);
    this.setupSubscriptions();
  }

  /**
   * Configure options for the controller.
   * Called by Root after construction and by View when it mounts.
   *
   * @param {Object} options - Configuration options
   * @param {string} options.role - ARIA role for the sheet
   * @param {number} options.activeDetent - Active detent index
   * @param {number} options.defaultActiveDetent - Default active detent index
   * @param {string} options.contentPlacement - Placement of content
   * @param {string} options.tracks - Track content travels on
   * @param {Array<string>} options.detents - Detent values
   * @param {boolean} options.swipe - Enable swipe gestures
   * @param {boolean} options.swipeDismissal - Allow swipe to dismiss
   * @param {boolean} options.swipeOvershoot - Allow overshoot
   * @param {boolean|Object} options.swipeTrap - Trap swipes
   * @param {boolean} options.nativeEdgeSwipePrevention - Prevent edge swipe
   * @param {boolean} options.nativeFocusScrollPrevention - Prevent focus scroll
   * @param {boolean} options.pageScroll - Enable page scroll
   * @param {boolean} options.inertOutside - Inert outside content
   * @param {Object} options.onClickOutside - Click outside behavior
   * @param {Object|Function} options.onEscapeKeyDown - Escape key behavior
   * @param {Object|Function} options.onPresentAutoFocus - Auto-focus on present
   * @param {Object|Function} options.onDismissAutoFocus - Auto-focus on dismiss
   * @param {string|Object} options.enteringAnimationSettings - Enter animation
   * @param {string|Object} options.exitingAnimationSettings - Exit animation
   * @param {string|Object} options.steppingAnimationSettings - Step animation
   * @param {number|string} options.snapOutAcceleration - Snap out acceleration
   * @param {number|string} options.snapToEndDetentsAcceleration - Snap acceleration
   * @param {boolean|string} options.themeColorDimming - Theme color dimming
   * @param {number} options.themeColorDimmingAlpha - Dimming alpha
   * @param {Function} options.onTravelStatusChange - Travel status callback
   * @param {Function} options.onTravelRangeChange - Travel range callback
   * @param {Function} options.onTravel - Travel callback
   * @param {Function} options.onTravelStart - Travel start callback
   * @param {Function} options.onTravelEnd - Travel end callback
   * @param {Function} options.onActiveDetentChange - Active detent change callback
   * @param {Object} options.sheetStackRegistry - Sheet stack registry
   * @param {Object} options.sheetRegistry - Sheet registry
   * @param {Object} options.themeColorManager - Theme color manager
   */
  configure(options = {}) {
    this.#configureRole(options);
    this.#configureDetents(options);
    this.#configureTracksAndPlacement(options);
    this.#configureSwipe(options);
    this.#configureEventHandlers(options);
    this.#configureAnimation(options);
    this.#configureThemeColor(options);
    this.#configureCallbacks(options);
    this.#configureRegistries(options);
  }

  /**
   * Merge an event handler option with the current value.
   * Handles function values, object merging, and undefined.
   *
   * @param {Object} options - The options object
   * @param {string} key - The option key to merge
   * @param {Object|Function} currentValue - The current value
   * @returns {Object|Function} The merged value
   */
  #mergeEventHandler(options, key, currentValue) {
    const value = options[key];
    if (value === undefined) {
      return currentValue;
    }
    if (typeof value === "function") {
      return value;
    }
    return { ...currentValue, ...value };
  }

  /**
   * Assign option values to this instance if they are defined.
   *
   * @param {Object} options - The options object
   * @param {Array<string>} keys - The keys to assign
   */
  #assignIfDefined(options, keys) {
    for (const key of keys) {
      if (options[key] !== undefined) {
        this[key] = options[key];
      }
    }
  }

  /**
   * Configure the ARIA role.
   *
   * @param {Object} options - Configuration options
   */
  #configureRole(options) {
    if (options.role !== undefined) {
      this.role = options.role;
    }
  }

  /**
   * Configure detent-related options.
   *
   * @param {Object} options - Configuration options
   */
  #configureDetents(options) {
    if (options.activeDetent !== undefined) {
      this.targetDetent = options.activeDetent;
    } else if (options.defaultActiveDetent !== undefined) {
      this.targetDetent = options.defaultActiveDetent;
    }

    if ("detents" in options) {
      this.detentsConfig = options.detents;
    }
  }

  /**
   * Configure tracks and content placement.
   *
   * @param {Object} options - Configuration options
   */
  #configureTracksAndPlacement(options) {
    const result = resolveTracksAndPlacement(options, {
      tracks: this.tracks,
      contentPlacement: this.contentPlacement,
    });
    this.tracks = result.tracks;
    this.contentPlacement = result.contentPlacement;
  }

  /**
   * Configure swipe and scroll behavior options.
   *
   * @param {Object} options - Configuration options
   */
  #configureSwipe(options) {
    this.#assignIfDefined(options, [
      "swipe",
      "swipeDismissal",
      "swipeOvershoot",
      "swipeTrap",
      "nativeEdgeSwipePrevention",
      "onSwipeFromEdgeToGoBackAttempt",
      "nativeFocusScrollPrevention",
      "pageScroll",
      "inertOutside",
    ]);
  }

  /**
   * Configure event handler options with proper merging.
   *
   * @param {Object} options - Configuration options
   */
  #configureEventHandlers(options) {
    this.onClickOutside = this.#mergeEventHandler(
      options,
      "onClickOutside",
      this.onClickOutside
    );
    this.onEscapeKeyDown = this.#mergeEventHandler(
      options,
      "onEscapeKeyDown",
      this.onEscapeKeyDown
    );
    this.onPresentAutoFocus = this.#mergeEventHandler(
      options,
      "onPresentAutoFocus",
      this.onPresentAutoFocus
    );
    this.onDismissAutoFocus = this.#mergeEventHandler(
      options,
      "onDismissAutoFocus",
      this.onDismissAutoFocus
    );
  }

  /**
   * Configure animation settings.
   *
   * @param {Object} options - Configuration options
   */
  #configureAnimation(options) {
    this.#assignIfDefined(options, [
      "enteringAnimationSettings",
      "exitingAnimationSettings",
      "steppingAnimationSettings",
      "snapOutAcceleration",
      "snapToEndDetentsAcceleration",
    ]);
  }

  /**
   * Configure theme color settings.
   *
   * @param {Object} options - Configuration options
   */
  #configureThemeColor(options) {
    this.themeColorAdapter.configure(options);
  }

  /**
   * Configure travel and detent change callbacks.
   *
   * @param {Object} options - Configuration options
   */
  #configureCallbacks(options) {
    this.#assignIfDefined(options, [
      "onTravelStatusChange",
      "onTravelRangeChange",
      "onTravel",
      "onTravelStart",
      "onTravelEnd",
      "onActiveDetentChange",
    ]);
  }

  /**
   * Configure registry references.
   *
   * @param {Object} options - Configuration options
   */
  #configureRegistries(options) {
    this.#assignIfDefined(options, [
      "sheetStackRegistry",
      "sheetRegistry",
      "themeColorManager",
    ]);
  }

  /**
   * Set up state machine subscriptions for lifecycle management.
   */
  setupSubscriptions() {
    for (const def of this.#subscriptionDefinitions) {
      const machine = this[def.machine];
      machine.subscribe({
        timing: def.timing || "immediate",
        state: def.state,
        guard: def.guard,
        callback: def.callback || ((msg) => this[def.handler](msg)),
        type: def.type,
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Aggregated Animation Callbacks
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * Invoke all registered travel animation callbacks.
   * Uses index-based iteration for performance per Silk implementation.
   *
   * @param {number} progress - Travel progress value (0-1)
   * @param {Function} [tween] - Optional tween function for interpolation
   */
  aggregatedTravelCallback(progress, tween) {
    const animations = this.travelAnimations;
    for (let i = 0, len = animations.length; i < len; i++) {
      animations[i].callback(progress, tween);
    }
  }

  /**
   * Invoke all registered stacking animation callbacks.
   * Uses index-based iteration for performance per Silk implementation.
   *
   * @param {number} progress - Stacking progress value (0-1)
   * @param {Function} tween - Tween function for interpolation
   */
  aggregatedStackingCallback(progress, tween) {
    const animations = this.stackingAnimations;
    for (let i = 0, len = animations.length; i < len; i++) {
      animations[i].callback(progress, tween);
    }
  }

  /**
   * Update animating attribute on the view element.
   */
  updateAnimatingAttribute() {
    this.domAttributes.updateAnimatingAttribute(this.animationState);
  }

  /**
   * @type {boolean}
   */
  get isScrollTrapActive() {
    const trapValue = this.inertOutside ? true : this.swipeTrap;
    return trapValue !== false && trapValue !== null && trapValue !== "none";
  }

  /**
   * CSS class for the swipe trap based on configuration.
   *
   * @type {string|null}
   */
  get effectiveSwipeTrapClass() {
    const trapValue = this.inertOutside ? true : this.swipeTrap;

    if (!trapValue) {
      return null;
    }

    if (trapValue === true) {
      return "swipe-trap-both";
    }

    if (typeof trapValue === "object" && trapValue.x && trapValue.y) {
      return "swipe-trap-both";
    }

    return null;
  }

  /**
   * Whether the scroll container should allow pointer events to pass through.
   *
   * @type {boolean}
   */
  get scrollContainerShouldBePassThrough() {
    return !this.inertOutside && !this.backdropSwipeable;
  }

  /**
   * ID for the title element (accessibility).
   *
   * @type {string}
   */
  get titleId() {
    return `${this.id}-title`;
  }

  /**
   * ID for the description element (accessibility).
   *
   * @type {string}
   */
  get descriptionId() {
    return `${this.id}-description`;
  }

  /**
   * Get the effective detent configurations with implicit full-height appended.
   * When no detents are configured, returns a single full-height marker.
   *
   * @type {Array<string>}
   */
  get detents() {
    return this.detentManager.effectiveDetents;
  }

  /**
   * Set the detent configurations and recalculate if needed.
   *
   * @param {Array|null} value - New detent configurations
   */
  set detents(value) {
    const oldValue = this.detentsConfig;
    this.detentsConfig = value;

    if (oldValue !== value) {
      this.detentMarkers = new TrackedArray();

      if (this.view && this.content && this.scrollContainer) {
        this.recalculateDimensionsFromResize();
      }
    }
  }

  /**
   * Whether swipe-to-dismiss is disabled.
   * True when sheet has detents, dismissal is disabled, and sheet is open.
   *
   * @type {boolean}
   */
  get swipeOutDisabled() {
    if (this.swipe === false || !Controller.browserSupportsRequiredFeatures) {
      return false;
    }

    if (this.swipeDismissal && this.role !== "alertdialog") {
      return false;
    }

    if (this.detentsConfig === null || this.detentsConfig === undefined) {
      return false;
    }

    return (
      this.currentState === "open" &&
      !this.animationStateMachine.matches("closing")
    );
  }

  /**
   * Whether overshoot is disabled for edge-aligned sheets.
   *
   * @type {boolean}
   */
  get edgeAlignedNoOvershoot() {
    if (this.swipeOvershoot) {
      return false;
    }

    const isDismissalDisabled =
      this.role === "alertdialog" || !this.swipeDismissal;
    return !this.isCenteredTrack || isDismissalDisabled;
  }

  /**
   * Whether the sheet travels on a horizontal track.
   *
   * @type {boolean}
   */
  get isHorizontalTrack() {
    return (
      this.tracks === "left" ||
      this.tracks === "right" ||
      this.tracks === "horizontal"
    );
  }

  /**
   * Whether the sheet travels on a vertical track.
   *
   * @type {boolean}
   */
  get isVerticalTrack() {
    return (
      this.tracks === "top" ||
      this.tracks === "bottom" ||
      this.tracks === "vertical"
    );
  }

  /**
   * Whether the sheet uses a centered track (horizontal or vertical).
   *
   * @type {boolean}
   */
  get isCenteredTrack() {
    return this.tracks === "horizontal" || this.tracks === "vertical";
  }

  /**
   * Get the CSS class for content placement.
   *
   * @type {string}
   */
  get contentPlacementCssClass() {
    return placementToCssClass(this.contentPlacement);
  }

  /**
   * Update travel status and notify callback.
   *
   * @param {string} status - "idleOutside", "idleInside", "travellingIn", "travellingOut", "stepping"
   */
  updateTravelStatus(status) {
    if (this.travelStatus !== status) {
      this.travelStatus = status;
      this.safeToUnmount = status === "idleOutside";

      this.updateAnimationActiveAttribute(status);
      this.handleStackingStateChange(status);

      this.onTravelStatusChange?.(status);
    }
  }

  /**
   * Update the animation-active data attribute based on travel status.
   *
   * @param {string} status - Current travel status
   */
  updateAnimationActiveAttribute(status) {
    const isAnimating =
      status === "travellingIn" ||
      status === "travellingOut" ||
      status === "stepping";
    this.domAttributes.updateAnimationActive(isAnimating);
  }

  /**
   * Handle stacking state changes based on travel status.
   * Delegates to stacking adapter for bookkeeping.
   *
   * @param {string} status - Current travel status
   */
  handleStackingStateChange(status) {
    this.stackingAdapter.handleTravelStatusChange(
      status,
      this.previousTravelStatus
    );
  }

  /**
   * Update travel range and notify callback.
   *
   * @param {number} start - Start detent index
   * @param {number} end - End detent index
   */
  updateTravelRange(start, end) {
    if (this.travelRange.start !== start || this.travelRange.end !== end) {
      this.travelRange = { start, end };
      this.onTravelRangeChange?.(this.travelRange);
    }
  }

  /**
   * Notify onTravel callback with current progress.
   *
   * @param {number} progress - Travel progress value (0-1)
   */
  notifyTravel(progress) {
    this.onTravel?.({ progress });
  }

  /**
   * Get the current state from the main state machine.
   *
   * @type {string}
   */
  get currentState() {
    return this.stateMachine.current;
  }

  /**
   * Simplified openness state for data attributes.
   * Maps detailed state machine states to UI-friendly values.
   *
   * @type {string}
   */
  get openness() {
    const state = this.stateMachine.current;

    switch (state) {
      case "open":
        return "open";
      case "closing":
        return "closing";
      case "opening":
      case "preparing-opening":
      case "preparing-open":
        return "opening";
      default:
        return "closed";
    }
  }

  /**
   * Current animation state from the animation state machine.
   *
   * @type {string}
   */
  get animationState() {
    return this.animationStateMachine.current;
  }

  /**
   * Whether the sheet should be focusable.
   * Enabled when native focus scroll prevention is active.
   *
   * @type {boolean}
   */
  get isFocusable() {
    return this.nativeFocusScrollPrevention;
  }

  /**
   * Whether any animation is currently in progress.
   *
   * @type {boolean}
   */
  get isAnimating() {
    return this.animationState !== "none";
  }

  /**
   * Set the current travel segment and handle stuck position detection.
   *
   * @param {Array<number>} segment - Segment as [start, end] detent indices
   */
  @action
  setSegment(segment) {
    const prevSegment = this.currentSegment;
    this.currentSegment = segment;

    this.updateTravelRange(segment[0], segment[1]);

    if (this.swipeOutDisabled) {
      const { backStuck, frontStuck, shouldStep } =
        this.detentManager.determineStuckPosition(segment, prevSegment);

      if (backStuck) {
        this.backStuck = true;
        if (shouldStep === "back") {
          this.stepToStuckPosition("back");
        }
      } else if (frontStuck) {
        this.frontStuck = true;
        if (shouldStep === "front") {
          this.stepToStuckPosition("front");
        }
      } else {
        this.frontStuck = false;
        this.backStuck = false;
      }
    }

    if (segment[0] === segment[1]) {
      this.activeDetent = segment[0];

      if (this.onActiveDetentChange) {
        this.onActiveDetentChange(this.activeDetent);
      }
    }
  }

  /**
   * Handle a state transition message.
   *
   * @param {string|Object} message - State transition message
   */
  @action
  handleStateTransition(message) {
    this.stateMachine.send(message);
  }

  /**
   * Handle the preparing-opening state.
   * Sets up initial state and captures focus.
   *
   * @private
   */
  handlePreparingOpening() {
    this.isPresented = true;
    this.resetViewStyles();
    this.updateTravelStatus("travellingIn");
    this.focusManagement.capturePreviouslyFocusedElement();
  }

  /**
   * Handle the preparing-open state (opening without animation).
   *
   * @private
   */
  handlePreparingOpen() {
    this.isPresented = true;
    this.resetViewStyles();
    this.updateTravelStatus("idleInside");
    this.focusManagement.capturePreviouslyFocusedElement();
  }

  /**
   * Handle the opening state.
   * Begins enter animation and notifies parent sheet.
   *
   * @private
   */
  handleOpening() {
    this.longRunningMachine.send("TO_TRUE");
    this.stateHelper.beginEnterAnimation(false);
    this.stackingAdapter.notifyParentOfOpening(false);
  }

  /**
   * Handle the open state.
   * Sets up scroll behavior, focus, and intersection observer.
   *
   * @param {Object} message - State transition message
   */
  handleOpen(message) {
    // Mark longRunning as false when opening animation completes
    if (this.longRunningMachine.current === "true") {
      this.longRunningMachine.send("TO_FALSE");
    }

    // Initialize progress smoother with expected detent progress
    // Like Silk's nB initialization with progressValueAtDetents[segment[1]].exact
    const expectedProgress =
      this.dimensions?.progressValueAtDetents?.[this.activeDetent]?.exact ?? 0;
    this.progressSmoother = this.createProgressSmoother(expectedProgress);

    this.updateScrollSnapBehavior();
    this.updateTravelRange(this.activeDetent, this.activeDetent);
    this.updateTravelStatus("idleInside");
    this.applyInertOutside();
    this.setupFocusScrollPrevention();
    this.executeAutoFocusOnPresent();

    if (this.stateHelper.isInAnimationState("opening")) {
      this.stateHelper.advanceAnimation();
    }

    this.#setupIntersectionObserver();

    if (message?.type === "STEP") {
      this.handleStepMessage(message);
    }
  }

  /**
   * Set up intersection observer if swipe-out is enabled.
   * Deferred to next frame to ensure DOM is ready.
   */
  #setupIntersectionObserver() {
    if (this.swipeOutDisabled) {
      return;
    }

    requestAnimationFrame(() => {
      if (this.currentState === "open" && !this.swipeOutDisabled) {
        this.setupIntersectionObserver();
      }
    });
  }

  /**
   * Handle a STEP message to animate to a new detent.
   *
   * @param {Object} message - Message with optional detent property
   * @private
   */
  handleStepMessage(message) {
    this.stateHelper.stepAnimation();
    this.updateTravelStatus("stepping");

    if (message.detent !== undefined) {
      this.animationTravel.animateToDetent(message.detent);
    } else {
      const nextDetent = this.activeDetent + 1;
      this.animationTravel.animateToDetent(nextDetent);
    }
  }

  /**
   * Handle the closing state.
   * Begins exit animation or handles immediate close.
   *
   * @private
   */
  handleClosing() {
    this.isScrollOngoing = false;

    this.stateHelper.beginExitAnimation(false);
    this.updateTravelStatus("travellingOut");
    this.stackingAdapter.notifyParentOfClosing();

    if (this.closingWithoutAnimation) {
      this.handleClosingWithoutAnimation();
      return;
    }

    this.domAttributes.disableScrollSnap();
    this.animationTravel.animateToDetent(
      0,
      this.animationTravel.exitingAnimationDefaults
    );
  }

  /**
   * Handle closing without animation (immediate close).
   *
   * @private
   */
  handleClosingWithoutAnimation() {
    this.closingWithoutAnimation = false;

    const tween = createTweenFunction(0);
    this.belowSheetsInStack.forEach((belowSheet) => {
      belowSheet.aggregatedStackingCallback(0, tween);
    });

    requestAnimationFrame(() => {
      this.handleStateTransition({ type: "ANIMATION_COMPLETE" });
    });
  }

  /**
   * Handle the closed.pending state.
   * Handles immediate close if needed, then schedules flush to safe-to-unmount.
   */
  handleClosedPending() {
    this.longRunningMachine.send("TO_FALSE");
    this.#handleImmediateCloseIfNeeded();
    this.#scheduleFlushToSafeToUnmount();
  }

  /**
   * Handle immediate close (swipe-out) without animation.
   */
  #handleImmediateCloseIfNeeded() {
    if (!this.closingWithoutAnimation) {
      return;
    }

    this.stateHelper.beginImmediateClose(true);
    this.updateTravelStatus("travellingOut");
    this.closingWithoutAnimation = false;
    this.stateHelper.goOut();
    this.stackingAdapter.notifyParentOfClosingImmediate();

    const tween = createTweenFunction(0);
    this.stackingAdapter.notifyBelowSheets(0, tween);
  }

  /**
   * Schedule the flush to safe-to-unmount state.
   */
  #scheduleFlushToSafeToUnmount() {
    this.timeoutManager.schedule(
      "pendingFlush",
      () => {
        if (this.stateHelper.isClosedPending()) {
          this.stateHelper.flushComplete();
        }
      },
      16
    );
  }

  /**
   * Handle the closed.safe-to-unmount state.
   * Performs final cleanup and resets all state to initial values.
   */
  handleClosedSafeToUnmount() {
    // Reset presentation flags
    this.isPresented = false;
    this.needsInitialScroll = true;
    this.viewHiddenByObserver = false;
    this.frontStuck = false;
    this.backStuck = false;
    this.isScrollOngoing = false;

    // Perform cleanup and restore focus
    this.cleanup();
    this.executeAutoFocusOnDismiss();

    // Reset travel state
    this.activeDetent = 0;
    this.currentSegment = [0, 0];
    this.dimensions = null;
    this.lastProcessedProgress = null;
    this.lastScrollTop = null;

    // Advance position machine if needed
    if (
      this.stateHelper.position !== "out" &&
      this.stateHelper.isPositionFrontClosing()
    ) {
      this.stateHelper.advancePosition();
    }

    // Notify travel status change
    this.updateTravelStatus("idleOutside");
    this.updateTravelRange(0, 0);
  }

  /**
   * Calculate dimensions if all required elements are ready.
   * Triggers dimension calculation and initial animation.
   */
  calculateDimensionsIfReady() {
    const isPreparingOpening = this.currentState === "preparing-opening";
    const isPreparingOpen = this.currentState === "preparing-open";
    const hasRequiredMarkers =
      this.detentsConfig === undefined || this.detentMarkers.length > 0;

    if (
      (isPreparingOpening || isPreparingOpen) &&
      this.view &&
      this.content &&
      this.scrollContainer &&
      hasRequiredMarkers &&
      !this.dimensions
    ) {
      const calculator = new DimensionCalculator({
        view: this.view,
        content: this.content,
        scrollContainer: this.scrollContainer,
        detentMarkers: this.detentMarkers,
      });

      this.dimensions = calculator.calculateDimensions(
        this.tracks,
        this.contentPlacement,
        {
          swipeOutDisabled: this.swipeOutDisabled,
          snapOutAcceleration: this.snapOutAcceleration,
          snapToEndDetentsAcceleration: this.snapToEndDetentsAcceleration,
          edgeAlignedNoOvershoot: this.edgeAlignedNoOvershoot,
        }
      );

      this.setInitialScrollPosition();

      if (isPreparingOpen) {
        requestAnimationFrame(() => {
          this.handleStateTransition({ type: "PREPARED" });
          this.setScrollPositionToDetent(this.targetDetent);
        });
      } else {
        this.domAttributes.setHidden();

        requestAnimationFrame(() => {
          this.handleStateTransition({ type: "PREPARED" });
          this.animationTravel.animateToDetent(this.targetDetent);
        });
      }
    }
  }

  /**
   * Set the initial scroll position based on track direction.
   */
  setInitialScrollPosition() {
    if (!this.scrollContainer || !this.dimensions) {
      return;
    }

    const isHorizontal = this.isHorizontalTrack;

    if (this.tracks === "bottom" || this.tracks === "right") {
      if (isHorizontal) {
        this.scrollContainer.scrollLeft = 0;
      } else {
        this.scrollContainer.scrollTop = 0;
      }
    } else {
      if (isHorizontal) {
        this.scrollContainer.scrollLeft = this.scrollContainer.scrollWidth;
      } else {
        this.scrollContainer.scrollTop = this.scrollContainer.scrollHeight;
      }
    }
  }

  /**
   * Set scroll position to a specific detent.
   *
   * @param {number} detentIndex - Target detent index
   */
  setScrollPositionToDetent(detentIndex) {
    if (!this.scrollContainer || !this.dimensions) {
      return;
    }

    const progressAtDetent =
      this.dimensions.progressValueAtDetents?.[detentIndex];
    if (progressAtDetent === undefined) {
      return;
    }

    const scrollDistance =
      progressAtDetent * this.dimensions.travelAxisContentSize;
    const isHorizontal = this.isHorizontalTrack;

    if (isHorizontal) {
      this.scrollContainer.scrollLeft = scrollDistance;
    } else {
      this.scrollContainer.scrollTop = scrollDistance;
    }

    this.activeDetent = detentIndex;
    this.currentSegment = [detentIndex, detentIndex];
    this.travelProgress = progressAtDetent;
  }

  /**
   * Set up the intersection observer for swipe-out detection.
   */
  setupIntersectionObserver() {
    this.observerManager.setupIntersectionObserver();
  }

  /**
   * Clean up the intersection observer.
   */
  cleanupIntersectionObserver() {
    this.observerManager.cleanupIntersectionObserver();
  }

  /**
   * Register the view element and initialize observers.
   *
   * @param {HTMLElement} view - The view element
   */
  @action
  registerView(view) {
    this.view = view;
    this.resetViewStyles();
    this.calculateDimensionsIfReady();
    this.setupResizeObserver();
    this.sheetRegistry?.recalculateInertOutside();
  }

  /**
   * Set up ResizeObserver to watch view and content elements.
   */
  setupResizeObserver() {
    this.observerManager.setupResizeObserver(() => {
      if (
        this.view &&
        this.content &&
        this.scrollContainer &&
        this.dimensions
      ) {
        this.recalculateDimensionsFromResize();
      }
    });
  }

  /**
   * Recalculate dimensions triggered by ResizeObserver.
   */
  recalculateDimensionsFromResize() {
    // eslint-disable-next-line no-console
    console.log("[recalculateDimensionsFromResize] called");

    const calculator = new DimensionCalculator({
      view: this.view,
      content: this.content,
      scrollContainer: this.scrollContainer,
      detentMarkers: this.detentMarkers,
    });

    this.dimensions = calculator.calculateDimensions(
      this.tracks,
      this.contentPlacement,
      {
        swipeOutDisabled: this.swipeOutDisabled,
        edgeAlignedNoOvershoot: this.edgeAlignedNoOvershoot,
        snapOutAcceleration: this.snapOutAcceleration,
        snapToEndDetentsAcceleration: this.snapToEndDetentsAcceleration,
      }
    );

    if (this.currentState === "open") {
      if (!this.swipeOutDisabled) {
        this.setupIntersectionObserver();
      } else {
        this.cleanupIntersectionObserver();
      }
    }

    if (this.activeDetent > 0 && this.currentState === "open") {
      this.animationTravel.recalculateAndTravel(this.activeDetent);
    }
  }

  /**
   * Full cleanup of all resources.
   * Idempotent and safe to call multiple times.
   * Called when sheet transitions to safe-to-unmount state.
   */
  cleanup() {
    this.timeoutManager.cleanup();

    this.touchHandler.detach();
    this.observerManager.cleanup();
    this.themeColorAdapter.cleanup();
    this.domAttributes.cleanup();
    this.inertManagement.cleanup();
    this.focusManagement.cleanup();
    this.stateMachine.cleanup();
    this.animationStateMachine.cleanup();
    this.positionMachine.cleanup();
    this.touchMachine.cleanup();
    this.longRunningMachine.cleanup();
  }

  /**
   * Find the element to auto-focus on present.
   *
   * @returns {HTMLElement|null} The element to focus, or null if none found
   */
  findAutoFocusTarget() {
    return this.focusManagement.findAutoFocusTarget() ?? null;
  }

  /**
   * Execute auto-focus when the sheet is presented.
   */
  executeAutoFocusOnPresent() {
    this.focusManagement.executeAutoFocusOnPresent();
  }

  /**
   * Execute auto-focus when the sheet is dismissed.
   */
  executeAutoFocusOnDismiss() {
    this.focusManagement.executeAutoFocusOnDismiss();
  }

  /**
   * Set up focus scroll prevention.
   */
  setupFocusScrollPrevention() {
    this.focusManagement.setupFocusScrollPrevention();
  }

  /**
   * Apply inert attribute to elements outside the sheet.
   */
  applyInertOutside() {
    this.inertManagement.applyInertOutside();
    this.sheetRegistry?.updateInertOutside(this, this.inertOutside);
  }

  /**
   * Remove inert attribute from elements outside the sheet.
   */
  removeInertOutside() {
    this.inertManagement.removeInertOutside();
    this.sheetRegistry?.updateInertOutside(this, false);
  }

  /**
   * Handle touch on edge-marker element.
   *
   * @param {TouchEvent} event
   */
  @action
  handleEdgeMarkerTouch(event) {
    if (!this.onSwipeFromEdgeToGoBackAttempt) {
      return;
    }

    const touch = event.touches?.[0];
    if (touch && touch.clientX <= 28) {
      this.onSwipeFromEdgeToGoBackAttempt({
        nativeEvent: event,
        clientX: touch.clientX,
        clientY: touch.clientY,
      });
    }
  }

  /**
   * Register the content element.
   *
   * @param {HTMLElement} content - The content element
   */
  @action
  registerContent(content) {
    this.content = content;
    this.themeColorAdapter.captureContentThemeColor();
    this.calculateDimensionsIfReady();
  }

  /**
   * Register the content wrapper element.
   *
   * @param {HTMLElement} contentWrapper - The content wrapper element
   */
  @action
  registerContentWrapper(contentWrapper) {
    this.contentWrapper = contentWrapper;
  }

  /**
   * Register the scroll container element.
   *
   * @param {HTMLElement} scrollContainer - The scroll container element
   */
  @action
  registerScrollContainer(scrollContainer) {
    this.scrollContainer = scrollContainer;

    if (this.tracks === "bottom") {
      this.needsInitialScroll = true;
    }

    this.calculateDimensionsIfReady();
  }

  /**
   * Update scroll-snap behavior based on current state.
   *
   * @private
   */
  updateScrollSnapBehavior() {
    if (!this.scrollContainer || !this.dimensions || !this.content) {
      return;
    }

    this.domAttributes.enableScrollSnap();
  }

  /**
   * Handle scroll events by sending state machine messages.
   */
  @action
  handleScrollEvent() {
    const currentScrollTop = this.scrollContainer?.scrollTop;
    const scrollTopChanged = this.lastScrollTop !== currentScrollTop;
    if (currentScrollTop !== undefined) {
      this.lastScrollTop = currentScrollTop;
    }

    if (this.currentState !== "open") {
      return;
    }

    if (!this.scrollContainer || !this.dimensions) {
      return;
    }

    if (!scrollTopChanged) {
      return;
    }

    if (!this.isScrollOngoing) {
      this.stateHelper.scrollStart();
    }

    if (!this.frontStuck && !this.backStuck) {
      if (!this.isSwipeOngoing) {
        this.stateHelper.swipeStart();
      }
      if (!this.isMoveOngoing) {
        this.stateHelper.moveStart();
      }
    }

    this.timeoutManager.schedule(
      "scrollEnd",
      () => {
        this.#handleScrollEnd();
      },
      200
    );

    this.processScrollProgress();
  }

  /**
   * Handle scroll end - send end messages for scroll/swipe/move.
   */
  #handleScrollEnd() {
    this.stateHelper.moveEnd();

    const progress = this.scrollProgressCalculator.calculateProgress();
    const detents = this.dimensions?.progressValueAtDetents;

    if (progress && detents) {
      for (const detent of detents) {
        const matches =
          progress.clampedProgress > detent.exact - 0.01 &&
          progress.clampedProgress < detent.exact + 0.01;

        if (matches) {
          this.stateHelper.scrollEnd();
          this.stateHelper.swipeEnd();
          break;
        }
      }
    }
  }

  /**
   * Create a progress smoother function which prevents large jumps in progress values.
   *
   * @param {number} initialProgress - The initial/expected progress value
   * @returns {Function} A smoother function that takes raw progress and returns smoothed progress
   */
  createProgressSmoother(initialProgress) {
    let lastValue = initialProgress;
    let lastDelta = 0;

    return (newProgress) => {
      let result = newProgress;
      const delta = lastValue - newProgress;

      if (
        (delta === 0 || Math.abs(delta) < Math.abs(lastDelta / 2)) &&
        this.stateHelper.isTouchOngoing()
      ) {
        result = lastValue - lastDelta / 2;
      }

      if (Math.abs(delta) >= 0.1 && Math.abs(delta) < 0.35) {
        result = delta >= 0 ? lastValue - 0.1 : lastValue + 0.1;
      }

      if (newProgress <= 0) {
        result = 0;
      }

      lastValue = result;
      lastDelta = lastValue - newProgress;
      return result;
    };
  }

  /**
   * Process scroll progress and update callbacks.
   */
  processScrollProgress() {
    const progress = this.scrollProgressCalculator.calculateProgress();
    if (!progress) {
      return;
    }

    const { rawProgress, clampedProgress, stackingProgress, segmentProgress } =
      progress;

    const smoothedProgress = this.progressSmoother
      ? this.progressSmoother(clampedProgress)
      : clampedProgress;

    if (this.scrollProgressCalculator.shouldTriggerSwipeOut(rawProgress)) {
      this.domAttributes.disableScrollSnap();
      this.closingWithoutAnimation = true;
      requestAnimationFrame(() => {
        this.handleStateTransition("SWIPE_OUT");
      });
      return;
    }

    if (this.lastProcessedProgress === smoothedProgress) {
      return;
    }

    this.lastProcessedProgress = smoothedProgress;

    this.aggregatedTravelCallback(smoothedProgress);

    this.travelProgress = stackingProgress;
    this.onTravelProgressChange?.(stackingProgress);

    const tween = createTweenFunction(stackingProgress);
    this.belowSheetsInStack.forEach((belowSheet) => {
      belowSheet.aggregatedStackingCallback(stackingProgress, tween);
    });

    this.notifyTravel(smoothedProgress);

    const segment =
      this.scrollProgressCalculator.determineSegment(segmentProgress);
    if (segment) {
      this.setSegment(segment);
      if (segment[0] === 0 && segment[1] === 0 && segmentProgress <= 0) {
        return;
      }
    }

    if (this.scrollProgressCalculator.shouldTriggerSwipeOut(rawProgress)) {
      this.domAttributes.disableScrollSnap();
      this.closingWithoutAnimation = true;
      requestAnimationFrame(() => {
        this.handleStateTransition("SWIPE_OUT");
      });
    }
  }

  /**
   * Handle touchstart events on scroll-container.
   */
  @action
  handleTouchStart() {
    this.stateHelper.touchStart();
    this.touchHandler.handleScrollStart();
  }

  /**
   * Handle touchend events on scroll-container.
   */
  @action
  handleTouchEnd() {
    this.stateHelper.touchEnd();
    this.touchHandler.handleScrollEnd();
  }

  /**
   * Handle focus events on scroll-container.
   *
   * @param {FocusEvent} event
   */
  @action
  handleFocus(event) {
    if (!this.scrollContainer || !this.scrollContainer.contains(event.target)) {
      return;
    }

    if (this.onFocusInside) {
      this.onFocusInside({
        nativeEvent: event,
      });
    }
  }

  /**
   * Handle touch gesture start.
   * Called by TouchHandler when a swipe gesture begins.
   */
  onTouchGestureStart() {
    this.stateHelper.swipeStart();
  }

  /**
   * Handle touch gesture end.
   * Called by TouchHandler when a swipe gesture ends.
   * May trigger step to stuck position if needed.
   */
  onTouchGestureEnd() {
    this.stateHelper.swipeEnd();

    if (
      this.edgeAlignedNoOvershoot &&
      this.snapToEndDetentsAcceleration === "auto" &&
      this.currentState === "open" &&
      this.stateHelper.isScrollEnded()
    ) {
      this.timeoutManager.schedule(
        "stuckPosition",
        () => {
          requestAnimationFrame(() => {
            if (this.currentState === "open") {
              if (this.backStuck) {
                this.stepToStuckPosition("back");
              } else if (this.frontStuck) {
                this.stepToStuckPosition("front");
              }
            }
          });
        },
        80
      );
    }
  }

  /**
   * Auto-step to a stuck position without animation.
   *
   * @param {string} direction - "front" (last detent) or "back" (first detent)
   */
  stepToStuckPosition(direction) {
    this.frontStuck = false;
    this.backStuck = false;

    this.stateHelper.moveStart();
    this.updateTravelStatus("travellingIn");

    this.animationTravel.stepToStuckPosition(direction, () => {
      this.stateHelper.moveEnd();
      this.updateTravelStatus("idleInside");
    });
  }

  /**
   * Register a detent marker element.
   *
   * @param {HTMLElement} detentMarker - The detent marker element
   */
  @action
  registerDetentMarker(detentMarker) {
    this.detentMarkers.push(detentMarker);
    this.calculateDimensionsIfReady();
  }

  /**
   * Register backdrop element with optional custom travel animation.
   * Note: Travel animations are now handled by Outlet component via outlet-animation-modifier.
   * This method only handles element registration, swipeable state, and theme color dimming.
   *
   * @param {HTMLElement} backdrop
   * @param {Object} travelAnimation - Travel animation config (used for theme color dimming)
   * @param {boolean} swipeable - Whether backdrop responds to swipe/click
   */
  @action
  registerBackdrop(backdrop, travelAnimation = null, swipeable = true) {
    this.backdrop = backdrop;
    this.backdropSwipeable = swipeable;
    backdrop.style.opacity = 0;
    backdrop.style.willChange = "opacity";

    const isDisabled =
      travelAnimation &&
      typeof travelAnimation === "object" &&
      travelAnimation.opacity === null;

    if (!isDisabled && this.themeColorAdapter.effectiveThemeColorDimming) {
      const opacityFn =
        typeof travelAnimation === "function"
          ? travelAnimation
          : typeof travelAnimation?.opacity === "function"
            ? travelAnimation.opacity
            : ({ progress }) => Math.min(progress * 0.33, 0.33);

      const computedStyle = window.getComputedStyle(backdrop);
      const backgroundColor = computedStyle.backgroundColor || "rgb(0, 0, 0)";

      const themeColorDimmingOverlay =
        this.themeColorAdapter.registerThemeColorDimmingOverlay({
          color: backgroundColor,
          alpha: 0,
        });

      this.travelAnimations.push({
        target: backdrop,
        isThemeColorDimming: true,
        callback: (progress) => {
          const opacity = opacityFn({ progress });
          if (themeColorDimmingOverlay) {
            themeColorDimmingOverlay.updateAlpha(opacity);
          }
        },
      });
    }
  }

  /**
   * Register a stacking animation callback.
   *
   * @param {Object} animation - Animation config with callback
   * @param {Function} animation.callback - Called with (progress, tween) during travel
   * @param {HTMLElement} animation.target - Target element for the animation
   * @returns {Function} Unregister function
   */
  @action
  registerStackingAnimation(animation) {
    this.stackingAnimations.push(animation);

    return () => {
      const index = this.stackingAnimations.indexOf(animation);
      if (index !== -1) {
        this.stackingAnimations.splice(index, 1);
      }
    };
  }

  /**
   * Register a travel animation callback.
   *
   * @param {Object} animation - Animation config with callback
   * @param {Function} animation.callback - Called with (progress) during travel
   * @param {HTMLElement} animation.target - Target element for the animation
   * @param {Object} animation.config - Animation configuration object
   * @returns {Function} Unregister function
   */
  @action
  registerTravelAnimation(animation) {
    this.travelAnimations.push(animation);

    return () => {
      const index = this.travelAnimations.indexOf(animation);
      if (index !== -1) {
        this.travelAnimations.splice(index, 1);
      }
    };
  }

  /**
   * Open the sheet.
   */
  @action
  open() {
    this.handleStateTransition({ type: "OPEN" });
  }

  /**
   * Close the sheet.
   */
  @action
  close() {
    this.handleStateTransition({ type: "CLOSE" });
  }

  /**
   * Send a message to the position machine.
   *
   * @param {string|Object} message - Message to send
   * @param {Object} context - Context for guards
   * @returns {boolean} Whether a transition occurred
   */
  sendToPositionMachine(message, context = {}) {
    return this.positionMachine.send(message, context);
  }

  /**
   * Notify parent sheet's position machine when this sheet's position machine transitions via NEXT.
   *
   * @private
   */
  notifyParentPositionMachineNext() {
    this.stackingAdapter.notifyParentPositionMachineNext();
  }

  /**
   * Step to the next detent (upward direction).
   * Cycles back to first detent when at the last.
   */
  @action
  step() {
    if (this.currentState !== "open") {
      return;
    }

    const nextDetent = this.detentManager.calculateNextDetent();
    if (nextDetent !== null) {
      this.handleStateTransition({ type: "STEP", detent: nextDetent });
    }
  }

  /**
   * Step to the previous detent (downward direction).
   * Cycles to last detent when at the first.
   */
  @action
  stepDown() {
    if (this.currentState !== "open") {
      return;
    }

    const prevDetent = this.detentManager.calculatePrevDetent();
    if (prevDetent !== null) {
      this.handleStateTransition({ type: "STEP", detent: prevDetent });
    }
  }

  /**
   * Step to a specific detent index.
   *
   * @param {number} detent - Target detent index (1-based)
   */
  @action
  stepToDetent(detent) {
    if (this.currentState !== "open") {
      return;
    }

    if (this.detentManager.isValidDetent(detent)) {
      this.handleStateTransition({ type: "STEP", detent });
    }
  }

  /**
   * Reset view styles to default state.
   */
  resetViewStyles() {
    this.domAttributes.resetViewStyles();
    this.viewHiddenByObserver = false;
  }

  /**
   * Updates the scroll lock state via the sheet registry.
   *
   * @param {boolean} shouldLock - Whether to lock scrolling
   */
  updateScrollLock(shouldLock) {
    this.sheetRegistry?.updateScrollLock(this, shouldLock);
  }
}
