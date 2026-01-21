import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { next } from "@ember/runloop";
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
import ObserverManager from "./observer-manager";
import ScrollProgressCalculator from "./scroll-progress-calculator";
import StackingAdapter from "./stacking-adapter";
import StateHelper from "./state-helper";
import StateMachine from "./state-machine";
import StateMachineGroup from "./state-machine-group";
import {
  GUARDS,
  SHEET_MACHINES,
  POSITION_MACHINES,
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
   * @returns {boolean} Whether required features are supported
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
  @tracked isScrollOngoing = false;

  /** @type {Array|null} */
  @tracked detentsConfig = null;

  /** @type {boolean} */
  @tracked swipeOvershoot = true;

  /** @type {boolean} */
  @tracked backdropSwipeable = true;

  /** @type {boolean} */
  @tracked inertOutside = true;

  /**
   * Whether a long-running operation (like animation) is in progress.
   *
   * @type {boolean}
   */
  @tracked longRunning = false;

  /**
   * Current staging phase of the sheet animation.
   * Values: "none", "opening", "open", "stepping", "closing"
   *
   * @type {string}
   */
  @tracked staging = "none";

  /** @type {TrackedArray<HTMLElement>} */
  detentMarkers = new TrackedArray();

  /** @type {string} */
  id = guidFor(this);

  /** @type {boolean} */
  viewHiddenByObserver = false;

  /** @type {boolean} */
  closingWithoutAnimation = false;

  /** @type {string} */
  contentPlacement = "bottom";

  /** @type {StateMachineGroup} */
  sheetMachines = new StateMachineGroup(SHEET_MACHINES, { guards: GUARDS });

  /** @type {StateMachineGroup} */
  positionMachines = new StateMachineGroup(POSITION_MACHINES, { guards: GUARDS });

  // Convenience accessors for backward compatibility
  get stateMachine() {
    return this.sheetMachines.getMachine("openness");
  }

  get animationStateMachine() {
    return this.sheetMachines.getMachine("staging");
  }

  get positionMachine() {
    return this.positionMachines.getMachine("position");
  }

  get touchMachine() {
    return this.sheetMachines.getMachine("scrollContainerTouch");
  }

  get longRunningMachine() {
    return this.sheetMachines.getMachine("longRunning");
  }

  get skipOpeningMachine() {
    return this.sheetMachines.getMachine("skipOpening");
  }

  get skipClosingMachine() {
    return this.sheetMachines.getMachine("skipClosing");
  }

  get backStuckMachine() {
    return this.sheetMachines.getMachine("backStuck");
  }

  get frontStuckMachine() {
    return this.sheetMachines.getMachine("frontStuck");
  }

  get elementsReadyMachine() {
    return this.sheetMachines.getMachine("elementsReady");
  }

  /** @type {boolean} */
  isSwipeOngoing = false;

  /** @type {boolean} */
  isMoveOngoing = false;

  /** @type {boolean} */
  frontStuck = false;

  /** @type {boolean} */
  backStuck = false;

  /** @type {number|null} */
  lastScrollTop = null;

  /** @type {Object|null} */
  dimensions = null;

  /** @type {number} */
  activeDetent = 0;

  /** @type {number} */
  targetDetent = 1;

  /** @type {Array<number>} */
  currentSegment = [0, 0];

  /** @type {number} */
  travelProgress = 0;

  /** @type {string} */
  travelStatus = "idleOutside";

  /** @type {string} */
  previousTravelStatus = "idleOutside";

  /** @type {{start: number, end: number}} */
  travelRange = { start: 0, end: 0 };

  /** @type {number|null} */
  lastProcessedProgress = null;

  /**
   * Progress smoother function initialized when interaction begins.
   * Prevents large jumps in progress values.
   *
   * @type {Function|null}
   */
  progressSmoother = null;

  /** @type {string} */
  role = "dialog";

  /** @type {string} */
  tracks = "bottom";

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

  /** @type {Array<Controller>} */
  belowSheetsInStack = [];

  /** @type {number} */
  stackingIndex = -1;

  /** @type {string|null} */
  stackId = null;

  /** @type {number} */
  stackPosition = 0;

  /** @type {Object|null} */
  sheetStackRegistry = null;

  /** @type {Object|null} */
  sheetRegistry = null;

  /** @type {Object|null} */
  themeColorManager = null;

  /** @type {Array<Object>} */
  travelAnimations = [];

  /** @type {Array<Object>} */
  stackingAnimations = [];

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
  onSafeToUnmountChange = null;

  /** @type {Function|null} */
  onSwipeFromEdgeToGoBackAttempt = null;

  /** @type {FocusManagement|null} */
  focusManagement = null;

  /**
   * Subscription definitions for state machines.
   */
  #subscriptionDefinitions = [
    {
      machine: "animationStateMachine",
      state: "opening",
      timing: "after-paint",
      callback: () => {
        requestAnimationFrame(() => {
          this.stateMachine.send({
            type: "READY_TO_OPEN",
            skipOpening: false,
          });
        });
      },
    },
    {
      machine: "stateMachine",
      state: "opening",
      timing: "before-paint",
      handler: "handleOpening",
    },
    {
      machine: "elementsReadyMachine",
      state: "true",
      timing: "immediate",
      guard: () => this.stateMachine.current === "opening",
      callback: () => this.#startOpeningAnimation(),
    },
    {
      machine: "stateMachine",
      state: "open",
      guard: () => {
        const msg = this.stateMachine.lastProcessedMessage;
        return ["NEXT", "PREPARED", "STEP", "READY_TO_OPEN"].includes(msg?.type);
      },
      callback: (message) => this.handleOpen(message),
    },
    { machine: "stateMachine", state: "closing", handler: "handleClosing" },
    {
      machine: "stateMachine",
      state: "closed.status:pending",
      handler: "handleClosedPending",
    },
    {
      machine: "stateMachine",
      state: "closed.status:safe-to-unmount",
      handler: "handleClosedSafeToUnmount",
    },
    {
      machine: "stateMachine",
      state: "closed.status:flushing-to-preparing-opening",
      timing: "before-paint",
      callback: () => {
        this.timeoutManager.clear("pendingFlush");
        this.stateMachine.send({
          machine: "openness:closed.status",
          type: "",
        });
      },
    },
    {
      machine: "stateMachine",
      state: "closed.status:flushing-to-preparing-open",
      timing: "before-paint",
      callback: () => {
        this.timeoutManager.clear("pendingFlush");
        this.stateMachine.send({
          machine: "openness:closed.status",
          type: "",
        });
      },
    },
    {
      machine: "stateMachine",
      state: "closed.status:preparing-opening",
      timing: "after-paint",
      callback: () => {
        this.animationStateMachine.send({
          type: "OPEN_PREPARED",
          skipOpening: false,
        });
      },
    },
    {
      machine: "stateMachine",
      state: "closed.status:preparing-open",
      timing: "after-paint",
      callback: () => {
        this.animationStateMachine.send({
          type: "OPEN_PREPARED",
          skipOpening: true,
        });
      },
    },
    {
      machine: "positionMachine",
      state: "covered.status:going-down",
      callback: () => this.stateHelper.goDown(),
    },
    {
      machine: "positionMachine",
      state: "covered.status:idle",
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
      state: "covered.status:going-up",
      callback: () => this.stateHelper.goUp(),
    },
    {
      machine: "positionMachine",
      state: "covered.status:indeterminate",
      callback: () => {
        if (this.stateHelper.isInAnimationState("going-up")) {
          this.stateHelper.advanceAnimation();
        }

        if (this.stateHelper.isPositionOut()) {
          this.stateHelper.goToFrontIdle();
        } else {
          this.stateHelper.goToCoveredIdle();
        }
      },
    },
    {
      machine: "stateMachine",
      state: "open.scroll:ongoing",
      guard: () => !this.isScrollOngoing,
      callback: () => {
        this.isScrollOngoing = true;
        const currentProgress =
          this.dimensions?.progressValueAtDetents?.[this.activeDetent]?.exact ??
          0;
        this.progressSmoother = this.createProgressSmoother(currentProgress);
      },
    },
    {
      machine: "stateMachine",
      state: "open.scroll:ended",
      guard: () => this.isScrollOngoing,
      callback: () => {
        this.isScrollOngoing = false;
      },
    },
    {
      machine: "stateMachine",
      state: "open.scroll:ongoing",
      type: "exit",
      callback: () => {
        this.isScrollOngoing = false;
      },
    },
    {
      machine: "stateMachine",
      state: "open.swipe:ongoing",
      guard: () => !this.isSwipeOngoing,
      callback: () => {
        this.isSwipeOngoing = true;
      },
    },
    {
      machine: "stateMachine",
      state: "open.swipe:ended",
      guard: () => this.isSwipeOngoing,
      callback: () => {
        this.isSwipeOngoing = false;
      },
    },
    {
      machine: "stateMachine",
      state: "open.swipe:ended",
      guard: () => typeof this.onTravelStatusChange === "function",
      callback: () => {
        if (this.stateHelper.isOpen) {
          this.onTravelStatusChange("idleInside");
        }
      },
    },
    {
      machine: "stateMachine",
      state: "open.swipe:ongoing",
      type: "exit",
      callback: () => {
        this.isSwipeOngoing = false;
      },
    },
    {
      machine: "stateMachine",
      state: "open.move:ongoing",
      guard: () => !this.isMoveOngoing,
      callback: () => {
        this.isMoveOngoing = true;
      },
    },
    {
      machine: "stateMachine",
      state: "open.move:ended",
      guard: () => this.isMoveOngoing,
      callback: () => {
        this.isMoveOngoing = false;
      },
    },
    {
      machine: "stateMachine",
      state: "open.move:ongoing",
      type: "exit",
      callback: () => {
        this.isMoveOngoing = false;
      },
    },
    {
      machine: "animationStateMachine",
      state: "none",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("none"),
    },
    {
      machine: "animationStateMachine",
      state: "opening",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("opening"),
    },
    {
      machine: "animationStateMachine",
      state: "open",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("open"),
    },
    {
      machine: "animationStateMachine",
      state: "stepping",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("stepping"),
    },
    {
      machine: "animationStateMachine",
      state: "closing",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("closing"),
    },
    {
      machine: "animationStateMachine",
      state: "go-down",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("go-down"),
    },
    {
      machine: "animationStateMachine",
      state: "going-down",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("going-down"),
    },
    {
      machine: "animationStateMachine",
      state: "going-up",
      timing: "immediate",
      callback: () => this.stackingAdapter?.updateStagingInStack("going-up"),
    },
  ];

  /**
   * Initialize the controller with helpers.
   * Use configure() to set options after construction.
   */
  constructor() {
    this.touchHandler = new TouchHandler(this);
    this.focusManagement = new FocusManagement(this);
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
      "nativeEdgeSwipePrevention",
      "onSwipeFromEdgeToGoBackAttempt",
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
          this[key] = { ...this[key], ...options[key] };
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
   * Get the staging attribute for CSS.
   *
   * @type {string|null}
   */
  get stagingAttribute() {
    return this.staging === "none" ? "staging-none" : null;
  }

  /**
   * Update travel status and notify callback.
   *
   * @param {string} status - "idleOutside", "idleInside", "travellingIn", "travellingOut", "stepping"
   */
  updateTravelStatus(status) {
    if (this.travelStatus !== status) {
      this.travelStatus = status;
      const newSafeToUnmount = status === "idleOutside";
      const safeToUnmountChanged = this.safeToUnmount !== newSafeToUnmount;
      this.safeToUnmount = newSafeToUnmount;

      if (safeToUnmountChanged) {
        this.onSafeToUnmountChange?.(newSafeToUnmount);
      }

      this.handleStackingStateChange(status);

      this.onTravelStatusChange?.(status);
    }
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

    if (state === "open") {
      return "open";
    }
    if (state === "closing") {
      return "closing";
    }
    if (state === "opening") {
      return "opening";
    }
    if (
      this.stateMachine.matches("closed.status:preparing-opening") ||
      this.stateMachine.matches("closed.status:preparing-open")
    ) {
      return "opening";
    }
    return "closed";
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
   * Merged staging state for the stack.
   * Returns "not-none" if ANY sheet in the stack has staging !== "none".
   *
   * @type {string}
   */
  get mergedStaging() {
    return this.stackingAdapter?.getMergedStaging() ?? "none";
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
   * @returns {boolean}
   */
  get isAnimating() {
    return this.animationState !== "none";
  }

  /**
   * Whether the scroll trap should be automatically disabled for performance optimization.
   * Currently used to apply the scroll-trap-optimised class for CSS performance.
   *
   * @returns {boolean}
   */
  get isAutomaticallyDisabledForOptimisation() {
    return true;
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
   * Handle the opening state.
   * Starts the enter animation and sends NEXT when complete.
   * If elements aren't ready yet (tracked via elementsReady state machine),
   * defers animation until ELEMENTS_REGISTERED is sent.
   *
   * @private
   */
  handleOpening() {
    this.isPresented = true;
    this.staging = "opening";
    this.updateTravelStatus("travellingIn");
    this.focusManagement.capturePreviouslyFocusedElement();

    this.longRunningMachine.send("TO_TRUE");
    this.longRunning = true;
    this.stateHelper.beginEnterAnimation(false);
    this.stackingAdapter.notifyParentOfOpening(false);

    if (this.elementsReadyMachine.current === "true") {
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
      this.elementsReadyMachine.current === "false"
    ) {
      // Defer to next run loop to avoid updating tracked state during render
      next(() => {
        if (this.elementsReadyMachine.current === "false") {
          this.elementsReadyMachine.send("ELEMENTS_REGISTERED");
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
    // Mark longRunning as false when opening animation completes
    if (this.longRunningMachine.current === "true") {
      this.longRunningMachine.send("TO_FALSE");
      this.longRunning = false;
    }

    // Set staging to "none" (idle) when open, unless stepping
    if (message?.type !== "STEP") {
      this.staging = "none";
    }

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
    this.staging = "stepping";
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
    this.staging = "closing";

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

    this.stackingAdapter.notifyBelowSheets(0);

    requestAnimationFrame(() => {
      this.handleStateTransition({ type: "NEXT" });
    });
  }

  /**
   * Handle the closed.pending state.
   * Handles immediate close if needed, then schedules flush to safe-to-unmount.
   */
  handleClosedPending() {
    this.longRunningMachine.send("TO_FALSE");
    this.longRunning = false;
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

    this.stackingAdapter.notifyBelowSheets(0);
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
    const wasLongRunning = this.stateHelper.isLongRunning();

    // Reset presentation flags
    this.isPresented = false;
    this.needsInitialScroll = true;
    this.viewHiddenByObserver = false;
    this.frontStuck = false;
    this.backStuck = false;
    this.isScrollOngoing = false;

    if (wasLongRunning) {
      this.longRunningMachine.send("TO_FALSE");
      this.longRunning = false;
    }

    this.staging = "none";

    // Reset elementsReady state machine for next open cycle
    if (this.elementsReadyMachine.current === "true") {
      this.elementsReadyMachine.send("RESET");
    }

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
    this.themeColorAdapter.cleanup();
    this.domAttributes.cleanup();
    this.focusManagement.cleanup();
    this.stateMachine.cleanup();
    this.animationStateMachine.cleanup();
    this.positionMachine.cleanup();
    this.touchMachine.cleanup();
    this.longRunningMachine.cleanup();
    this.stackingAdapter?.removeStagingFromStack();
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
    this.sheetRegistry?.updateInertOutside(this, this.inertOutside);
  }

  /**
   * Remove inert attribute from elements outside the sheet.
   */
  removeInertOutside() {
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

    if (this.tracks === "bottom") {
      this.needsInitialScroll = true;
    }

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
    if (this.currentState !== "open" || this.staging !== "none") {
      return;
    }

    if (!this.scrollContainer || !this.dimensions) {
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
  }

  /**
   * Process a single scroll frame - called by RAF loop.
   */
  @action
  processScrollFrame() {
    if (this.currentState !== "open") {
      return;
    }

    if (!this.scrollContainer || !this.dimensions) {
      return;
    }

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

    const { clampedProgress, stackingProgress, segmentProgress } = progress;

    const smoothedProgress = this.progressSmoother
      ? this.progressSmoother(clampedProgress)
      : clampedProgress;

    if (this.lastProcessedProgress === smoothedProgress) {
      return;
    }

    this.lastProcessedProgress = smoothedProgress;

    this.aggregatedTravelCallback(smoothedProgress);

    this.travelProgress = stackingProgress;
    this.onTravelProgressChange?.(stackingProgress);

    this.stackingAdapter.notifyBelowSheets(stackingProgress);

    this.notifyTravel(smoothedProgress);

    const segment =
      this.scrollProgressCalculator.determineSegment(segmentProgress);
    if (segment) {
      this.setSegment(segment);
      if (segment[0] === 0 && segment[1] === 0 && segmentProgress <= 0) {
        return;
      }
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
      this.stateHelper.isOpen &&
      this.stateHelper.isScrollEnded()
    ) {
      this.timeoutManager.schedule(
        "stuckPosition",
        () => {
          requestAnimationFrame(() => {
            if (this.stateHelper.isOpen) {
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
    this.sheetMachines.send({ type: "OPEN" });
  }

  /**
   * Close the sheet.
   */
  @action
  close() {
    this.handleStateTransition({ type: "READY_TO_CLOSE" });
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
    if (this.currentState !== "open") {
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
