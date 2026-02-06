import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { next } from "@ember/runloop";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { capabilities } from "discourse/services/capabilities";
import AnimationTravel from "./animation-travel";
import {
  placementToCssClass,
  resolveTracksAndPlacement,
} from "./config-normalizer";
import DetentManager from "./detent-manager";
import DimensionCalculator from "./dimensions-calculator";
import DOMAttributes from "./dom-attributes";
import FocusManagement from "./focus-management";
import ObserverManager from "./observer-manager";
import ScrollProgressCalculator from "./scroll-progress-calculator";
import StackingAdapter from "./stacking-adapter";
import StateHelper from "./state-helper";
import ThemeColorAdapter from "./theme-color-adapter";
import TimeoutManager from "./timeout-manager";
import { TouchHandler } from "./touch-handler";

/**
 * Browser feature detection for scroll-snap and IntersectionObserver.
 * @type {boolean}
 */
const BROWSER_SUPPORTS_REQUIRED_FEATURES = (() => {
  const supportsScrollSnap =
    typeof CSS !== "undefined" && CSS.supports("scroll-snap-align: start");

  const supportsIntersectionObserver =
    typeof window !== "undefined" &&
    "IntersectionObserver" in window &&
    "IntersectionObserverEntry" in window &&
    "intersectionRatio" in window.IntersectionObserverEntry.prototype;

  return supportsScrollSnap && supportsIntersectionObserver;
})();

/**
 * Controller for d-sheet component managing lifecycle, animations, and user interactions.
 */
export default class Controller {
  /**
   * Default configurations for event handler behaviors.
   *
   * @type {{ onClickOutside: { dismiss: boolean, stopOverlayPropagation: boolean }, onEscapeKeyDown: { nativePreventDefault: boolean, dismiss: boolean, stopOverlayPropagation: boolean }, onPresentAutoFocus: { focus: boolean }, onDismissAutoFocus: { focus: boolean } }}
   */
  static EVENT_HANDLER_DEFAULTS = {
    onClickOutside: {
      dismiss: true,
      stopOverlayPropagation: true,
    },
    onEscapeKeyDown: {
      nativePreventDefault: true,
      dismiss: true,
      stopOverlayPropagation: true,
    },
    onPresentAutoFocus: { focus: true },
    onDismissAutoFocus: { focus: true },
  };

  /**
   * Browser feature detection for scroll-snap and IntersectionObserver.
   * Returns cached result from module-level constant.
   *
   * @returns {boolean} Whether required features are supported
   * @static
   */
  static get browserSupportsRequiredFeatures() {
    return BROWSER_SUPPORTS_REQUIRED_FEATURES;
  }

  /**
   * The view element (outermost container).
   * @type {HTMLElement|null}
   */
  @tracked view = null;

  /**
   * The content element (inner content container).
   * @type {HTMLElement|null}
   */
  @tracked content = null;

  /**
   * The content wrapper element.
   * @type {HTMLElement|null}
   */
  @tracked contentWrapper = null;

  /**
   * The scroll container element used for swipe interaction.
   * @type {HTMLElement|null}
   */
  @tracked scrollContainer = null;

  /**
   * The backdrop element for dimming and click-outside handling.
   * @type {HTMLElement|null}
   */
  @tracked backdrop = null;

  /**
   * Whether the sheet is currently presented.
   * @type {boolean}
   */
  @tracked isPresented = false;

  /**
   * Whether it's safe to unmount the sheet (no animations running).
   * @type {boolean}
   */
  @tracked safeToUnmount = true;

  /**
   * User-provided detent configuration.
   * @type {Array|null}
   */
  @tracked detentsConfig = null;

  /**
   * Whether swipe overshoot is enabled.
   * @type {boolean}
   */
  @tracked swipeOvershoot = true;

  /**
   * Whether backdrop responds to swipe gestures.
   * @type {boolean}
   */
  @tracked backdropSwipeable = true;

  /**
   * Whether elements outside the sheet are inert.
   * @type {boolean}
   */
  @tracked inertOutside = true;

  /**
   * Array of detent marker elements.
   * @type {TrackedArray<HTMLElement>}
   */
  detentMarkers = new TrackedArray();

  /**
   * Unique ID for this controller instance.
   * @type {string}
   */
  id = guidFor(this);

  /**
   * Content placement direction ("bottom", "top", "left", "right", "center").
   * @type {string}
   */
  contentPlacement = "bottom";

  /**
   * Calculated dimensions for layout and scroll calculations.
   * @type {Object|null}
   */
  dimensions = null;

  /**
   * Index of the currently active detent.
   * @type {number}
   */
  activeDetent = 0;

  /**
   * Index of the target detent to animate to.
   * @type {number}
   */
  targetDetent = 1;

  /**
   * Current travel segment [start, end] as detent indices.
   * @type {Array<number>}
   */
  currentSegment = [0, 0];

  /**
   * Current travel status ("idleOutside", "idleInside", "travellingIn", "travellingOut", "stepping").
   * @type {string}
   */
  travelStatus = "idleOutside";

  /**
   * Previous travel status before last change.
   * @type {string}
   */
  previousTravelStatus = "idleOutside";

  /**
   * Current travel range (start and end detent indices).
   * @type {{start: number, end: number}}
   */
  travelRange = { start: 0, end: 0 };

