import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { tracked } from "@glimmer/tracking";
import { createTweenFunction } from "./animation";
import AnimationTravel from "./animation-travel";
import { trackToPlacement } from "./config-normalizer";
import DimensionCalculator from "./dimensions-calculator";
import DOMAttributes from "./dom-attributes";
import FocusManagement from "./focus-management";
import InertManagement from "./inert-management";
import ObserverManager from "./observer-manager";
import StackingAdapter from "./stacking-adapter";
import StateHelper from "./state-helper";
import StateMachine from "./state-machine";
import { POSITION_STATES, SHEET_STATES, STAGING_STATES } from "./states";
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
  /** @type {string} */
  @tracked tracks = "bottom";
  /** @type {string} */
  @tracked contentPlacement = "end";
  /** @type {boolean} */
  @tracked inertOutside = true;
  /** @type {Array|null} */
  @tracked detentsConfig = null;
  /** @type {boolean} */
  @tracked swipeOvershoot = true;
  /** @type {TrackedArray<HTMLElement>} */
  detentMarkers = new TrackedArray();

  /** @type {string} */
  id = guidFor(this);

  /** @type {string} */
  role = "dialog";

  /** @type {StateMachine} Main state machine for sheet lifecycle */
  stateMachine = new StateMachine(SHEET_STATES, SHEET_STATES.initial);

  /** @type {StateMachine} State machine for staging transitions */
  stagingMachine = new StateMachine(STAGING_STATES, STAGING_STATES.initial);

  /** @type {StateMachine} State machine for stacking position */
  positionMachine = new StateMachine(POSITION_STATES, POSITION_STATES.initial);

  /** @type {StateMachine} State machine for touch gesture tracking */
  touchMachine = new StateMachine(
    {
      initial: "ended",
      states: {
        ended: { on: { TOUCH_START: "ongoing" } },
        ongoing: { on: { TOUCH_END: "ended" } },
      },
    },
    "ended"
  );

  /** @type {Object|null} Calculated dimension data */
  dimensions = null;

  /** @type {boolean} Whether the view was hidden by intersection observer */
  viewHiddenByObserver = false;

  /** @type {boolean} Flag to skip closing animation */
  closingWithoutAnimation = false;

  /** @type {number} Currently active detent index */
  activeDetent = 0;

  /** @type {number} Target detent for animations */
  targetDetent = 1;

  /** @type {Array<number>} Current travel segment [start, end] */
  currentSegment = [0, 0];

  /** @type {boolean} Whether stuck at front (last) detent */
  frontStuck = false;

  /** @type {boolean} Whether stuck at back (first) detent */
  backStuck = false;

  /** @type {number} Current travel progress (0-1) */
  travelProgress = 0;

  /** @type {string} Current travel status */
  travelStatus = "idleOutside";

  /** @type {{start: number, end: number}} Current travel range */
  travelRange = { start: 0, end: 0 };

  /** @type {string} Previous travel status for comparison */
  previousTravelStatus = "idleOutside";

  /** @type {Array<Object>} Registered travel animation callbacks */
  travelAnimations = [];

  /** @type {Array<Object>} Registered stacking animation callbacks */
  stackingAnimations = [];

  /** @type {Animation|null} Current backdrop Web Animations API animation */
  backdropAnimation = null;

  /** @type {Function|null} Backdrop opacity function from travelAnimation */
  backdropOpacityFn = null;

  /** @type {Array<Controller>} Sheets below this one in the stack */
  belowSheetsInStack = [];

  /**
   * Aggregated callback for all travel animations.
   *
   * @param {number} progress - Travel progress (0-1)
   * @param {Function} tween - Tween function
   */
  aggregatedTravelCallback = (progress, tween) => {
    for (let i = 0; i < this.travelAnimations.length; i++) {
      this.travelAnimations[i].callback(progress, tween);
    }
  };

  /**
   * Aggregated callback for all stacking animations.
   *
   * @param {number} progress - Stacking progress (0-1)
   * @param {Function} tween - Tween function
   */
  aggregatedStackingCallback = (progress, tween) => {
    for (let i = 0; i < this.stackingAnimations.length; i++) {
      this.stackingAnimations[i].callback(progress, tween);
    }
  };

  /** @type {number} Index in the sheet stack */
  stackingIndex = -1;

  /** @type {string|null} ID of the stack this sheet belongs to */
  stackId = null;

  /** @type {number} Position within the stack */
  myStackPosition = 0;

  /** @type {Object|null} Registry for sheet stacks */
  sheetStackRegistry = null;

  /** @type {Object|null} Registry for all sheets */
  sheetRegistry = null;

  /** @type {Set} Registered outlet elements */
  outlets = new Set();

  /** @type {Function|null} Callback when travel status changes */
  onTravelStatusChange = null;

  /** @type {Function|null} Callback when travel range changes */
  onTravelRangeChange = null;

  /** @type {Function|null} Callback during travel with progress */
  onTravel = null;

  /** @type {Function|null} Callback when travel starts */
  onTravelStart = null;

  /** @type {Function|null} Callback when travel ends */
  onTravelEnd = null;

  /** @type {Function|null} Callback when active detent changes */
  onActiveDetentChange = null;

  /** @type {Function|null} Callback when travel progress changes */
  onTravelProgressChange = null;

  /** @type {boolean} Whether swipe gestures are enabled */
  swipe = true;

  /** @type {boolean} Whether swipe-to-dismiss is enabled */
  swipeDismissal = true;

  /** @type {boolean|Object} Swipe trap configuration */
  swipeTrap = true;

  /** @type {string|Object|null} Animation settings for entering */
  enteringAnimationSettings = null;

  /** @type {string|Object|null} Animation settings for exiting */
  exitingAnimationSettings = null;

  /** @type {string|Object|null} Animation settings for stepping between detents */
  steppingAnimationSettings = null;

  /** @type {string|number} Snap-out acceleration configuration */
  snapOutAcceleration = "auto";

  /** @type {string|number} Snap to end detents acceleration */
  snapToEndDetentsAcceleration = "auto";

  /** @type {Object} Click outside behavior configuration */
  onClickOutside = {
    dismiss: true,
    stopOverlayPropagation: true,
  };

  /** @type {Object|Function} Escape key behavior configuration */
  onEscapeKeyDown = {
    nativePreventDefault: true,
    dismiss: true,
    stopOverlayPropagation: true,
  };

  /** @type {Object|Function} Auto-focus behavior on present */
  onPresentAutoFocus = { focus: true };

  /** @type {Object|Function} Auto-focus behavior on dismiss */
  onDismissAutoFocus = { focus: true };

  /** @type {boolean} Whether to prevent native edge swipe gestures */
  nativeEdgeSwipePrevention = false;

  /** @type {boolean} Whether to prevent native focus-induced scrolling */
  nativeFocusScrollPrevention = true;

  /** @type {boolean} Whether page scroll is enabled */
  pageScroll = false;

  /** @type {Function|null} Callback for edge swipe attempts */
  onSwipeFromEdgeToGoBackAttempt = null;

  /** @type {boolean} Whether a programmatic scroll is in progress */
  programmaticScrollOngoing = false;

  /** @type {FocusManagement|null} Focus management helper */
  focusManagement = null;

  /** @type {InertManagement|null} Inert management helper */
  inertManagement = null;

  /** @type {Object|null} Theme color manager service */
  themeColorManager = null;

  /** @type {boolean|string} Theme color dimming configuration */
  themeColorDimming = false;

  /** @type {number|null} Alpha value for theme color dimming */
  themeColorDimmingAlpha = null;

  /** @type {Array} Registered theme color dimming overlays */
  themeColorDimmingOverlays = [];

  /** @type {HTMLMetaElement|null} Theme color meta tag element */
  themeColorMetaTag = null;

  /** @type {Object|null} Entry in the theme color stack */
  themeColorStackEntry = null;

  /** @type {string|null} Original underlying theme color */
  underlyingThemeColor = null;

  /** @type {boolean} Whether a touch gesture is active */
  touchGestureActive = false;

  /**
   * Initialize the controller with helpers and state machines.
   * Use configure() to set options after construction.
   */
  constructor() {
    this.touchHandler = new TouchHandler(this);
    this.focusManagement = new FocusManagement(this);
    this.inertManagement = new InertManagement(this);
    this.timeoutManager = new TimeoutManager();
    this.domAttributes = new DOMAttributes(this);
    this.observerManager = new ObserverManager(this);
    this.stackingAdapter = new StackingAdapter(this);
    this.stateHelper = new StateHelper(this);
    this.animationTravel = new AnimationTravel(this);
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
    if (options.role !== undefined) {
      this.role = options.role;
    }

    // Target detent (activeDetent takes priority over defaultActiveDetent)
    if (options.activeDetent !== undefined) {
      this.targetDetent = options.activeDetent;
    } else if (options.defaultActiveDetent !== undefined) {
      this.targetDetent = options.defaultActiveDetent;
    }

    if ("detents" in options) {
      this.detentsConfig = options.detents;
    }

    // Handle tracks first, then contentPlacement
    // If tracks is provided but contentPlacement is not, derive placement from tracks
    if (options.tracks !== undefined) {
      this.tracks = options.tracks;
      if (options.contentPlacement === undefined) {
        this.contentPlacement = trackToPlacement(options.tracks);
      }
    }
    if (options.contentPlacement !== undefined) {
      this.contentPlacement = options.contentPlacement;
    }

    // Swipe settings
    if (options.swipe !== undefined) {
      this.swipe = options.swipe;
    }
    if (options.swipeDismissal !== undefined) {
      this.swipeDismissal = options.swipeDismissal;
    }
    if (options.swipeOvershoot !== undefined) {
      this.swipeOvershoot = options.swipeOvershoot;
    }
    if (options.swipeTrap !== undefined) {
      this.swipeTrap = options.swipeTrap;
    }
    if (options.nativeEdgeSwipePrevention !== undefined) {
      this.nativeEdgeSwipePrevention = options.nativeEdgeSwipePrevention;
    }
    if (options.onSwipeFromEdgeToGoBackAttempt !== undefined) {
      this.onSwipeFromEdgeToGoBackAttempt =
        options.onSwipeFromEdgeToGoBackAttempt;
    }
    if (options.nativeFocusScrollPrevention !== undefined) {
      this.nativeFocusScrollPrevention = options.nativeFocusScrollPrevention;
    }
    if (options.pageScroll !== undefined) {
      this.pageScroll = options.pageScroll;
    }
    if (options.inertOutside !== undefined) {
      this.inertOutside = options.inertOutside;
    }

    if (options.onClickOutside !== undefined) {
      this.onClickOutside =
        typeof options.onClickOutside === "object"
          ? { ...this.onClickOutside, ...options.onClickOutside }
          : options.onClickOutside;
    }
    if (options.onEscapeKeyDown !== undefined) {
      this.onEscapeKeyDown =
        typeof options.onEscapeKeyDown === "function"
          ? options.onEscapeKeyDown
          : { ...this.onEscapeKeyDown, ...options.onEscapeKeyDown };
    }
    if (options.onPresentAutoFocus !== undefined) {
      this.onPresentAutoFocus =
        typeof options.onPresentAutoFocus === "function"
          ? options.onPresentAutoFocus
          : { ...this.onPresentAutoFocus, ...options.onPresentAutoFocus };
    }
    if (options.onDismissAutoFocus !== undefined) {
      this.onDismissAutoFocus =
        typeof options.onDismissAutoFocus === "function"
          ? options.onDismissAutoFocus
          : { ...this.onDismissAutoFocus, ...options.onDismissAutoFocus };
    }

    if (options.enteringAnimationSettings !== undefined) {
      this.enteringAnimationSettings = options.enteringAnimationSettings;
    }
    if (options.exitingAnimationSettings !== undefined) {
      this.exitingAnimationSettings = options.exitingAnimationSettings;
    }
    if (options.steppingAnimationSettings !== undefined) {
      this.steppingAnimationSettings = options.steppingAnimationSettings;
    }
    if (options.snapOutAcceleration !== undefined) {
      this.snapOutAcceleration = options.snapOutAcceleration;
    }
    if (options.snapToEndDetentsAcceleration !== undefined) {
      this.snapToEndDetentsAcceleration = options.snapToEndDetentsAcceleration;
    }

    if (options.themeColorDimming !== undefined) {
      this.themeColorDimming = options.themeColorDimming;
    }
    if (options.themeColorDimmingAlpha !== undefined) {
      this.themeColorDimmingAlpha = options.themeColorDimmingAlpha;
    }

    // Callbacks
    if (options.onTravelStatusChange !== undefined) {
      this.onTravelStatusChange = options.onTravelStatusChange;
    }
    if (options.onTravelRangeChange !== undefined) {
      this.onTravelRangeChange = options.onTravelRangeChange;
    }
    if (options.onTravel !== undefined) {
      this.onTravel = options.onTravel;
    }
    if (options.onTravelStart !== undefined) {
      this.onTravelStart = options.onTravelStart;
    }
    if (options.onTravelEnd !== undefined) {
      this.onTravelEnd = options.onTravelEnd;
    }
    if (options.onActiveDetentChange !== undefined) {
      this.onActiveDetentChange = options.onActiveDetentChange;
    }

    if (options.sheetStackRegistry !== undefined) {
      this.sheetStackRegistry = options.sheetStackRegistry;
    }
    if (options.sheetRegistry !== undefined) {
      this.sheetRegistry = options.sheetRegistry;
    }
    if (options.themeColorManager !== undefined) {
      this.themeColorManager = options.themeColorManager;
    }
  }

  /**
   * Set up state machine subscriptions for lifecycle management.
   */
  setupSubscriptions() {
    this.stateMachine.subscribe({
      timing: "immediate",
      state: "preparing-opening",
      callback: () => this.handlePreparingOpening(),
    });

    this.stateMachine.subscribe({
      timing: "immediate",
      state: "opening",
      callback: () => this.handleOpening(),
    });

    this.stateMachine.subscribe({
      timing: "immediate",
      state: "open",
      callback: (message) => this.handleOpen(message),
    });

    this.stateMachine.subscribe({
      timing: "immediate",
      state: "closing",
      callback: () => this.handleClosing(),
    });

    this.stateMachine.subscribe({
      timing: "immediate",
      state: "closed.pending",
      callback: () => this.handleClosedPending(),
    });

    this.stateMachine.subscribe({
      timing: "immediate",
      state: "closed.safe-to-unmount",
      callback: () => this.handleClosedSafeToUnmount(),
    });

    this.stateMachine.subscribe({
      timing: "before-paint",
      state: "closed.flushing-to-preparing-opening",
      callback: () => {
        this.timeoutManager.clear("pendingFlush");
        this.stateHelper.flushComplete();
      },
    });

    this.stateMachine.subscribe({
      timing: "before-paint",
      state: "closed.flushing-to-preparing-open",
      callback: () => {
        this.timeoutManager.clear("pendingFlush");
        this.stateHelper.flushComplete();
      },
    });

    this.stateMachine.subscribe({
      timing: "immediate",
      state: "preparing-open",
      callback: () => this.handlePreparingOpen(),
    });

    this.positionMachine.subscribe({
      timing: "immediate",
      state: "covered-going-down",
      callback: () => {
        this.stateHelper.goDown();
      },
    });

    this.positionMachine.subscribe({
      timing: "immediate",
      state: "covered-idle",
      callback: () => {
        if (
          this.stateHelper.isStagingIn("going-down") ||
          this.stateHelper.isStagingIn("go-down")
        ) {
          this.stateHelper.advanceStaging();
        }
      },
    });

    this.positionMachine.subscribe({
      timing: "immediate",
      state: "covered-going-up",
      callback: () => {
        this.stateHelper.goUp();
      },
    });

    this.positionMachine.subscribe({
      timing: "immediate",
      state: "covered-indeterminate",
      callback: () => {
        if (this.stateHelper.isStagingIn("going-up")) {
          this.stateHelper.advanceStaging();
        }

        const stackId = this.stackId;
        if (stackId && this.sheetStackRegistry) {
          const topmostSheet =
            this.sheetStackRegistry.getTopmostSheetInStack(stackId);
          if (topmostSheet === this) {
            this.stateHelper.gotoFrontIdle();
          } else {
            this.stateHelper.gotoCoveredIdle();
          }
        } else {
          this.stateHelper.gotoFrontIdle();
        }
      },
    });

    const stagingStates = [
      "none",
      "opening",
      "open",
      "stepping",
      "closing",
      "going-down",
      "go-down",
      "going-up",
    ];
    stagingStates.forEach((state) => {
      this.stagingMachine.subscribe({
        timing: "immediate",
        state,
        callback: () => this.updateStagingActiveAttribute(),
      });
    });
  }

  /**
   * Update staging-active attribute on the view element.
   *
   * @private
   */
  updateStagingActiveAttribute() {
    this.domAttributes?.updateStagingActive(this.staging);
  }

  /**
   * @type {boolean}
   */
  get isScrollTrapActive() {
    const trapValue = this.inertOutside ? true : this.swipeTrap;
    return trapValue !== false && trapValue !== null && trapValue !== "none";
  }

  /**
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

    if (typeof trapValue === "object") {
      const { x, y } = trapValue;
      if (x && y) {
        return "swipe-trap-both";
      }
    }

    return null;
  }

  /**
   * @type {boolean}
   */
  get effectiveThemeColorDimming() {
    if (this.themeColorDimming === "auto") {
      if (typeof navigator !== "undefined") {
        const ua = navigator.userAgent;
        const isWebKit =
          /Safari/.test(ua) && !/Chrome/.test(ua) && !/CriOS/.test(ua);
        return isWebKit;
      }
      return false;
    }
    return Boolean(this.themeColorDimming);
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
    const config = this.detentsConfig;
    if (config === null || config === undefined) {
      return ["var(--d-sheet-content-travel-axis)"];
    }
    if (typeof config === "string") {
      return [config, "var(--d-sheet-content-travel-axis)"];
    }
    return [...config, "var(--d-sheet-content-travel-axis)"];
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
   *
   * @type {boolean}
   */
  get swipeOutDisabled() {
    const swipeEnabled = this.swipe !== false;
    const browserSupported = Controller.browserSupportsRequiredFeatures;
    if (!(swipeEnabled && browserSupported)) {
      return false;
    }

    const dismissalDisabled =
      !this.swipeDismissal || this.role === "alertdialog";
    if (!dismissalDisabled) {
      return false;
    }

    const hasDetentsConfig =
      this.detentsConfig !== null && this.detentsConfig !== undefined;
    if (!hasDetentsConfig) {
      return false;
    }

    const isOpen = this.currentState === "open";
    const isNotClosing = !this.stagingMachine.matches("closing");
    return isOpen && isNotClosing;
  }

  /**
   * @type {boolean}
   */
  get edgeAlignedNoOvershoot() {
    return !this.isCenteredTrack && !this.swipeOvershoot;
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
   * Update the theme color via the theme color manager.
   *
   * @param {string} color - New theme color value
   */
  @action
  updateThemeColor(color) {
    this.themeColorManager?.updateThemeColor(this, color);
  }

  /**
   * Set the actual theme color based on current state.
   */
  @action
  setActualThemeColor() {
    this.themeColorManager?.setActualThemeColor(this);
  }

  /**
   * Register a theme color dimming overlay.
   *
   * @param {Object} overlay - Overlay configuration
   * @returns {Object|undefined} Registered overlay handle
   */
  @action
  registerThemeColorDimmingOverlay(overlay) {
    return this.themeColorManager?.registerThemeColorDimmingOverlay(
      this,
      overlay
    );
  }

  /**
   * Release ownership of the theme color.
   */
  @action
  releaseThemeColorOwnership() {
    this.themeColorManager?.releaseThemeColorOwnership(this);
  }

  /**
   * Capture the theme color from the content element.
   */
  captureContentThemeColor() {
    this.themeColorManager?.captureContentThemeColor(this);
  }

  /**
   * Update travel status and notify callback.
   *
   * @param {string} status - "idleOutside", "idleInside", "travellingIn", "travellingOut", "stepping"
   */
  @action
  updateTravelStatus(status) {
    if (this.travelStatus !== status) {
      this.travelStatus = status;
      this.safeToUnmount = status === "idleOutside";

      this.updateAnimationActiveAttribute(status);
      this.handleStackingStateChange(status);

      if (status === "travellingOut" && !this.closingWithoutAnimation) {
        this.animateBackdrop("out");
      }

      this.onTravelStatusChange?.(status);
    }
  }

  /**
   * @param {string} status
   * @private
   */
  updateAnimationActiveAttribute(status) {
    const isAnimating =
      status === "travellingIn" ||
      status === "travellingOut" ||
      status === "stepping";
    this.domAttributes?.updateAnimationActive(isAnimating);
  }

  /**
   * Handle stacking state changes based on travel status.
   *
   * @param {string} status
   * @private
   */
  handleStackingStateChange(status) {
    this.stackingAdapter?.handleTravelStatusChange(
      status,
      this.previousTravelStatus
    );
  }

  /**
   * Update travel range and notify callback.
   *
   * @param {number} start
   * @param {number} end
   */
  @action
  updateTravelRange(start, end) {
    if (this.travelRange.start !== start || this.travelRange.end !== end) {
      this.travelRange = { start, end };
      this.onTravelRangeChange?.(this.travelRange);
    }
  }

  /**
   * Notify onTravel callback with current progress.
   *
   * @param {number} progress
   */
  @action
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
   *
   * @type {string}
   */
  get openness() {
    const state = this.stateMachine.current;

    if (state === "open") {
      return "open";
    } else if (state === "closing") {
      return "closing";
    } else if (
      state === "opening" ||
      state === "preparing-opening" ||
      state === "preparing-open"
    ) {
      return "opening";
    } else {
      return "closed";
    }
  }

  /**
   * @type {string}
   */
  get staging() {
    return this.stagingMachine.current;
  }

  /**
   * @type {boolean}
   */
  get isFocusable() {
    return this.nativeFocusScrollPrevention;
  }

  /**
   * @type {boolean}
   */
  get isStagingActive() {
    return this.staging !== "none";
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
      const [start, end] = segment;
      const prevStart = prevSegment?.[0];
      const prevEnd = prevSegment?.[1];
      const lastDetent = this.dimensions?.detentMarkers?.length ?? 1;

      if (start !== prevStart || end !== prevEnd) {
        if (start === 1 && end === 1) {
          this.backStuck = true;

          if (
            this.edgeAlignedNoOvershoot &&
            this.snapToEndDetentsAcceleration === "auto" &&
            this.stateMachine.matches("open.scroll.ended") &&
            !this.stateMachine.matches("open.swipe.ongoing") &&
            this.currentState === "open"
          ) {
            this.stepToStuckPosition("back");
          }
        } else if (start === lastDetent && end === lastDetent) {
          this.frontStuck = true;

          if (
            this.edgeAlignedNoOvershoot &&
            this.snapToEndDetentsAcceleration === "auto" &&
            this.stateMachine.matches("open.scroll.ended") &&
            !this.stateMachine.matches("open.swipe.ongoing") &&
            this.currentState === "open"
          ) {
            this.stepToStuckPosition("front");
          }
        } else {
          if (this.frontStuck) {
            this.frontStuck = false;
          }
          if (this.backStuck) {
            this.backStuck = false;
          }
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
   * Set whether a programmatic scroll is ongoing.
   *
   * @param {boolean} value - Whether programmatic scroll is active
   */
  @action
  setProgrammaticScrollOngoing(value) {
    this.programmaticScrollOngoing = value;
  }

  /**
   * Handle a state transition message via the state helper.
   *
   * @param {string|Object} message - State transition message
   */
  @action
  handleStateTransition(message) {
    this.stateHelper.send(message);
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
    this.focusManagement?.capturePreviouslyFocusedElement();
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
    this.focusManagement?.capturePreviouslyFocusedElement();
  }

  /**
   * Handle the opening state.
   * Begins enter animation and notifies parent sheet.
   *
   * @private
   */
  handleOpening() {
    this.stateHelper.beginEnterAnimation(false);
    this.stackingAdapter?.notifyParentOfOpening(false);
  }

  /**
   * Handle the open state.
   * Sets up scroll behavior, focus, and intersection observer.
   *
   * @param {Object} message - State transition message
   * @private
   */
  handleOpen(message) {
    this.updateScrollSnapBehavior();
    this.updateTravelRange(this.activeDetent, this.activeDetent);
    this.updateTravelStatus("idleInside");
    this.applyInertOutside();
    this.setupFocusScrollPrevention();
    this.executeAutoFocusOnPresent();

    // TODO - is this necessary?
    // this.scrollContainer?.focus({ preventScroll: true });

    if (this.stateHelper.isStagingIn("opening")) {
      this.stateHelper.advanceStaging();
    }

    if (!this.swipeOutDisabled) {
      requestAnimationFrame(() => {
        if (this.currentState === "open" && !this.swipeOutDisabled) {
          this.setupIntersectionObserver();
        }
      });
    }

    if (message && message.type === "STEP") {
      this.handleStepMessage(message);
    }
  }

  /**
   * Handle a STEP message to animate to a new detent.
   *
   * @param {Object} message - Message with optional detent property
   * @private
   */
  handleStepMessage(message) {
    this.stateHelper.actuallyStep();
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
    this.stateHelper.beginExitAnimation(false);
    this.updateTravelStatus("travellingOut");
    this.stackingAdapter?.notifyParentOfClosing();

    if (this.closingWithoutAnimation) {
      this.handleClosingWithoutAnimation();
      return;
    }

    this.domAttributes?.disableScrollSnap();
    this.animationTravel.animateToDetent(
      0,
      this.animationTravel.exitingAnimationConfig
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
   * Schedules flush to safe-to-unmount.
   *
   * @private
   */
  handleClosedPending() {
    if (this.closingWithoutAnimation) {
      this.stateHelper.beginClosingImmediate(true);
      // Call updateTravelStatus BEFORE resetting the flag so animateBackdrop
      // can check it and skip the animation for swipe-out dismissal
      this.updateTravelStatus("travellingOut");
      this.closingWithoutAnimation = false;
      this.stateHelper.goOut();
      this.stackingAdapter?.notifyParentOfClosingImmediate();

      const tween = createTweenFunction(0);
      this.stackingAdapter?.notifyBelowSheets(0, tween);
    }

    this.timeoutManager.schedule(
      "pendingFlush",
      () => {
        if (this.stateHelper.matchesClosedPending()) {
          this.stateHelper.flushComplete();
        }
      },
      16
    );
  }

  /**
   * Handle the closed.safe-to-unmount state.
   * Performs final cleanup and resets state.
   *
   * @private
   */
  handleClosedSafeToUnmount() {
    this.isPresented = false;
    this.needsInitialScroll = true;
    this.viewHiddenByObserver = false;
    this.frontStuck = false;
    this.backStuck = false;

    this.cleanup();
    this.executeAutoFocusOnDismiss();

    this.activeDetent = 0;
    this.currentSegment = [0, 0];
    this.dimensions = null;

    if (this.stateHelper.position !== "out") {
      if (this.stateHelper.isPositionFrontClosing()) {
        this.stateHelper.advancePosition();
      }
    }

    this.updateTravelStatus("idleOutside");
    this.updateTravelRange(0, 0);
  }

  /**
   * Calculate dimensions if all required elements are ready.
   * Triggers dimension calculation and initial animation.
   */
  @action
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
        this.domAttributes?.setHidden();

        requestAnimationFrame(() => {
          this.handleStateTransition({ type: "PREPARED" });
          if (this.backdrop && this.travelStatus === "travellingIn") {
            this.animateBackdrop("in");
          }
          this.animationTravel.animateToDetent(this.targetDetent);
        });
      }
    }
  }

  /**
   * Set the initial scroll position based on track direction.
   */
  @action
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
  @action
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
  @action
  setupIntersectionObserver() {
    this.observerManager?.setupIntersectionObserver();
  }

  /**
   * Clean up the intersection observer.
   */
  @action
  cleanupIntersectionObserver() {
    this.observerManager?.cleanupIntersectionObserver();
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
    this.observerManager?.setupResizeObserver(() => {
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
   * Full cleanup of all resources. Idempotent - safe to call multiple times.
   */
  @action
  cleanup() {
    this.timeoutManager?.cleanup();
    this.touchHandler?.detach();
    this.observerManager?.cleanup();
    this.releaseThemeColorOwnership();

    this.domAttributes?.cleanup();
    this.inertManagement?.cleanup();
    this.focusManagement?.cleanup();

    this.stateMachine.cleanup();
    this.stagingMachine.cleanup();
    this.positionMachine.cleanup();
    this.touchMachine.cleanup();
  }

  /**
   * Find the element to auto-focus on present.
   *
   * @returns {HTMLElement|null}
   */
  @action
  findAutoFocusTarget() {
    return this.focusManagement?.findAutoFocusTarget() ?? null;
  }

  /**
   * Execute auto-focus when the sheet is presented.
   */
  @action
  executeAutoFocusOnPresent() {
    this.focusManagement?.executeAutoFocusOnPresent();
  }

  /**
   * Execute auto-focus when the sheet is dismissed.
   */
  @action
  executeAutoFocusOnDismiss() {
    this.focusManagement?.executeAutoFocusOnDismiss();
  }

  /**
   * Set up focus scroll prevention.
   */
  @action
  setupFocusScrollPrevention() {
    this.focusManagement?.setupFocusScrollPrevention();
  }

  /**
   * Apply inert attribute to elements outside the sheet.
   */
  @action
  applyInertOutside() {
    this.inertManagement?.applyInertOutside();
    this.sheetRegistry?.updateInertOutside(this, this.inertOutside);
  }

  /**
   * Remove inert attribute from elements outside the sheet.
   */
  @action
  removeInertOutside() {
    this.inertManagement?.removeInertOutside();
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
    this.captureContentThemeColor();
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

    this.domAttributes?.enableScrollSnap();
  }

  /**
   * Handle scroll events to detect close gestures and update travel state.
   */
  @action
  handleScrollForClose() {
    if (!this.scrollContainer || !this.dimensions) {
      return;
    }

    if (this.programmaticScrollOngoing) {
      this.programmaticScrollOngoing = false;
      return;
    }

    if (this.currentState !== "open") {
      return;
    }

    this.stateHelper.scrollStart();

    this.timeoutManager.schedule(
      "scrollEnd",
      () => {
        this.stateHelper.scrollEnd();
      },
      90
    );

    const scrollTop = this.scrollContainer.scrollTop;
    const contentSize = this.dimensions.content?.travelAxis?.unitless ?? 1;
    const snapAccelerator =
      this.dimensions.snapOutAccelerator?.travelAxis?.unitless ?? 0;

    const firstDetentProgress =
      this.swipeOutDisabled && this.detentsConfig !== undefined
        ? (this.dimensions.progressValueAtDetents?.[1]?.exact ?? 0)
        : 0;

    const rawProgress = (scrollTop - snapAccelerator) / contentSize;

    const clampedProgress = Math.max(
      firstDetentProgress,
      Math.min(1, rawProgress)
    );

    const stackingProgress = Math.max(0, Math.min(1, rawProgress));

    this.aggregatedTravelCallback(clampedProgress);

    this.travelProgress = stackingProgress;
    this.onTravelProgressChange?.(stackingProgress);

    const tween = createTweenFunction(stackingProgress);
    this.belowSheetsInStack.forEach((belowSheet) => {
      belowSheet.aggregatedStackingCallback(stackingProgress, tween);
    });

    this.notifyTravel(clampedProgress);

    if (this.dimensions?.progressValueAtDetents) {
      const detents = this.dimensions.progressValueAtDetents;
      const n = detents.length;

      let segmentProgress;
      if (this.dimensions.swipeOutDisabledWithDetent) {
        const firstMarkerSize =
          this.dimensions.detentMarkers[0]?.travelAxis?.unitless ?? 0;
        const edgePadding = this.dimensions.frontSpacerEdgePadding ?? 0;
        const scrollOffset = firstMarkerSize - edgePadding;
        segmentProgress = (scrollTop + scrollOffset) / contentSize;
      } else {
        segmentProgress = rawProgress;
      }

      if (segmentProgress <= 0) {
        this.setSegment([0, 0]);
        return;
      }

      for (let i = 0; i < n; i++) {
        const detent = detents[i];
        const after = detent.after;
        if (
          segmentProgress > after &&
          i + 1 < n &&
          segmentProgress < detents[i + 1].before
        ) {
          this.setSegment([i, i + 1]);
          break;
        } else if (segmentProgress > detent.before && segmentProgress < after) {
          this.setSegment([i, i]);
          break;
        }
      }
    }

    if (
      this.detentsConfig === undefined &&
      scrollTop <= 0 &&
      this.isPresented &&
      this.currentState === "open"
    ) {
      this.domAttributes?.disableScrollSnap();
      this.closingWithoutAnimation = true;
      requestAnimationFrame(() => {
        this.handleStateTransition("SWIPE_OUT");
      });
      return;
    }
  }

  /**
   * Handle touchstart events on scroll-container.
   */
  @action
  handleTouchStart() {
    this.touchMachine.send("TOUCH_START");
    this.touchHandler?.handleScrollStart();
  }

  /**
   * Handle touchend events on scroll-container.
   */
  @action
  handleTouchEnd() {
    this.touchMachine.send("TOUCH_END");
    this.touchHandler?.handleTouchEnd();
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
   */
  @action
  onTouchGestureStart() {
    this.stateHelper.swipeStart();
  }

  /**
   * Handle touch gesture end.
   * May trigger step to stuck position if needed.
   */
  @action
  onTouchGestureEnd() {
    this.stateHelper.swipeEnd();

    if (
      this.edgeAlignedNoOvershoot &&
      this.snapToEndDetentsAcceleration === "auto" &&
      this.currentState === "open" &&
      this.stateHelper.matchesScrollEnded()
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
  @action
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
   *
   * @param {HTMLElement} backdrop
   * @param {Object} travelAnimation
   * @param {Array|Function} travelAnimation.opacity - Opacity config
   */
  @action
  registerBackdrop(backdrop, travelAnimation = null) {
    this.backdrop = backdrop;
    backdrop.style.opacity = 0;
    backdrop.style.willChange = "opacity";

    // Check if opacity is explicitly disabled via { opacity: null }
    const isDisabled =
      travelAnimation &&
      typeof travelAnimation === "object" &&
      travelAnimation.opacity === null;

    if (isDisabled) {
      return;
    }

    const opacityFn =
      typeof travelAnimation === "function"
        ? travelAnimation
        : typeof travelAnimation?.opacity === "function"
          ? travelAnimation.opacity
          : ({ progress }) => Math.min(progress * 0.33, 0.33);

    this.backdropOpacityFn = opacityFn;

    this.travelAnimations.push({
      target: backdrop,
      callback: (progress) => {
        if (
          this.travelStatus === "travellingIn" ||
          this.travelStatus === "travellingOut"
        ) {
          return;
        }

        const opacity = opacityFn({ progress });
        backdrop.style.opacity = opacity;

        if (this.themeColorDimmingOverlay) {
          this.themeColorDimmingOverlay.updateAlpha(opacity);
        }
      },
    });

    this.animateBackdrop("out");

    if (this.effectiveThemeColorDimming) {
      const computedStyle = window.getComputedStyle(backdrop);
      const backgroundColor = computedStyle.backgroundColor || "rgb(0, 0, 0)";

      this.themeColorDimmingOverlay = this.registerThemeColorDimmingOverlay({
        color: backgroundColor,
        alpha: 0,
      });
    }
  }

  /**
   * Animate the backdrop using Web Animations API.
   * Called when travel status changes to travellingIn or travellingOut.
   *
   * @param {string} direction - "in" or "out"
   * @param {number} duration - Animation duration in ms
   * @private
   */
  animateBackdrop(direction, duration = 500) {
    if (!this.backdrop || !this.backdropOpacityFn) {
      return;
    }

    let keyframes;
    if (direction === "in") {
      // Animate to the target detent's opacity
      const targetProgress =
        this.dimensions?.progressValueAtDetents?.[this.targetDetent]?.exact ??
        1;
      const targetOpacity = this.backdropOpacityFn({
        progress: targetProgress,
      });
      keyframes = [{ opacity: 0 }, { opacity: targetOpacity }];
    } else {
      // Animate from current opacity to 0
      const currentOpacity = parseFloat(this.backdrop.style.opacity) || 0;
      keyframes = [{ opacity: currentOpacity }, { opacity: 0 }];
    }

    this.backdropAnimation?.cancel();

    const animation = this.backdrop.animate(keyframes, {
      duration,
      easing: "cubic-bezier(0.25, 0.1, 0.25, 1)",
      fill: "forwards",
    });

    animation.onfinish = () => {
      if (direction === "in" && this.backdrop?.isConnected) {
        animation.commitStyles();
      }
      animation.cancel();
    };

    this.backdropAnimation = animation;

    if (this.themeColorDimmingOverlay) {
      // keyframes[1] is always the target (end) opacity
      this.themeColorDimmingOverlay.animateTo(keyframes[1].opacity, duration);
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
   * @param {string|Object} message
   * @param {Object} context
   */
  @action
  sendToPositionMachine(message, context = {}) {
    return this.stateHelper.sendToPosition(message, context);
  }

  /**
   * Notify parent sheet's position machine when this sheet's position machine transitions via NEXT.
   *
   * @private
   */
  notifyParentPositionMachineNext() {
    this.stackingAdapter?.notifyParentPositionMachineNext();
  }

  /**
   * Step to the next detent.
   */
  @action
  step() {
    if (this.currentState !== "open") {
      return;
    }

    const nextDetent = this.activeDetent + 1;
    const maxDetent = this.detents?.length ?? 1;

    if (nextDetent > maxDetent) {
      return;
    }

    this.handleStateTransition({ type: "STEP", detent: nextDetent });
  }

  /**
   * Reset view styles to default state.
   */
  @action
  resetViewStyles() {
    this.domAttributes?.resetViewStyles();
    this.viewHiddenByObserver = false;
  }

  /**
   * Updates the scroll lock state via the sheet registry.
   *
   * @param {boolean} shouldLock
   */
  @action
  updateScrollLock(shouldLock) {
    this.sheetRegistry?.updateScrollLock(this, shouldLock);
  }
}