  /**
   * Last processed progress value to prevent duplicate callbacks.
   * @type {number|null}
   */
  lastProcessedProgress = null;

  /**
   * Progress smoother function initialized when interaction begins.
   * Prevents large jumps in progress values.
   *
   * @type {Function|null}
   */
  progressSmoother = null;

  /**
   * ARIA role for the sheet ("dialog", "alertdialog", etc.).
   * @type {string}
   */
  role = "dialog";

  /**
   * Track direction ("bottom", "top", "left", "right", "horizontal", "vertical").
   * @type {string}
   */
  tracks = "bottom";

  /**
   * Whether swipe gestures are enabled.
   * @type {boolean}
   */
  swipe = true;

  /**
   * Whether swipe-to-dismiss is enabled.
   * @type {boolean}
   */
  swipeDismissal = true;

  /**
   * Swipe trap configuration (true, false, {x, y}).
   * @type {boolean|Object}
   */
  swipeTrap = true;

  /**
   * Whether native focus scroll prevention is enabled.
   * @type {boolean}
   */
  nativeFocusScrollPrevention = true;

  /**
   * Whether page scrolling is enabled when sheet is open.
   * @type {boolean}
   */
  pageScroll = false;

  /**
   * Animation settings for entering the sheet.
   * @type {string|Object|null}
   */
  enteringAnimationSettings = null;

  /**
   * Animation settings for exiting the sheet.
   * @type {string|Object|null}
   */
  exitingAnimationSettings = null;

  /**
   * Animation settings for stepping between detents.
   * @type {string|Object|null}
   */
  steppingAnimationSettings = null;

  /**
   * Snap-out acceleration setting (auto or numeric value).
   * @type {string|number}
   */
  snapOutAcceleration = "auto";

  /**
   * Snap-to-end detents acceleration setting (auto or numeric value).
   * @type {string|number}
   */
  snapToEndDetentsAcceleration = "auto";

  /**
   * Click-outside handler configuration.
   * @type {Object}
   */
  onClickOutside = {
    dismiss: true,
    stopOverlayPropagation: true,
  };

  /**
   * Escape key handler configuration.
   * @type {Object|Function}
   */
  onEscapeKeyDown = {
    nativePreventDefault: true,
    dismiss: true,
    stopOverlayPropagation: true,
  };

  /**
   * Auto-focus configuration when presenting.
   * @type {Object|Function}
   */
  onPresentAutoFocus = { focus: true };

  /**
   * Auto-focus configuration when dismissing.
   * @type {Object|Function}
   */
  onDismissAutoFocus = { focus: true };

  /**
   * Array of sheets below this one in the stack.
   * @type {Array<Controller>}
   */
  belowSheetsInStack = [];

  /**
   * Index in the sheet stack.
   * @type {number}
   */
  stackingIndex = -1;

  /**
   * ID of the stack this sheet belongs to.
   * @type {string|null}
   */
  stackId = null;

  /**
   * Counter tracking how many times this sheet has been covered by sheets above.
   * @type {number}
   */
  coveredCount = 0;

  /**
   * Reference to the sheet stack registry.
   * @type {Object|null}
   */
  sheetStackRegistry = null;

  /**
   * Reference to the sheet registry.
   * @type {Object|null}
   */
  sheetRegistry = null;

  /**
   * Reference to the theme color manager.
   * @type {Object|null}
   */
  themeColorManager = null;

  /**
   * Array of registered travel animations.
   * @type {Array<Object>}
   */
  travelAnimations = [];

  /**
   * Array of registered stacking animations.
   * @type {Array<Object>}
   */
  stackingAnimations = [];

  /**
   * Theme color dimming overlay for backdrop.
   * @type {{updateAlpha: Function, remove: Function}|null}
   */
  backdropThemeColorDimmingOverlay = null;

  /**
   * Cleanup function for backdrop theme color dimming travel animation.
   * @type {Function|null}
   */
  backdropThemeColorDimmingTravelAnimationCleanup = null;

  /**
   * Current alpha value for backdrop theme color dimming.
   * @type {number}
   */
  backdropThemeColorDimmingAlpha = 0;

  /**
   * Callback invoked when travel status changes.
   * @type {Function|null}
   */
  onTravelStatusChange = null;

  /**
   * Callback invoked when travel range changes.
   * @type {Function|null}
   */
  onTravelRangeChange = null;

  /**
   * Callback invoked during travel with progress updates.
   * @type {Function|null}
   */
  onTravel = null;

  /**
   * Callback invoked when travel starts.
   * @type {Function|null}
   */
  onTravelStart = null;

  /**
   * Callback invoked when travel ends.
   * @type {Function|null}
   */
  onTravelEnd = null;

  /**
   * Callback invoked when active detent changes.
   * @type {Function|null}
   */
  onActiveDetentChange = null;

  /**
   * Callback invoked when travel progress changes.
   * @type {Function|null}
   */
  onTravelProgressChange = null;

  /**
   * Callback invoked when safe-to-unmount status changes.
   * @type {Function|null}
   */
  onSafeToUnmountChange = null;

  /**
   * Callback invoked when focus enters the sheet.
   * @type {Function|null}
   */
  onFocusInside = null;

  /**
   * Focus management helper instance.
   * @type {FocusManagement|null}
   */
  focusManagement = null;

  /**
   * Touch handler instance.
   * @type {TouchHandler}
   */
  touchHandler;

  /**
   * Timeout manager instance.
   * @type {TimeoutManager}
   */
  timeoutManager;

  /**
   * Detent manager instance.
   * @type {DetentManager}
   */
  detentManager;

  /**
   * DOM attributes helper instance.
   * @type {DOMAttributes}
   */
  domAttributes;

  /**
   * Observer manager instance.
   * @type {ObserverManager}
   */
  observerManager;

  /**
   * Scroll progress calculator instance.
   * @type {ScrollProgressCalculator}
   */
  scrollProgressCalculator;

  /**
   * Stacking adapter instance.
   * @type {StackingAdapter}
   */
  stackingAdapter;

  /**
   * State machine helper instance.
   * @type {StateHelper}
   */
  state;

  /**
   * Animation travel helper instance.
   * @type {AnimationTravel}
   */
  animationTravel;

  /**
   * Theme color adapter instance.
   * @type {ThemeColorAdapter}
   */
  themeColorAdapter;

  /**
   * Root component reference (set externally).
   * @type {Object|null}
   */
  rootComponent = null;

  /**
   * Whether the controller is being destroyed.
   * @type {boolean}
   */
  isDestroying = false;

  /**
   * Whether the controller has been destroyed.
   * @type {boolean}
   */
  isDestroyed = false;

  /**
   * Subscription definitions for state machines.
   *
   * @type {Array<{machine: string, state: string, timing?: string, callback?: Function, handler?: string, guard?: Function, type?: string}>}
   */
  #subscriptionDefinitions = [
    {
      machine: "staging",
      state: "opening",
      timing: "after-paint",
      callback: () => {
        requestAnimationFrame(() => {
          this.state.openness.readyToOpen(false);
        });
      },
    },
    {
      machine: "staging",
      state: "closing",
      timing: "after-paint",
      callback: () => {
        this.handleStateTransition({ type: "READY_TO_CLOSE" });
      },
    },
    {
      machine: "openness",
      state: "opening",
      timing: "before-paint",
      handler: "handleOpening",
    },
    {
      machine: "elementsReady",
      state: "true",
      timing: "immediate",
      guard: () => this.state.openness.current === "opening",
      callback: () => this.#startOpeningAnimation(),
    },
    {
      machine: "openness",
      state: "open",
      guard: () => {
        const msg = this.state.openness.lastProcessedMessage;
        return ["NEXT", "PREPARED", "STEP", "READY_TO_OPEN"].includes(
          msg?.type
        );
      },
      callback: (message) => this.handleOpen(message),
    },
    { machine: "openness", state: "closing", handler: "handleClosing" },
    {
      machine: "openness",
      state: "closed.status:pending",
      handler: "handleClosedPending",
    },
    {
      machine: "openness",
      state: "closed.status:safe-to-unmount",
      handler: "handleClosedSafeToUnmount",
    },
    {
      machine: "openness",
      state: "closed.status:flushing-to-preparing-opening",
      timing: "before-paint",
      callback: () => {
        this.timeoutManager.clear("pendingFlush");
        this.state.flushClosedStatus();
      },
    },
    {
      machine: "openness",
      state: "closed.status:flushing-to-preparing-open",
      timing: "before-paint",
      callback: () => {
        this.timeoutManager.clear("pendingFlush");
        this.state.flushClosedStatus();
      },
    },
    {
      machine: "openness",
      state: "closed.status:preparing-opening",
      timing: "after-paint",
      callback: () => {
        this.state.beginEnterAnimation(false);
      },
    },
    {
      machine: "openness",
      state: "closed.status:preparing-open",
      timing: "after-paint",
      callback: () => {
        this.state.beginEnterAnimation(true);
      },
    },
    {
      machine: "position",
      state: "covered.status:going-down",
      callback: () => {
        this.coveredCount++;
        this.stackingAdapter?.updateStackingIndexWithPositionValue();
        this.state.staging.goDown();
      },
    },
    {
      machine: "position",
      state: "covered.status:idle",
      callback: () => {
        if (
          this.state.staging.matches("going-down") ||
          this.state.staging.matches("go-down")
        ) {
          this.state.staging.advance();
        }
      },
    },
    {
      machine: "position",
      state: "covered.status:going-up",
      callback: () => this.state.staging.goUp(),
    },
    {
      machine: "position",
      state: "covered.status:indeterminate",
      callback: () => {
        this.coveredCount--;
        this.stackingAdapter?.updateStackingIndexWithPositionValue();

        if (this.state.staging.matches("going-up")) {
          this.state.staging.advance();
        }

        if (this.coveredCount === 0) {
          this.state.position.goToFrontIdle();
        } else {
          this.state.position.goToCoveredIdle();
        }
      },
    },
    {
      machine: "position",
      state: "covered.status:come-back",
      timing: "immediate",
      callback: () => {
        this.state.advancePositionAuto();
      },
    },
    {
      machine: "openness",
      state: "open.scroll:ongoing",
      callback: () => {
        const currentProgress =
          this.dimensions?.progressValueAtDetents?.[this.activeDetent]?.exact ??
          0;
        this.progressSmoother = this.createProgressSmoother(currentProgress);
      },
    },
    {
      machine: "openness",
      state: "open.swipe:ended",
      guard: () => typeof this.onTravelStatusChange === "function",
      callback: () => {
        if (this.state.openness.isOpen) {
          this.onTravelStatusChange("idleInside");
        }
      },
    },
    {
      machine: "staging",
      state: "none",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("none"),
    },
    {
      machine: "staging",
      state: "opening",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("opening"),
    },
    {
      machine: "staging",
      state: "open",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("open"),
    },
    {
      machine: "staging",
      state: "stepping",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("stepping"),
    },
    {
      machine: "staging",
      state: "closing",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("closing"),
    },
    {
      machine: "staging",
      state: "go-down",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("go-down"),
    },
    {
      machine: "staging",
      state: "going-down",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("going-down"),
    },
    {
      machine: "staging",
      state: "going-up",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("going-up"),
    },
    {
      machine: "touch",
      state: "ongoing",
      timing: "immediate",
      callback: () => this.touchHandler.handleScrollStart(),
    },
    {
      machine: "touch",
      state: "ended",
      timing: "immediate",
      callback: () => this.touchHandler.handleScrollEnd(),
    },
  ];

  /**
   * Initialize the controller with helpers.
   * Use configure() to set options after construction.
   */
  constructor() {
    /** @type {TouchHandler} */
    this.touchHandler = new TouchHandler(this);
    /** @type {FocusManagement} */
    this.focusManagement = new FocusManagement(this);
    /** @type {TimeoutManager} */
    this.timeoutManager = new TimeoutManager();
    /** @type {DetentManager} */
    this.detentManager = new DetentManager(this);
    /** @type {DOMAttributes} */
    this.domAttributes = new DOMAttributes(this);
    /** @type {ObserverManager} */
    this.observerManager = new ObserverManager(this);
    /** @type {ScrollProgressCalculator} */
    this.scrollProgressCalculator = new ScrollProgressCalculator(this);
    /** @type {StackingAdapter} */
    this.stackingAdapter = new StackingAdapter(this);
    /** @type {StateHelper} */
    this.state = new StateHelper();
    /** @type {AnimationTravel} */
    this.animationTravel = new AnimationTravel(this);
    /** @type {ThemeColorAdapter} */
    this.themeColorAdapter = new ThemeColorAdapter(this);
    this.setupSubscriptions();
  }

  /**
   * Configure options for the controller.
   * Called by Root after construction and by View when it mounts.
   *
   * @param {Object} [options={}] - Configuration options
   */
  configure(options = {}) {
    if (options.role !== undefined) {
      this.role = options.role;
    }

    if (options.activeDetent !== undefined) {
      this.targetDetent = options.activeDetent;
    } else if (options.defaultActiveDetent !== undefined) {
      this.targetDetent = options.defaultActiveDetent;
    }

    if ("detents" in options) {
      this.detentsConfig = options.detents;
    }

    const result = resolveTracksAndPlacement(options, {
      tracks: this.tracks,
      contentPlacement: this.contentPlacement,
    });
    this.tracks = result.tracks;
    this.contentPlacement = result.contentPlacement;

    const propsToAssign = [
      "swipe",
      "swipeDismissal",
      "swipeOvershoot",
      "swipeTrap",
      "onFocusInside",
      "nativeFocusScrollPrevention",
      "pageScroll",
      "inertOutside",
      "enteringAnimationSettings",
      "exitingAnimationSettings",
      "steppingAnimationSettings",
      "snapOutAcceleration",
      "snapToEndDetentsAcceleration",
      "onTravelStatusChange",
      "onTravelRangeChange",
      "onTravel",
      "onTravelStart",
      "onTravelEnd",
      "onActiveDetentChange",
      "onSafeToUnmountChange",
      "sheetStackRegistry",
      "sheetRegistry",
      "themeColorManager",
    ];

    for (const key of propsToAssign) {
      if (options[key] !== undefined) {
        this[key] = options[key];
      }
    }

    const eventHandlers = [
      "onClickOutside",
      "onEscapeKeyDown",
      "onPresentAutoFocus",
      "onDismissAutoFocus",
    ];

    for (const key of eventHandlers) {
      if (options[key] !== undefined) {
        if (typeof options[key] === "function") {
          this[key] = options[key];
        } else {
          this[key] = {
            ...Controller.EVENT_HANDLER_DEFAULTS[key],
            ...options[key],
          };
        }
      }
    }

    this.themeColorAdapter.configure(options);
  }

  /**
   * Set up state machine subscriptions for lifecycle management.
   */
  setupSubscriptions() {
    for (const def of this.#subscriptionDefinitions) {
      this.state.subscribe(def.machine, {
        timing: def.timing || "immediate",
        state: def.state,
        guard: def.guard,
        callback: def.callback || ((msg) => this[def.handler](msg)),
        type: def.type,
      });
    }
  }

  /**
   * Invoke all registered travel animation callbacks.
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
   * Whether scroll trap is active (inertOutside or swipeTrap enabled).
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
  get swipeOutDisabledWithDetent() {
    if (this.swipe === false || !Controller.browserSupportsRequiredFeatures) {
      return false;
    }

    if (this.swipeDismissal && this.role !== "alertdialog") {
      return false;
    }

    if (this.detentsConfig === null || this.detentsConfig === undefined) {
      return false;
    }

    return this.state.openness.isOpen && !this.state.staging.isClosing;
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
   * Whether webkit small spacer mode should be enabled.
   * Used for webkit-specific scroll optimization when sheet is open and
   * swipe overshoot is enabled.
   *
   * @type {boolean}
   */
  get webkitSmallSpacerMode() {
    return (
      capabilities.browserEngine === "webkit" &&
      this.state.openness.isOpen &&
      !this.state.staging.isClosing &&
      !this.edgeAlignedNoOvershoot
    );
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
   * Get the staging attribute for CSS.
   *
   * @type {string|null}
   */
  get stagingAttribute() {
    return this.state.staging.current === "none" ? "staging-none" : null;
  }

  /**
   * Update travel status and notify callback.
   *
   * @param {string} status - "idleOutside", "idleInside", "travellingIn", "travellingOut", "stepping"
   */
  updateTravelStatus(status) {
    if (this.travelStatus !== status) {
      const previousStatus = this.travelStatus;
      this.travelStatus = status;
      this.previousTravelStatus = previousStatus;
      const newSafeToUnmount = status === "idleOutside";
      const safeToUnmountChanged = this.safeToUnmount !== newSafeToUnmount;
      this.safeToUnmount = newSafeToUnmount;

      if (safeToUnmountChanged) {
        this.onSafeToUnmountChange?.(newSafeToUnmount);
      }

      this.handleStackingStateChange(status, previousStatus);

      this.onTravelStatusChange?.(status);
    }
  }

  /**
   * Handle stacking state changes based on travel status.
   * Delegates to stacking adapter for bookkeeping.
   *
   * @param {string} status - Current travel status
   * @param {string} previousStatus - Previous travel status
   */
  handleStackingStateChange(status, previousStatus) {
    this.stackingAdapter.handleTravelStatusChange(status, previousStatus);
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
   * Merged staging state for the stack.
   * Returns "not-none" if ANY sheet in the stack has staging !== "none".
   *
   * @type {string}
   */
  get mergedStaging() {
    return this.stackingAdapter?.getMergedStaging() ?? "none";
  }

  /**
   * Whether any sheet in the stack is currently animating.
   *
   * @type {boolean}
   */
  get isStackAnimating() {
    return this.mergedStaging !== "none";
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

    if (this.swipeOutDisabledWithDetent) {
      const { backStuck, frontStuck, shouldStep } =
        this.detentManager.determineStuckPosition(segment, prevSegment);

      if (backStuck) {
        this.state.stuck.startBack();
        if (shouldStep === "back") {
          this.stepToStuckPosition("back");
        }
      } else if (frontStuck) {
        this.state.stuck.startFront();
        if (shouldStep === "front") {
          this.stepToStuckPosition("front");
        }
      } else {
        if (this.state.stuck.isFront) {
          this.state.stuck.endFront();
        }
        if (this.state.stuck.isBack) {
          this.state.stuck.endBack();
        }
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
    this.state.openness.send(message);
  }

  /**
   * Handle the opening state.
   * Starts the enter animation and sends NEXT when complete.
   * If elements aren't ready yet (tracked via elementsReady state machine),
   * defers animation until ELEMENTS_REGISTERED is sent.
   *
   * @private
   */
  handleOpening() {
    this.isPresented = true;
    this.updateTravelStatus("travellingIn");
    this.focusManagement.capturePreviouslyFocusedElement();

    this.state.longRunning.start();
    this.state.beginEnterAnimation(false);
    this.stackingAdapter.notifyParentOfOpening(false);

    if (this.state.elements.isReady) {
      this.#startOpeningAnimation();
    }
  }

  /**
   * Start the opening animation.
   * Called from handleOpening or from element registration when deferred.
   *
   * @private
   */
  #startOpeningAnimation() {
    this.resetViewStyles();
    this.calculateDimensionsIfReady();
    this.domAttributes.setHidden();
    this.animationTravel.animateToDetent(this.targetDetent);
  }

  /**
   * Send ELEMENTS_REGISTERED if all required elements are now present.
   * Used by register methods to signal readiness for deferred animations.
   * Deferred to next frame to avoid Ember auto-tracking issues.
   *
   * @private
   */
  #notifyElementsRegisteredIfReady() {
    if (
      this.view &&
      this.scrollContainer &&
      this.contentWrapper &&
      this.state.elements.isNotReady
    ) {
      // Defer to next run loop to avoid updating tracked state during render
      next(() => {
        if (this.state.elements.isNotReady) {
          this.state.elements.markRegistered();
        }
      });
    }
  }

  /**
   * Handle the open state.
   * Sets up scroll behavior, focus, and intersection observer.
   *
   * @param {Object} message - State transition message
   */
  handleOpen(message) {
    if (this.state.longRunning.isActive) {
      this.state.longRunning.end();
    }

    this.updateScrollSnapBehavior();
    this.updateTravelRange(this.activeDetent, this.activeDetent);
    this.updateTravelStatus("idleInside");
    this.applyInertOutside();

    if (message?.type !== "STEP") {
      this.executeAutoFocusOnPresent();
    }

    if (this.state.staging.matches("opening")) {
      this.state.staging.advance();
    }

    this.#setupIntersectionObserver();

    if (message?.type === "STEP") {
      this.handleStepMessage(message);
    }
  }

  /**
   * Set up intersection observer if swipe-out is enabled.
   * Deferred to next frame to ensure DOM is ready.
   * @private
   */
  #setupIntersectionObserver() {
    if (this.swipeOutDisabledWithDetent) {
      return;
    }

    requestAnimationFrame(() => {
      if (this.state.openness.isOpen && !this.swipeOutDisabledWithDetent) {
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
    this.state.stepAnimation();
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
    this.state.position.readyToGoOut();
    this.updateTravelStatus("travellingOut");
    this.stackingAdapter.notifyParentOfClosing();

    if (this.state.skip.isClosing) {
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
    this.state.skip.disableClosing();

    this.stackingAdapter.notifyBelowSheets(0);

    requestAnimationFrame(() => {
      this.handleStateTransition({ type: "NEXT" });
    });
  }

  /**
   * Handle the closed.pending state.
   * Handles immediate close if needed, then schedules flush to safe-to-unmount.
   * @private
   */
  handleClosedPending() {
    this.state.longRunning.end();
    this.#handleImmediateCloseIfNeeded();
    this.#scheduleFlushToSafeToUnmount();
  }

  /**
   * Handle immediate close (swipe-out) without animation.
   * @private
   */
  #handleImmediateCloseIfNeeded() {
    if (!this.state.skip.isClosing) {
      return;
    }

    this.state.beginImmediateClose(true);
    this.updateTravelStatus("travellingOut");
    this.state.skip.disableClosing();
    this.state.position.goOut();
    this.stackingAdapter.notifyParentOfClosingImmediate();

    this.stackingAdapter.notifyBelowSheets(0);
  }

  /**
   * Schedule the flush to safe-to-unmount state.
   * @private
   */
  #scheduleFlushToSafeToUnmount() {
    this.timeoutManager.schedule(
      "pendingFlush",
      () => {
        if (this.state.openness.isClosedPending) {
          this.state.openness.flushComplete();
        }
      },
      16
    );
  }

  /**
   * Handle the closed.safe-to-unmount state.
   * Performs final cleanup and resets all state to initial values.
   * @private
   */
  handleClosedSafeToUnmount() {
    const wasLongRunning = this.state.longRunning.isActive;

    // Reset presentation flags
    this.isPresented = false;
    if (this.state.stuck.isFront) {
      this.state.stuck.endFront();
    }
    if (this.state.stuck.isBack) {
      this.state.stuck.endBack();
    }

    if (wasLongRunning) {
      this.state.longRunning.end();
    }

    // Reset elementsReady state machine for next open cycle
    if (this.state.elements.isReady) {
      this.state.elements.reset();
    }

    this.executeAutoFocusOnDismiss();
    this.cleanup();

    // Reset travel state
    this.activeDetent = 0;
    this.currentSegment = [0, 0];
    this.dimensions = null;
    this.lastProcessedProgress = null;

    // Advance position machine if needed
    if (!this.state.position.isOut && this.state.position.isFrontClosing) {
      this.state.position.advance();
    }

    // Notify travel status change
    this.updateTravelStatus("idleOutside");
    this.updateTravelRange(0, 0);
  }

  /**
   * Create dimension calculator options object.
   * @returns {Object} Options for calculateDimensions
   * @private
   */
  #getDimensionCalculatorOptions() {
    return {
      swipeOutDisabledWithDetent: this.swipeOutDisabledWithDetent,
      snapOutAcceleration: this.snapOutAcceleration,
      snapToEndDetentsAcceleration: this.snapToEndDetentsAcceleration,
      edgeAlignedNoOvershoot: this.edgeAlignedNoOvershoot,
      webkitSmallSpacerMode: this.webkitSmallSpacerMode,
    };
  }

  /**
   * Calculate and return dimensions using current elements.
   * @returns {Object} Calculated dimensions
   * @private
   */
  #calculateDimensions() {
    const calculator = new DimensionCalculator({
      view: this.view,
      content: this.content,
      scrollContainer: this.scrollContainer,
      detentMarkers: this.detentMarkers,
    });

    return calculator.calculateDimensions(
      this.tracks,
      this.contentPlacement,
      this.#getDimensionCalculatorOptions()
    );
  }

  /**
   * Calculate dimensions if all required elements are ready.
   * Pure dimension calculation - no state transitions.
   */
  calculateDimensionsIfReady() {
    const hasRequiredMarkers =
      this.detentsConfig === undefined || this.detentMarkers.length > 0;

    if (
      this.view &&
      this.content &&
      this.scrollContainer &&
      hasRequiredMarkers &&
      !this.dimensions
    ) {
      this.dimensions = this.#calculateDimensions();
      this.setInitialScrollPosition();
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
      this.dimensions.progressValueAtDetents?.[detentIndex]?.exact;
    if (progressAtDetent === undefined) {
      return;
    }

    const scrollDistance =
      progressAtDetent * this.dimensions.content.travelAxis.unitless;
    const isHorizontal = this.isHorizontalTrack;

    if (isHorizontal) {
      this.scrollContainer.scrollLeft = scrollDistance;
    } else {
      this.scrollContainer.scrollTop = scrollDistance;
    }

    this.activeDetent = detentIndex;
    this.currentSegment = [detentIndex, detentIndex];
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
    this.#notifyElementsRegisteredIfReady();
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
    this.dimensions = this.#calculateDimensions();

    if (this.state.openness.isOpen) {
      if (!this.swipeOutDisabledWithDetent) {
        this.setupIntersectionObserver();
      } else {
        this.cleanupIntersectionObserver();
      }
    }

    if (this.activeDetent > 0 && this.state.openness.isOpen) {
      requestAnimationFrame(() => {
        if (!this.isDestroying && !this.isDestroyed) {
          this.animationTravel.recalculateAndTravel(this.activeDetent);
        }
      });
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
    this.unregisterBackdrop(this.backdrop);
    this.themeColorAdapter.cleanup();
    this.domAttributes.cleanup();
    this.focusManagement.cleanup();
    this.state.cleanup();
    this.stackingAdapter?.removeStagingFromStack();
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
   * Apply inert attribute to elements outside the sheet.
   */
  applyInertOutside() {
    this.sheetRegistry?.updateInertOutside(this, this.inertOutside);
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
    this.#notifyElementsRegisteredIfReady();
  }

  /**
   * Register the scroll container element.
   *
   * @param {HTMLElement} scrollContainer - The scroll container element
   */
  @action
  registerScrollContainer(scrollContainer) {
    this.scrollContainer = scrollContainer;

    this.calculateDimensionsIfReady();
    this.#notifyElementsRegisteredIfReady();
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
   * Handle native scroll events - state transitions only.
   */
  @action
  handleScrollStateChange() {
    if (!this.state.openness.isOpen || this.state.staging.current !== "none") {
      return;
    }

    if (!this.scrollContainer || !this.dimensions) {
      return;
    }

    if (!this.state.openness.isScrollOngoing) {
      this.state.openness.scrollStart();
    }

    if (!this.state.stuck.isFront && !this.state.stuck.isBack) {
      if (!this.state.openness.isSwipeOngoing) {
        this.state.openness.swipeStart();
      }
      if (!this.state.openness.isMoveOngoing) {
        this.state.openness.moveStart();
      }
    }

    this.timeoutManager.schedule(
      "scrollEnd",
      () => {
        this.#handleScrollEnd();
      },
      200
    );
  }

  /**
   * Process a single scroll frame - called by RAF loop.
   */
  @action
  processScrollFrame() {
    if (!this.state.openness.isOpen) {
      return;
    }

    if (!this.scrollContainer || !this.dimensions) {
      return;
    }

    this.processScrollProgress();
  }

  /**
   * Handle scroll end - send end messages for scroll/swipe/move.
   * @private
   */
  #handleScrollEnd() {
    this.state.openness.moveEnd();

    const progress = this.scrollProgressCalculator.calculateProgress();
    const detents = this.dimensions?.progressValueAtDetents;

    if (progress && detents) {
      for (const detent of detents) {
        const matches =
          progress.clampedProgress > detent.exact - 0.01 &&
          progress.clampedProgress < detent.exact + 0.01;

        if (matches) {
          this.state.openness.scrollEnd();
          this.state.openness.swipeEnd();
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
      let currentDelta = lastValue - newProgress;

      if (
        (currentDelta === 0 ||
          Math.abs(currentDelta) < Math.abs(lastDelta / 2)) &&
        this.state.touch.isOngoing
      ) {
        result = lastValue - lastDelta / 2;
        currentDelta = lastValue - result;
      }

      if (Math.abs(currentDelta) >= 0.1 && Math.abs(currentDelta) < 0.35) {
        result = currentDelta >= 0 ? lastValue - 0.1 : lastValue + 0.1;
        currentDelta = currentDelta >= 0 ? 0.1 : -0.1;
      }

      if (newProgress <= 0) {
        result = 0;
      }

      lastValue = result;
      lastDelta = currentDelta;
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

    const { clampedProgress } = progress;
    const minProgress =
      this.edgeAlignedNoOvershoot && this.swipeOutDisabledWithDetent
        ? (this.dimensions?.progressValueAtDetents?.[1]?.exact ?? 0)
        : 0;
    const maxProgress = this.edgeAlignedNoOvershoot ? 1 : 10;

    const smoothedProgressValue = this.progressSmoother
      ? this.progressSmoother(clampedProgress)
      : clampedProgress;
    const smoothedProgress = Math.min(
      maxProgress,
      Math.max(minProgress, smoothedProgressValue)
    );

    if (this.lastProcessedProgress === smoothedProgress) {
      return;
    }

    this.lastProcessedProgress = smoothedProgress;

    this.aggregatedTravelCallback(smoothedProgress);
    this.onTravelProgressChange?.(smoothedProgress);

    this.stackingAdapter.notifyBelowSheets(smoothedProgress);

    this.notifyTravel(smoothedProgress);

    const segment =
      this.scrollProgressCalculator.determineSegment(smoothedProgress);
    if (segment) {
      this.setSegment(segment);
      if (segment[0] === 0 && segment[1] === 0 && smoothedProgress <= 0) {
        return;
      }
    }
  }

  /**
   * Handle touchstart events on scroll-container.
   */
  @action
  handleTouchStart() {
    this.state.touch.start();
  }

  /**
   * Handle touchend events on scroll-container.
   */
  @action
  handleTouchEnd() {
    this.state.touch.end();
  }

  /**
   * Handle focus events on scroll-container.
   *
   * @param {FocusEvent} event - The focus event
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
    this.state.openness.swipeStart();
  }

  /**
   * Handle touch gesture end.
   * Called by TouchHandler when a swipe gesture ends.
   * May trigger step to stuck position if needed.
   */
  onTouchGestureEnd() {
    this.state.openness.swipeEnd();

    if (
      this.edgeAlignedNoOvershoot &&
      this.snapToEndDetentsAcceleration === "auto" &&
      this.state.openness.isOpen &&
      this.state.openness.isScrollEnded
    ) {
      this.timeoutManager.schedule(
        "stuckPosition",
        () => {
          requestAnimationFrame(() => {
            if (this.state.openness.isOpen) {
              if (this.state.stuck.isBack) {
                this.stepToStuckPosition("back");
              } else if (this.state.stuck.isFront) {
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
    if (this.state.stuck.isFront) {
      this.state.stuck.endFront();
    }
    if (this.state.stuck.isBack) {
      this.state.stuck.endBack();
    }

    this.state.openness.moveStart();
    this.updateTravelStatus("travellingIn");

    this.animationTravel.stepToStuckPosition(direction, () => {
      this.state.openness.moveEnd();
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
   *
   * @param {HTMLElement} backdrop - The backdrop element
   * @param {Object|Function|null} travelAnimation - Travel animation config (used for theme color dimming)
   * @param {boolean} swipeable - Whether backdrop responds to swipe/click
   */
  @action
  registerBackdrop(backdrop, travelAnimation = null, swipeable = true) {
    this.backdrop = backdrop;
    this.backdropSwipeable = swipeable;
    backdrop.style.opacity = 0;
    backdrop.style.willChange = "opacity";
    this.#cleanupBackdropThemeColorDimming();

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

      this.backdropThemeColorDimmingOverlay =
        this.themeColorAdapter.registerThemeColorDimmingOverlay({
          color: backgroundColor,
          alpha: this.backdropThemeColorDimmingAlpha,
        });

      this.backdropThemeColorDimmingTravelAnimationCleanup =
        this.registerTravelAnimation({
          callback: (progress) => {
            const opacity = opacityFn({ progress });
            this.backdropThemeColorDimmingAlpha = opacity;
            backdrop.style.setProperty("opacity", opacity);

            if (this.backdropThemeColorDimmingOverlay) {
              this.backdropThemeColorDimmingOverlay.updateAlpha(opacity);
            }
          },
        });
    }
  }

  /**
   * Clean up backdrop theme color dimming overlay and travel animation.
   * @private
   */
  #cleanupBackdropThemeColorDimming() {
    this.backdropThemeColorDimmingTravelAnimationCleanup?.();
    this.backdropThemeColorDimmingTravelAnimationCleanup = null;

    this.backdropThemeColorDimmingOverlay?.remove?.();
    this.backdropThemeColorDimmingOverlay = null;
  }

  /**
   * Unregister backdrop element and remove backdrop-specific handlers.
   *
   * @param {HTMLElement|null} backdrop - The backdrop to unregister
   */
  @action
  unregisterBackdrop(backdrop = this.backdrop) {
    if (backdrop && this.backdrop && backdrop !== this.backdrop) {
      return;
    }

    this.#cleanupBackdropThemeColorDimming();
    this.backdrop = null;
    this.backdropSwipeable = false;
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
   * @param {HTMLElement} [animation.target] - Target element for the animation
   * @param {Object} [animation.config] - Animation configuration object
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
    this.state.broadcastOpen();
  }

  /**
   * Close the sheet.
   */
  @action
  close() {
    this.handleStateTransition({ type: "CLOSE" });
    this.#evaluateCloseMessage();
  }

  /**
   * Evaluates whether a CLOSE request can proceed to actual closing.
   *
   * @private
   */
  #evaluateCloseMessage() {
    if (!this.state.openness.isOpen) {
      return;
    }

    const atInitialSegment =
      this.currentSegment[0] === 0 && this.currentSegment[1] === 0;
    const isSteppingWithSwipeOutDisabled =
      this.swipeOutDisabledWithDetent &&
      this.currentSegment[0] !== this.currentSegment[1];
    const canActuallyClose =
      this.state.position.isFront &&
      !atInitialSegment &&
      !isSteppingWithSwipeOutDisabled;

    if (!canActuallyClose) {
      if (this.rootComponent?.effectivePresented === false) {
        this.rootComponent.present();
      }
      return;
    }

    this.state.staging.actuallyClose();
    this.handleStateTransition({ type: "ACTUALLY_CLOSE" });
  }

  /**
   * Send a message to the position machine.
   *
   * @param {string|Object} message - Message to send
   * @param {Object} context - Context for guards
   * @returns {boolean} Whether a transition occurred
   */
  sendToPositionMachine(message, context = {}) {
    return this.state.sendToPosition(message, context);
  }

  /**
   * Step to the next detent (upward direction).
   * Cycles back to first detent when at the last.
   */
  @action
  step() {
    if (!this.state.openness.isOpen) {
      return;
    }

    const nextDetent = this.detentManager.calculateStep("up");
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
    if (!this.state.openness.isOpen) {
      return;
    }

    const prevDetent = this.detentManager.calculateStep("down");
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
    if (!this.state.openness.isOpen) {
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
  }
}
