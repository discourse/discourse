import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { next, schedule } from "@ember/runloop";
import { processBehavior } from "discourse/float-kit/lib/behavior-handler";
import { capabilities } from "discourse/services/capabilities";
import { createTweenFunction } from "./animation";
import AnimationTravel from "./animation-travel";
import {
  placementToAttribute,
  resolveTracksAndPlacement,
} from "./config-normalizer";
import DetentManager from "./detent-manager";
import DimensionCalculator from "./dimensions-calculator";
import DOMAttributes from "./dom-attributes";
import FocusManagement from "./focus-management";
import ObserverManager from "./observer-manager";
import ScrollProgressCalculator from "./scroll-progress-calculator";
import StackingAdapter from "./stacking-adapter";
import { buildStateEffects } from "./state-effects";
import StateHelper from "./state-helper";
import { EVENTS } from "./state-machine-events";
import TimeoutManager from "./timeout-manager";
import { resolveTravelTrack } from "./travel";

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

const CONFIGURATION_SKIP_STATE_SYNC = "configurationSkipStateSync";

const RENDER_AFFECTING_OPTIONS = new Set([
  "contentPlacement",
  "role",
  "snapOutAcceleration",
  "snapToEndDetentsAcceleration",
  "tracks",
  "swipe",
  "swipeDismissal",
  "swipeOvershoot",
  "swipeTrap",
  "nativeFocusScrollPrevention",
  "inertOutside",
]);

const DIMENSION_AFFECTING_OPTIONS = new Set([
  "contentPlacement",
  "role",
  "snapOutAcceleration",
  "snapToEndDetentsAcceleration",
  "swipe",
  "swipeDismissal",
  "swipeOvershoot",
  "tracks",
]);

const OPPOSITE_TRACK_AXES = Object.freeze({
  "bottom:top": "vertical",
  "left:right": "horizontal",
  "right:left": "horizontal",
  "top:bottom": "vertical",
});

const STAGING_STATE_BY_ANIMATION_OPTION = Object.freeze({
  enteringAnimationSettings: "isOpening",
  exitingAnimationSettings: "isClosing",
});

const WEBKIT_SMALL_SPACER_TRANSFORMS = Object.freeze({
  bottom: "translateY(-2px)",
  horizontal: "translateX(-2px)",
  left: "translateX(2px)",
  right: "translateX(-2px)",
  top: "translateY(2px)",
  vertical: "translateY(-2px)",
});

export default class Controller {
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

  static OPTION_DEFAULTS = {
    contentPlacement: "bottom",
    role: undefined,
    swipe: true,
    swipeDismissal: true,
    swipeOvershoot: true,
    swipeTrap: undefined,
    onFocusInside: null,
    nativeFocusScrollPrevention: true,
    inertOutside: true,
    enteringAnimationSettings: null,
    exitingAnimationSettings: null,
    steppingAnimationSettings: null,
    snapOutAcceleration: "auto",
    snapToEndDetentsAcceleration: "auto",
    onTravelStatusChange: null,
    onTravelRangeChange: null,
    onTravel: null,
    onTravelStart: null,
    onTravelEnd: null,
    sheetStackRegistry: null,
    sheetRegistry: null,
    tracks: "bottom",
  };

  static get browserSupportsRequiredFeatures() {
    return BROWSER_SUPPORTS_REQUIRED_FEATURES;
  }

  @tracked titleElement = null;
  @tracked descriptionElement = null;
  @tracked bleedingBackgroundPresent = false;
  @tracked isPresented = false;
  @tracked safeToUnmount = true;
  @tracked detentsConfig = null;
  @tracked backdropSwipeable = true;
  @tracked configurationVersion = 0;

  view = null;
  content = null;
  contentWrapper = null;
  scrollContainer = null;
  backdrop = null;
  rootElement = null;
  detentMarkers = [];
  id = guidFor(this);

  dimensions = null;
  activeDetent = 0;
  targetDetent = 1;
  currentSegment = [0, 0];
  travelStatus = "idleOutside";
  previousTravelStatus = "idleOutside";
  travelRange = { start: 0, end: 0 };
  lastProcessedProgress = null;
  progressSmoother = null;
  enteringAnimationSettings = null;
  exitingAnimationSettings = null;
  steppingAnimationSettings = null;
  snapOutAcceleration = "auto";
  snapToEndDetentsAcceleration = "auto";
  onClickOutside = {
    dismiss: true,
    stopOverlayPropagation: true,
  };
  onEscapeKeyDown = {
    nativePreventDefault: true,
    dismiss: true,
    stopOverlayPropagation: true,
  };
  onPresentAutoFocus = { focus: true };
  onDismissAutoFocus = { focus: true };
  belowSheetsInStack = [];
  stackingIndex = -1;
  stackId = null;
  coveredCount = 0;
  sheetStackRegistry = null;
  sheetRegistry = null;
  travelAnimations = [];
  stackingAnimations = [];
  onTravelStatusChange = null;
  onTravelRangeChange = null;
  onTravel = null;
  onTravelStart = null;
  onTravelEnd = null;
  onActiveDetentChange = null;
  onSafeToUnmountChange = null;
  onFocusInside = null;
  focusManagement = null;
  timeoutManager;
  detentManager;
  domAttributes;
  observerManager;
  scrollProgressCalculator;
  stackingAdapter;
  state;
  animationTravel;
  rootComponent = null;
  isDestroying = false;
  isDestroyed = false;
  markProgrammaticScroll = () => {
    this.#programmaticScrollPending = true;
  };
  #activeDetentConfigurationInitialized = false;
  #configurationVersionBumpScheduled = false;
  #controlledActiveDetent;
  #defaultActiveDetent;
  #dimensionRecalculationPending = false;
  #dimensionRecalculationScheduled = false;
  #dimensionsTrack = null;
  #initialControlledActiveDetent = null;
  #manualTravelOngoing = false;
  #programmaticDetent = null;
  #pendingStepMessage = null;
  #programmaticScrollPending = false;
  #progressBeforeDimensionRecalculation = null;
  #renderConfigurationPending = false;
  #scrollOccurredSinceClosed = false;
  #trackDimensionRecalculationScheduled = false;
  #webkitSmallSpacerTransformApplied = false;
  #contentPlacement = "bottom";
  #inertOutside = true;
  #nativeFocusScrollPrevention = true;
  #role;
  #subscriptionDefinitions = [];
  #swipe = true;
  #swipeDismissal = true;
  #swipeOvershoot = true;
  #swipeTrap;
  #tracks = "bottom";

  constructor() {
    this.focusManagement = new FocusManagement(this);
    this.timeoutManager = new TimeoutManager();
    this.detentManager = new DetentManager(this);
    this.domAttributes = new DOMAttributes(this);
    this.observerManager = new ObserverManager(this);
    this.scrollProgressCalculator = new ScrollProgressCalculator(this);
    this.stackingAdapter = new StackingAdapter(this);
    this.state = new StateHelper();
    this.animationTravel = new AnimationTravel(this);
    this.animationTravel.syncSkipStates();
    this.#subscriptionDefinitions = buildStateEffects(this);
    this.setupSubscriptions();
  }

  get contentPlacement() {
    this.configurationVersion;
    return this.#contentPlacement;
  }

  set contentPlacement(value) {
    this.#contentPlacement = value;
  }

  get role() {
    this.configurationVersion;
    return this.#role;
  }

  set role(value) {
    this.#role = value;
  }

  get tracks() {
    this.configurationVersion;

    let animationTrack;
    if (this.state?.staging.isOpening) {
      animationTrack = this.enteringAnimationSettings?.track;
    } else if (this.state?.staging.isClosing) {
      animationTrack = this.exitingAnimationSettings?.track;
    }

    return (
      OPPOSITE_TRACK_AXES[`${this.#tracks}:${animationTrack}`] ?? this.#tracks
    );
  }

  set tracks(value) {
    this.#tracks = value;
  }

  get swipe() {
    this.configurationVersion;
    return this.#swipe;
  }

  set swipe(value) {
    this.#swipe = value;
  }

  get swipeDismissal() {
    this.configurationVersion;
    return this.#swipeDismissal;
  }

  set swipeDismissal(value) {
    this.#swipeDismissal = value;
  }

  get swipeOvershoot() {
    this.configurationVersion;
    return this.#swipeOvershoot;
  }

  set swipeOvershoot(value) {
    this.#swipeOvershoot = value;
  }

  get swipeTrap() {
    this.configurationVersion;
    return this.#swipeTrap;
  }

  set swipeTrap(value) {
    this.#swipeTrap = value;
  }

  get nativeFocusScrollPrevention() {
    this.configurationVersion;
    return this.#nativeFocusScrollPrevention;
  }

  set nativeFocusScrollPrevention(value) {
    this.#nativeFocusScrollPrevention = value;
  }

  get inertOutside() {
    this.configurationVersion;
    return this.#inertOutside;
  }

  set inertOutside(value) {
    this.#inertOutside = value;
  }

  configure(options = {}) {
    let animationSettingsChanged = false;
    let configurationChanged = false;
    let dimensionsChanged = false;
    let inertOutsideChanged = false;
    const assignConfig = (key, value) => {
      const currentValue = key === "tracks" ? this.#tracks : this[key];
      const stagingState = STAGING_STATE_BY_ANIMATION_OPTION[key];
      const stagingTrackChanged =
        stagingState &&
        this.state.staging[stagingState] &&
        currentValue?.track !== value?.track;

      if (currentValue !== value) {
        this[key] = value;
        if (stagingState) {
          animationSettingsChanged = true;
        }
        if (key === "inertOutside") {
          inertOutsideChanged = true;
        }
        if (RENDER_AFFECTING_OPTIONS.has(key) || stagingTrackChanged) {
          configurationChanged = true;
        }
        if (DIMENSION_AFFECTING_OPTIONS.has(key) || stagingTrackChanged) {
          dimensionsChanged = true;
        }
      }
    };

    if ("role" in options) {
      assignConfig(
        "role",
        options.role === undefined
          ? Controller.OPTION_DEFAULTS.role
          : options.role
      );
    }

    if ("activeDetent" in options || "defaultActiveDetent" in options) {
      this.#configureActiveDetent(options);
    }

    if ("onActiveDetentChange" in options) {
      this.onActiveDetentChange = options.onActiveDetentChange ?? null;
    }

    if ("onSafeToUnmountChange" in options) {
      this.onSafeToUnmountChange = options.onSafeToUnmountChange ?? null;
    }

    if ("detents" in options) {
      if (this.#assignDetents(options.detents)) {
        configurationChanged = true;
        dimensionsChanged = true;
      }
    }

    if ("tracks" in options || "contentPlacement" in options) {
      const result = resolveTracksAndPlacement(
        options,
        Controller.OPTION_DEFAULTS
      );
      assignConfig("tracks", result.tracks);
      assignConfig("contentPlacement", result.contentPlacement);
    }

    const propsToAssign = [
      "swipe",
      "swipeDismissal",
      "swipeOvershoot",
      "swipeTrap",
      "onFocusInside",
      "nativeFocusScrollPrevention",
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
      "sheetStackRegistry",
      "sheetRegistry",
    ];

    for (const key of propsToAssign) {
      if (key in options) {
        assignConfig(
          key,
          options[key] === undefined
            ? Controller.OPTION_DEFAULTS[key]
            : options[key]
        );
      }
    }

    if (inertOutsideChanged && this.isPresented) {
      this.applyInertOutside();
    }

    if (configurationChanged) {
      this.resetWebkitSmallSpacerTransform();
    }

    if (animationSettingsChanged) {
      this.timeoutManager.scheduleAnimationFrame(
        CONFIGURATION_SKIP_STATE_SYNC,
        () => {
          if (this.isDestroying || this.isDestroyed) {
            return;
          }

          this.animationTravel.syncSkipStates();
        }
      );
    }

    const eventHandlers = [
      "onClickOutside",
      "onEscapeKeyDown",
      "onPresentAutoFocus",
      "onDismissAutoFocus",
    ];

    for (const key of eventHandlers) {
      if (key in options) {
        if (typeof options[key] === "function") {
          this[key] = options[key];
        } else if (options[key] === undefined || options[key] === null) {
          this[key] = { ...Controller.EVENT_HANDLER_DEFAULTS[key] };
        } else {
          this[key] = {
            ...Controller.EVENT_HANDLER_DEFAULTS[key],
            ...options[key],
          };
        }
      }
    }

    if (dimensionsChanged) {
      this.#invalidateDimensions();
    }

    if (configurationChanged) {
      this.#scheduleRenderConfigurationUpdate();
    }
  }

  #configureActiveDetent(options) {
    if (!this.#activeDetentConfigurationInitialized) {
      this.#activeDetentConfigurationInitialized = true;
      if (Number.isInteger(options.activeDetent) && options.activeDetent > 0) {
        this.#initialControlledActiveDetent = options.activeDetent;
      }
    }

    if ("defaultActiveDetent" in options) {
      this.#defaultActiveDetent = options.defaultActiveDetent;
    }
    if ("activeDetent" in options) {
      this.#controlledActiveDetent = options.activeDetent;
      this.syncActiveDetent(options.activeDetent, this.#resolveOpeningDetent());
    } else {
      this.targetDetent = this.#resolveOpeningDetent();
    }
  }

  #resolveOpeningDetent() {
    if (Number.isInteger(this.#defaultActiveDetent)) {
      return this.#defaultActiveDetent;
    }
    if (
      Number.isInteger(this.#controlledActiveDetent) &&
      this.#controlledActiveDetent > 0
    ) {
      return this.#controlledActiveDetent;
    }
    return this.#initialControlledActiveDetent ?? 1;
  }

  #scheduleRenderConfigurationUpdate() {
    this.#renderConfigurationPending = true;
    this.#scheduleConfigurationVersionBump();
    this.#scheduleDimensionRecalculation();
  }

  #scheduleConfigurationVersionBump() {
    if (this.#configurationVersionBumpScheduled) {
      return;
    }

    this.#configurationVersionBumpScheduled = true;

    schedule("afterRender", () => {
      this.#configurationVersionBumpScheduled = false;

      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.configurationVersion++;
    });
  }

  #invalidateDimensions() {
    const shouldRecalculate =
      this.dimensions !== null || this.#dimensionRecalculationPending;

    if (this.dimensions && !this.#dimensionRecalculationPending) {
      this.#progressBeforeDimensionRecalculation =
        this.#currentProgressForDimensionRecalculation(this.dimensions);
    }

    this.cleanupIntersectionObserver();
    this.observerManager.resetResizeObservationCycle();
    this.dimensions = null;

    if (!shouldRecalculate) {
      return;
    }

    this.#dimensionRecalculationPending = true;
    this.#scheduleDimensionRecalculation();
  }

  #scheduleDimensionRecalculation() {
    if (this.#dimensionRecalculationScheduled) {
      return;
    }

    this.#dimensionRecalculationScheduled = true;

    next(() => {
      schedule("afterRender", () => {
        this.#dimensionRecalculationScheduled = false;

        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.#renderConfigurationPending = false;
        this.calculateDimensionsIfReady();
      });
    });
  }

  #currentProgressForDimensionRecalculation(dimensions) {
    const progressValues = dimensions?.progressValueAtDetents;

    if (!progressValues?.length) {
      return 0;
    }

    return progressValues[this.currentSegment[1]]?.exact ?? 1;
  }

  #closestDetentToProgress(progress, dimensions) {
    const progressValues = dimensions.exactProgressValueAtDetents;
    let closestIndex = 0;

    for (let index = 1; index < progressValues.length; index++) {
      if (
        Math.abs(progressValues[index] - progress) <
        Math.abs(progressValues[closestIndex] - progress)
      ) {
        closestIndex = index;
      }
    }

    return closestIndex;
  }

  setupSubscriptions() {
    for (const def of this.#subscriptionDefinitions) {
      this.state.subscribe(def.machine, {
        timing: def.timing || "immediate",
        state: def.state,
        transition: def.transition,
        guard: def.guard,
        callback: def.callback || ((msg) => this[def.handler](msg)),
        type: def.type,
      });
    }
  }

  aggregatedTravelCallback(progress, tween) {
    const animations = this.travelAnimations;
    for (let i = 0, len = animations.length; i < len; i++) {
      animations[i].callback(progress, tween);
    }
  }

  aggregatedStackingCallback(progress, tween) {
    const animations = this.stackingAnimations;
    for (let i = 0, len = animations.length; i < len; i++) {
      animations[i].callback(progress, tween);
    }
  }

  get isScrollTrapActive() {
    return this.resolvedSwipeTrap !== "none";
  }

  get effectiveSwipeTrapClass() {
    const resolved = this.resolvedSwipeTrap;
    switch (resolved) {
      case "both":
        return "swipe-trap-both";
      case "horizontal":
        return "swipe-trap-horizontal";
      case "vertical":
        return "swipe-trap-vertical";
      default:
        return null;
    }
  }

  get resolvedSwipeTrap() {
    const trapValue = this.swipeTrap;

    let trapAxes;
    if (typeof trapValue === "boolean") {
      trapAxes = { x: trapValue, y: trapValue };
    } else if (trapValue && typeof trapValue === "object") {
      trapAxes = { x: trapValue.x, y: trapValue.y };
    } else {
      trapAxes = { x: undefined, y: undefined };
    }

    let trapHorizontal, trapVertical;
    const travelAxis = this.isHorizontalTrack ? "horizontal" : "vertical";
    const appleModalTrap =
      capabilities.isAppleMobile &&
      this.inertOutside &&
      !this.ancestorPrimarySwipeTrapActiveOnYAxis;

    if (travelAxis === "vertical") {
      trapHorizontal = trapAxes.x;
      trapVertical =
        appleModalTrap ||
        (!capabilities.isAndroidChromiumBrowser && (trapAxes.y ?? true));
    } else if (travelAxis === "horizontal") {
      trapVertical = appleModalTrap || trapAxes.y;
      trapHorizontal = trapAxes.x ?? true;
    }

    if (trapHorizontal && !trapVertical) {
      return "horizontal";
    } else if (!trapHorizontal && trapVertical) {
      return "vertical";
    } else if (trapHorizontal && trapVertical) {
      return "both";
    }
    return "none";
  }

  get ancestorPrimarySwipeTrapActiveOnYAxis() {
    const ancestor = this.sheetRegistry?.findContainingSheet(
      this.rootElement,
      this
    );
    const resolved = ancestor?.resolvedSwipeTrap;
    return resolved === "vertical" || resolved === "both";
  }

  get primaryScrollTrapAxisClass() {
    const resolved = this.resolvedSwipeTrap;
    switch (resolved) {
      case "horizontal":
        return "scroll-horizontal";
      case "vertical":
        return "scroll-vertical";
      case "both":
        return "scroll-both";
      default:
        return "scroll-vertical";
    }
  }

  get scrollContainerShouldBePassThrough() {
    return !this.inertOutside && !this.backdropSwipeable;
  }

  get titleId() {
    return `${this.id}-title`;
  }

  get descriptionId() {
    return `${this.id}-description`;
  }

  get labelledById() {
    return this.titleElement?.isConnected ? this.titleId : null;
  }

  get describedById() {
    return this.descriptionElement?.isConnected ? this.descriptionId : null;
  }

  get detents() {
    return this.detentManager.effectiveDetents;
  }

  set detents(value) {
    if (!this.#assignDetents(value)) {
      return;
    }

    this.#invalidateDimensions();
    this.#scheduleRenderConfigurationUpdate();
  }

  #assignDetents(value) {
    if (this.detentsConfig === value) {
      return false;
    }

    this.detentsConfig = value;
    this.detentMarkers.splice(this.detents.length);
    return true;
  }

  @cached
  get swipeBehaviorFlags() {
    const swipeAvailable =
      Boolean(this.swipe) && Controller.browserSupportsRequiredFeatures;
    const dismissalDisabled =
      this.role === "alertdialog" || !this.swipeDismissal;
    const openAndNotClosing =
      this.state.openness.isOpen && !this.state.staging.isClosing;
    let swipeDisabled = false;
    let swipeOutDisabledWithDetent = false;
    let webkitSmallSpacerMode = false;

    if (swipeAvailable) {
      if (dismissalDisabled && this.detentsConfig) {
        swipeOutDisabledWithDetent = openAndNotClosing;
      } else if (dismissalDisabled && openAndNotClosing) {
        if (
          !this.edgeAlignedNoOvershoot &&
          capabilities.browserEngine === "webkit"
        ) {
          webkitSmallSpacerMode = true;
        } else {
          swipeDisabled = true;
        }
      }
    } else if (!this.state.openness.isClosed) {
      swipeDisabled = true;
    }

    return {
      swipeDisabled,
      swipeOutDisabledWithDetent,
      webkitSmallSpacerMode,
    };
  }

  get swipeDisabled() {
    return this.swipeBehaviorFlags.swipeDisabled;
  }

  get canAcceptDismissRequest() {
    return this.state.openness.isOpen;
  }

  get swipeOutDisabledWithDetent() {
    return this.swipeBehaviorFlags.swipeOutDisabledWithDetent;
  }

  get edgeAlignedNoOvershoot() {
    if (this.swipeOvershoot) {
      return false;
    }

    const isDismissalDisabled =
      this.role === "alertdialog" || !this.swipeDismissal;
    return !this.isCenteredTrack || isDismissalDisabled;
  }

  get webkitSmallSpacerMode() {
    return this.swipeBehaviorFlags.webkitSmallSpacerMode;
  }

  get isHorizontalTrack() {
    return (
      this.tracks === "left" ||
      this.tracks === "right" ||
      this.tracks === "horizontal"
    );
  }

  get isVerticalTrack() {
    return (
      this.tracks === "top" ||
      this.tracks === "bottom" ||
      this.tracks === "vertical"
    );
  }

  get isCenteredTrack() {
    return this.tracks === "horizontal" || this.tracks === "vertical";
  }

  get contentPlacementAttribute() {
    return placementToAttribute(this.contentPlacement);
  }

  get stagingAttribute() {
    return this.state.staging.current === "none" ? "staging-none" : null;
  }

  get shouldRenderView() {
    const opennessKeepsViewMounted =
      !this.state.openness.isClosedFlushing &&
      !this.state.openness.isClosedSafeToUnmount;
    const stagingKeepsViewMounted =
      this.state.staging.isOpening || this.state.staging.isOpen;

    return opennessKeepsViewMounted || stagingKeepsViewMounted;
  }

  get shouldFlushView() {
    return this.state.openness.isClosedFlushing;
  }

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

  handleStackingStateChange(status, previousStatus) {
    this.stackingAdapter.handleTravelStatusChange(status, previousStatus);
  }

  updateTravelRange(start, end) {
    if (this.travelRange.start !== start || this.travelRange.end !== end) {
      this.travelRange = { start, end };
      this.onTravelRangeChange?.(this.travelRange);
    }
  }

  #scheduleSegmentNotifications(segment) {
    queueMicrotask(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      const [start, end] = segment;
      if (this.travelRange.start === start && this.travelRange.end === end) {
        return;
      }

      this.updateTravelRange(start, end);

      if (start === end) {
        if (this.#programmaticDetent === null) {
          this.onActiveDetentChange?.(end);
        } else if (start === this.#programmaticDetent) {
          this.#programmaticDetent = null;
        }
      }
    });
  }

  notifyTravel(progress, segment) {
    this.onTravel?.({
      progress,
      range: segment ? { start: segment[0], end: segment[1] } : undefined,
      progressAtDetents: this.dimensions?.exactProgressValueAtDetents,
    });
  }

  get mergedStaging() {
    return this.stackingAdapter?.getMergedStaging() ?? "none";
  }

  get isStackAnimating() {
    return this.mergedStaging !== "none";
  }

  @action
  setSegment(segment) {
    const prevSegment = this.currentSegment;
    this.#scheduleSegmentNotifications(segment);

    if (prevSegment[0] === segment[0] && prevSegment[1] === segment[1]) {
      return;
    }

    this.currentSegment = segment;

    if (this.swipeOutDisabledWithDetent) {
      const { backStuck, frontStuck } =
        this.detentManager.determineStuckPosition(segment, prevSegment);

      if (backStuck) {
        const wasStuck = this.state.stuck.isBack;
        this.state.stuck.startBack();
        if (
          !wasStuck &&
          this.#shouldAutoCorrectStuckPosition &&
          this.state.touch.isEnded
        ) {
          this.stepToStuckPosition("back");
        }
      } else if (frontStuck) {
        const wasStuck = this.state.stuck.isFront;
        this.state.stuck.startFront();
        if (
          !wasStuck &&
          this.#shouldAutoCorrectStuckPosition &&
          this.state.touch.isEnded
        ) {
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
    }
  }

  #notifyProgrammaticDetent(detent) {
    this.#programmaticDetent = detent;
    this.onActiveDetentChange?.(detent);
  }

  #startProgrammaticDetentTravel(
    detent,
    behavior = null,
    runOnTravelStart = true
  ) {
    this.#notifyProgrammaticDetent(detent);
    this.animationTravel.animateToDetent(
      detent,
      null,
      behavior,
      runOnTravelStart
    );
  }

  #notifyDismissedDetent() {
    this.#programmaticDetent = null;
    this.onActiveDetentChange?.(0);
  }

  @action
  handleStateTransition(message) {
    this.state.openness.send(message);
  }

  handleOpening() {
    this.isPresented = true;
    this.domAttributes.setHidden();
    this.updateTravelStatus("entering");
    this.focusManagement.capturePreviouslyFocusedElement();

    this.state.longRunning.start();
    this.#scheduleDimensionRecalculation();
    this.state.beginEnterAnimation(false);
    this.stackingAdapter.notifyParentOfOpening(false);

    if (this.state.elements.isReady) {
      this.#startOpeningAnimation();
    }
  }

  handleSkippedOpening() {
    this.isPresented = true;
    this.domAttributes.setHidden();
    this.state.longRunning.start();
    this.stackingAdapter.notifyParentOfOpening(true);
  }

  handleOpeningTravelStart() {
    this.onTravelStart?.();
    this.notifyTravel(0, [0, 0]);

    const tween = createTweenFunction(0);
    this.aggregatedTravelCallback(0, tween);
    this.stackingAdapter.notifyBelowSheets(0);
  }

  completeSkippedOpening() {
    if (this.isDestroying || this.isDestroyed || !this.state.staging.isOpen) {
      return;
    }

    this.state.position.readyToGoFront(true);
    this.state.openness.readyToOpen(true);
    this.state.staging.advance();
  }

  startSkippedOpeningTravel() {
    this.calculateDimensionsIfReady();
    this.#startProgrammaticDetentTravel(this.targetDetent);
  }

  #startOpeningAnimation() {
    this.resetViewStyles();
    this.calculateDimensionsIfReady();
    this.#recalculateDimensionsForCurrentTrack();
    this.setInitialScrollPosition();
    this.domAttributes.setHidden();
    this.#startProgrammaticDetentTravel(this.targetDetent, null, false);
  }

  startOpeningAnimation() {
    this.#startOpeningAnimation();
  }

  #notifyElementsRegisteredIfReady() {
    if (
      this.view &&
      this.content &&
      this.scrollContainer &&
      this.contentWrapper &&
      this.dimensions &&
      this.state.elements.isNotReady
    ) {
      next(() => {
        if (
          !this.isDestroying &&
          !this.isDestroyed &&
          this.state.elements.isNotReady
        ) {
          this.state.elements.markRegistered();
        }
      });
    }
  }

  handleOpen() {
    this.updateScrollSnapBehavior();
    this.#scheduleSegmentNotifications([this.activeDetent, this.activeDetent]);
    this.updateTravelStatus("idleInside");
    this.applyInertOutside();

    this.executeAutoFocusOnPresent();

    if (this.state.staging.matches("opening")) {
      this.state.staging.advance();
    }
  }

  handleStepMessage(message) {
    this.updateTravelStatus("stepping");

    const destinationDetent = message.detent ?? this.activeDetent + 1;
    this.#startProgrammaticDetentTravel(destinationDetent, message.behavior);
  }

  evaluateStepMessage(message) {
    if (this.state.openness.areScrollEndedAfterPaintEffectsRun) {
      this.#performStep(message);
    } else {
      this.#pendingStepMessage = message;
    }
  }

  handleScrollEndedAfterPaint() {
    this.state.openness.markScrollEndedAfterPaintEffectsRun();

    if (!this.#pendingStepMessage) {
      return;
    }

    const message = this.#pendingStepMessage;
    this.#pendingStepMessage = null;
    this.#performStep(message);
  }

  #performStep(message) {
    const detent = this.detentManager.calculateStep(
      message.direction,
      message.detent ?? null
    );

    if (detent !== null) {
      this.state.stepAnimation(detent, message.behavior);
    }
  }

  handleClosing() {
    this.focusManagement.captureFocusWasInsideOnClose();
    this.state.position.readyToGoOut();
    this.updateTravelStatus("exiting");
    this.stackingAdapter.notifyParentOfClosing();

    if (this.state.skip.isClosing) {
      this.#notifyProgrammaticDetent(0);
      this.handleClosingWithoutAnimation();
      return;
    }

    this.#recalculateDimensionsForCurrentTrack();
    this.domAttributes.disableScrollSnap();
    this.#startProgrammaticDetentTravel(0);
  }

  handleClosingWithoutAnimation() {
    this.state.skip.disableClosing();

    this.stackingAdapter.notifyBelowSheets(0);

    this.timeoutManager.scheduleAnimationFrame(
      "closingWithoutAnimation",
      () => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.handleStateTransition({ type: EVENTS.NEXT });
        this.animationTravel.syncSkipStates();
      }
    );
  }

  handleClosedPending() {
    this.ensureDismissed();

    this.state.longRunning.end();
    this.#handleImmediateCloseIfNeeded();
    this.#scheduleFlushToSafeToUnmount();
    this.rootComponent?.deactivateSheetLayer(true);
  }

  #handleImmediateCloseIfNeeded() {
    if (!this.state.skip.isClosing) {
      return;
    }

    this.focusManagement.captureFocusWasInsideOnClose();
    this.state.beginImmediateClose(true);
    this.updateTravelStatus("exiting");
    this.animationTravel.syncSkipStates();
    const configuredSkip = this.state.skip.isClosing;

    if (configuredSkip) {
      this.onTravelStart?.();
    }
    this.state.position.goOut();

    if (configuredSkip) {
      this.notifyTravel(0, [0, 0]);
      this.aggregatedTravelCallback(0, createTweenFunction(0));
    }
    this.stackingAdapter.notifyBelowSheets(0);
    if (configuredSkip) {
      this.onTravelEnd?.();
      this.lastProcessedProgress = 0;
      this.stackingAdapter.updateTravelProgress(0);
    }
    this.stackingAdapter.notifyParentOfClosingImmediate();
  }

  #scheduleFlushToSafeToUnmount() {
    this.timeoutManager.scheduleNative(
      "pendingFlush",
      () => {
        if (this.state.openness.isClosedPending) {
          this.state.openness.advanceClosedStatus();
        }
      },
      3000
    );
  }

  handleClosedSafeToUnmount() {
    const wasLongRunning = this.state.longRunning.isActive;

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

    if (this.state.elements.isReady) {
      this.state.elements.reset();
    }

    this.activeDetent = 0;
    this.currentSegment = [0, 0];
    this.dimensions = null;
    this.lastProcessedProgress = null;
    this.#scrollOccurredSinceClosed = false;

    if (!this.state.position.isOut && this.state.position.isFrontClosing) {
      this.state.position.advance();
    }

    this.updateTravelStatus("idleOutside");
    this.updateTravelRange(0, 0);
  }

  #getDimensionCalculatorOptions() {
    return {
      swipeOutDisabledWithDetent: this.swipeOutDisabledWithDetent,
      snapOutAcceleration: this.snapOutAcceleration,
      snapToEndDetentsAcceleration: this.snapToEndDetentsAcceleration,
      edgeAlignedNoOvershoot: this.edgeAlignedNoOvershoot,
      webkitSmallSpacerMode: this.webkitSmallSpacerMode,
    };
  }

  #calculateDimensions() {
    const tracks = this.tracks;
    const calculator = new DimensionCalculator({
      view: this.view,
      content: this.content,
      scrollContainer: this.scrollContainer,
      detentMarkers: this.detentMarkers,
    });

    const dimensions = calculator.calculateDimensions(
      tracks,
      this.contentPlacement,
      this.#getDimensionCalculatorOptions()
    );

    this.#dimensionsTrack = tracks;
    return dimensions;
  }

  calculateDimensionsIfReady() {
    if (this.#renderConfigurationPending || this.state.openness.isClosed) {
      return;
    }

    const expectedMarkerCount = this.detents.length;
    const registeredMarkers = this.detentMarkers.slice(0, expectedMarkerCount);
    const hasRequiredMarkers =
      registeredMarkers.length === expectedMarkerCount &&
      registeredMarkers.every((marker) => marker?.isConnected);

    if (
      this.view &&
      this.content &&
      this.scrollContainer &&
      hasRequiredMarkers
    ) {
      if (this.#dimensionRecalculationPending) {
        this.#dimensionRecalculationPending = false;
        this.recalculateDimensionsFromResize();
      } else if (!this.dimensions) {
        this.dimensions = this.#calculateDimensions();
        this.setInitialScrollPosition();
        this.#notifyElementsRegisteredIfReady();
      }
    }
  }

  setInitialScrollPosition() {
    if (!this.scrollContainer || !this.dimensions) {
      return;
    }

    const configuredEnteringTrack = this.state.staging.isOpening
      ? this.enteringAnimationSettings?.track
      : undefined;
    const enteringTrack = resolveTravelTrack(
      configuredEnteringTrack,
      this.tracks
    );
    const isHorizontal = enteringTrack === "left" || enteringTrack === "right";
    const isBackTrack = enteringTrack === "bottom" || enteringTrack === "right";

    if (isHorizontal) {
      this.scrollContainer.scrollLeft = isBackTrack
        ? 0
        : this.scrollContainer.scrollWidth;
    } else {
      this.scrollContainer.scrollTop = isBackTrack
        ? 0
        : this.scrollContainer.scrollHeight;
    }
  }

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

  setupIntersectionObserver() {
    this.observerManager.setupIntersectionObserver();
  }

  restoreRestingDetentAfterLayout() {
    const [segmentStart, segmentEnd] = this.currentSegment;

    if (
      !this.state.openness.isOpen ||
      !this.scrollContainer ||
      !this.contentWrapper ||
      !this.dimensions ||
      segmentStart !== segmentEnd
    ) {
      return;
    }

    this.animationTravel.recalculateAndTravel(segmentEnd);
  }

  cleanupIntersectionObserver() {
    this.observerManager.cleanupIntersectionObserver();
  }

  @action
  registerView(view) {
    this.view = view;
    this.resetViewStyles();
    if (this.state.openness.isOpening) {
      this.domAttributes.setHidden();
    }
    this.calculateDimensionsIfReady();
    this.setupResizeObserver();
    this.sheetRegistry?.viewRegistered(this, view);
    this.#notifyElementsRegisteredIfReady();
  }

  @action
  unregisterView(view) {
    if (this.view !== view) {
      return;
    }

    this.cleanupIntersectionObserver();
    this.observerManager.unobserveResizeTarget(view);
    this.view = null;
    this.dimensions = null;
  }

  @action
  registerRootElement(rootElement) {
    this.rootElement = rootElement;
  }

  @action
  unregisterRootElement(rootElement) {
    if (this.rootElement === rootElement) {
      this.rootElement = null;
    }
  }

  setupResizeObserver() {
    const canRecalculate = () => {
      return Boolean(
        this.view && this.content && this.scrollContainer && this.dimensions
      );
    };

    this.observerManager.setupResizeObserver({
      onInitialContentResize: () => {
        if (canRecalculate()) {
          this.recalculateDimensionsFromResize({
            correctScrollPosition: false,
          });
        } else {
          this.calculateDimensionsIfReady();
        }
      },
      onResize: () => {
        if (canRecalculate()) {
          this.recalculateDimensionsFromResize();
        }
      },
    });
  }

  #recalculateDimensionsForCurrentTrack() {
    if (
      !this.view ||
      !this.content ||
      !this.scrollContainer ||
      !this.dimensions ||
      this.#dimensionsTrack === this.tracks
    ) {
      return;
    }

    this.recalculateDimensionsFromResize();
  }

  scheduleTrackDimensionRecalculation() {
    if (this.#trackDimensionRecalculationScheduled) {
      return;
    }

    this.#trackDimensionRecalculationScheduled = true;

    next(() => {
      schedule("afterRender", () => {
        this.#trackDimensionRecalculationScheduled = false;

        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.#recalculateDimensionsForCurrentTrack();
      });
    });
  }

  recalculateDimensionsFromResize({ correctScrollPosition = true } = {}) {
    const previousProgress =
      this.#progressBeforeDimensionRecalculation ??
      this.#currentProgressForDimensionRecalculation(this.dimensions);
    const dimensions = this.#calculateDimensions();
    const destinationDetent = this.#closestDetentToProgress(
      previousProgress,
      dimensions
    );

    this.#progressBeforeDimensionRecalculation = null;
    this.dimensions = dimensions;
    this.setSegment([destinationDetent, destinationDetent]);

    if (destinationDetent !== null) {
      this.lastProcessedProgress =
        dimensions.exactProgressValueAtDetents[destinationDetent];
    }

    const updateIntersectionObserver = () => {
      if (!this.swipeDisabled && !this.swipeOutDisabledWithDetent) {
        this.setupIntersectionObserver();
      } else {
        this.cleanupIntersectionObserver();
      }
    };

    if (
      correctScrollPosition &&
      destinationDetent > 0 &&
      this.state.openness.isOpen
    ) {
      this.animationTravel.recalculateAndTravel(destinationDetent);
    }

    if (this.state.openness.isOpen) {
      updateIntersectionObserver();
    }
  }

  cleanup() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.isDestroying = true;
    this.animationTravel.cancelActiveTravel();
    this.timeoutManager.cleanup();
    this.removeAllOutletPersistedStyles();

    this.observerManager.cleanup();
    this.unregisterBackdrop(this.backdrop);
    this.resetWebkitSmallSpacerTransform();
    this.domAttributes.cleanup();
    this.focusManagement.cleanup();
    this.state.cleanup();
    this.stackingAdapter?.removeStagingFromStack();

    this.view = null;
    this.rootElement = null;
    this.content = null;
    this.contentWrapper = null;
    this.scrollContainer = null;
    this.detentMarkers.length = 0;
    this.dimensions = null;
    this.isDestroyed = true;
  }

  executeAutoFocusOnPresent() {
    this.focusManagement.executeAutoFocusOnPresent();
  }

  executeAutoFocusOnDismiss() {
    this.focusManagement.executeAutoFocusOnDismiss();
  }

  setPreviouslyFocusedElement(element) {
    this.focusManagement.setPreviouslyFocusedElement(element);
  }

  applyInertOutside() {
    this.sheetRegistry?.updateInertOutside(this, this.inertOutside);
  }

  @action
  setBleedingBackgroundPresent(value) {
    this.bleedingBackgroundPresent = value;
  }

  @action
  registerContent(content) {
    this.content = content;
    this.calculateDimensionsIfReady();
    this.setupResizeObserver();
  }

  @action
  unregisterContent(content) {
    if (this.content !== content) {
      return;
    }

    this.cleanupIntersectionObserver();
    this.observerManager.unobserveResizeTarget(content);
    this.content = null;
    this.dimensions = null;
  }

  @action
  registerTitle(element) {
    this.titleElement = element;
  }

  @action
  unregisterTitle(element) {
    if (this.titleElement === element) {
      this.titleElement = null;
    }
  }

  @action
  registerDescription(element) {
    this.descriptionElement = element;
  }

  @action
  unregisterDescription(element) {
    if (this.descriptionElement === element) {
      this.descriptionElement = null;
    }
  }

  @action
  registerContentWrapper(contentWrapper) {
    this.contentWrapper = contentWrapper;
    this.#notifyElementsRegisteredIfReady();
  }

  @action
  unregisterContentWrapper(contentWrapper) {
    if (this.contentWrapper === contentWrapper) {
      this.resetWebkitSmallSpacerTransform();
      this.contentWrapper = null;
    }
  }

  @action
  registerScrollContainer(scrollContainer) {
    this.scrollContainer = scrollContainer;

    this.calculateDimensionsIfReady();
    this.#notifyElementsRegisteredIfReady();
  }

  @action
  unregisterScrollContainer(scrollContainer) {
    if (this.scrollContainer !== scrollContainer) {
      return;
    }

    this.timeoutManager.clear("scrollEnd");
    this.scrollContainer = null;
    this.dimensions = null;
  }

  updateScrollSnapBehavior() {
    if (!this.scrollContainer || !this.dimensions || !this.content) {
      return;
    }

    this.domAttributes.enableScrollSnap();
  }

  @action
  handleScrollStateChange() {
    const programmaticScroll = this.#programmaticScrollPending;

    if (programmaticScroll) {
      this.#programmaticScrollPending = false;
    }

    if (!this.state.openness.isOpen) {
      return;
    }

    if (!this.scrollContainer || !this.dimensions) {
      return;
    }

    if (!programmaticScroll) {
      if (!this.state.openness.isScrollOngoing) {
        this.state.openness.scrollStart();
      }

      if (!this.state.stuck.isFront && !this.state.stuck.isBack) {
        if (!this.state.openness.isSwipeOngoing) {
          this.state.openness.swipeStart();
          this.updateTravelStatus("stepping");
        }
        if (!this.state.openness.isMoveOngoing) {
          this.state.openness.moveStart();
        }
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

  #handleScrollEnd() {
    this.state.openness.moveEnd();

    const progress = this.lastProcessedProgress;
    const detents = this.dimensions?.progressValueAtDetents;

    if (progress !== null && progress !== undefined && detents) {
      for (const detent of detents) {
        const matches =
          progress > detent.exact - 0.01 && progress < detent.exact + 0.01;

        if (matches) {
          this.state.openness.scrollEnd();
          this.state.openness.swipeEnd();
          if (this.state.openness.isOpen) {
            this.updateTravelStatus("idleInside");
          }
          break;
        }
      }
    }
  }

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
    const webkitSmallSpacerMode = this.webkitSmallSpacerMode;

    if (!webkitSmallSpacerMode) {
      this.resetWebkitSmallSpacerTransform();
    }

    if (this.lastProcessedProgress === smoothedProgress) {
      return;
    }

    this.lastProcessedProgress = smoothedProgress;

    const segment =
      this.scrollProgressCalculator.determineSegment(smoothedProgress);
    if (segment) {
      this.setSegment(segment);
    }

    if (!this.state.openness.isMoveOngoing) {
      return;
    }

    if (webkitSmallSpacerMode) {
      this.#updateWebkitSmallSpacerTransform(smoothedProgress);
      return;
    }

    this.notifyTravel(smoothedProgress, segment);

    const tween = createTweenFunction(smoothedProgress);
    this.aggregatedTravelCallback(smoothedProgress, tween);
    this.stackingAdapter.notifyBelowSheets(smoothedProgress);
  }

  #updateWebkitSmallSpacerTransform(progress) {
    if (
      progress > 0 &&
      progress < 1 &&
      !this.#webkitSmallSpacerTransformApplied
    ) {
      const transform = WEBKIT_SMALL_SPACER_TRANSFORMS[this.tracks] ?? null;

      if (transform && this.contentWrapper) {
        this.contentWrapper.style.setProperty("transform", transform);
        this.#webkitSmallSpacerTransformApplied = true;
      }
    } else if (progress > 1 || progress <= 0) {
      this.resetWebkitSmallSpacerTransform();
    }
  }

  resetWebkitSmallSpacerTransform() {
    if (!this.#webkitSmallSpacerTransformApplied) {
      return;
    }

    this.contentWrapper?.style.removeProperty("transform");
    this.#webkitSmallSpacerTransformApplied = false;
  }

  handleManualTravelStart() {
    if (this.#manualTravelOngoing) {
      return;
    }

    this.#manualTravelOngoing = true;
    this.onTravelStart?.();
  }

  handleManualTravelEnd() {
    if (!this.#manualTravelOngoing) {
      return;
    }

    this.#manualTravelOngoing = false;
    this.onTravelEnd?.();

    const exactProgress =
      this.dimensions?.exactProgressValueAtDetents?.[this.currentSegment[0]];

    if (exactProgress === undefined) {
      return;
    }

    this.lastProcessedProgress = exactProgress;
    this.stackingAdapter.updateTravelProgress(exactProgress);
  }

  @action
  handleTouchStart() {
    this.state.touch.start();
  }

  @action
  handleTouchEnd() {
    this.state.touch.end();
  }

  @action
  handleFocus(event) {
    processBehavior({
      nativeEvent: event,
      defaultBehavior: {},
      handler: this.onFocusInside,
    });
  }

  handleTouchEnded() {
    if (
      !this.#shouldAutoCorrectStuckPosition ||
      !this.#scrollOccurredSinceClosed
    ) {
      return;
    }

    this.timeoutManager.scheduleNative(
      "stuckPosition",
      () => {
        this.timeoutManager.scheduleAnimationFrame("stuckPosition", () => {
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

  get #shouldAutoCorrectStuckPosition() {
    return (
      this.edgeAlignedNoOvershoot &&
      this.snapToEndDetentsAcceleration === "auto"
    );
  }

  markScrollOccurred() {
    this.#scrollOccurredSinceClosed = true;
  }

  handleSwipeOut() {
    if (!this.state.openness.isOpen) {
      return;
    }

    this.#notifyDismissedDetent();
    this.handleStateTransition("SWIPED_OUT");
  }

  stepToStuckPosition(direction) {
    this.animationTravel.stepToStuckPosition(direction);

    if (capabilities.isWebKit) {
      const overflowTimeout = CSS.supports("overscroll-behavior", "none")
        ? 1
        : 10;
      this.domAttributes.temporarilyHideOverflow(overflowTimeout);
    }

    this.#scrollOccurredSinceClosed = false;
  }

  @action
  registerDetentMarker(detentMarker, index) {
    this.detentMarkers.splice(this.detents.length);
    this.detentMarkers[index] = detentMarker;
    this.calculateDimensionsIfReady();
  }

  @action
  unregisterDetentMarker(detentMarker, index) {
    if (this.detentMarkers[index] !== detentMarker) {
      return;
    }

    this.detentMarkers[index] = null;
    this.#invalidateDimensions();
  }

  @action
  registerBackdrop(backdrop, swipeable = true) {
    this.backdrop = backdrop;
    this.backdropSwipeable = swipeable;
    backdrop.style.opacity = 0;
    backdrop.style.willChange = "opacity";
  }

  @action
  unregisterBackdrop(backdrop = this.backdrop) {
    if (backdrop && this.backdrop && backdrop !== this.backdrop) {
      return;
    }

    this.backdrop = null;
    this.backdropSwipeable = false;
  }

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

  removeAllOutletPersistedStyles() {
    for (const animations of [this.travelAnimations, this.stackingAnimations]) {
      for (const animation of animations) {
        animation.restorePersistedStyles?.();
      }
    }
  }

  @action
  open() {
    this.timeoutManager.clear(CONFIGURATION_SKIP_STATE_SYNC);
    this.animationTravel.syncSkipStates();
    this.focusManagement.capturePreviouslyFocusedElement();
    this.state.broadcastOpen();
  }

  @action
  requestPresent() {
    if (this.rootComponent) {
      this.rootComponent.present();
    } else {
      this.open();
    }
  }

  ensurePresented() {
    if (this.rootComponent?.effectivePresented === false) {
      this.rootComponent.present();
    }
  }

  ensureDismissed() {
    if (this.rootComponent?.effectivePresented) {
      this.rootComponent.dismiss();
    }
  }

  @action
  close() {
    this.timeoutManager.clear(CONFIGURATION_SKIP_STATE_SYNC);
    this.animationTravel.syncSkipStates();
    this.handleStateTransition({ type: EVENTS.CLOSE });
  }

  @action
  requestDismiss() {
    if (this.rootComponent) {
      this.rootComponent.dismiss();
    } else {
      this.close();
    }
  }

  evaluateCloseMessage() {
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
      this.ensurePresented();
      return;
    }

    this.#notifyDismissedDetent();
    this.state.staging.actuallyClose();
    this.handleStateTransition({ type: EVENTS.ACTUALLY_CLOSE });
  }

  sendToPositionMachine(message, context = {}) {
    return this.state.sendToPosition(message, context);
  }

  @action
  step() {
    if (!this.state.openness.isOpen) {
      return;
    }

    this.handleStateTransition({ type: EVENTS.STEP, direction: "up" });
  }

  @action
  stepDown() {
    if (!this.state.openness.isOpen) {
      return;
    }

    this.handleStateTransition({ type: EVENTS.STEP, direction: "down" });
  }

  @action
  stepToDetent(detent) {
    if (!this.state.openness.isOpen) {
      return;
    }

    if (this.detentManager.isValidDetent(detent)) {
      this.handleStateTransition({ type: EVENTS.STEP, detent });
    }
  }

  syncActiveDetent(activeDetent, openingDetent = activeDetent) {
    const shouldStep =
      this.state.openness.isOpen &&
      this.currentSegment[0] !== activeDetent &&
      this.currentSegment[1] !== activeDetent &&
      this.#programmaticDetent !== activeDetent &&
      this.detentManager.isValidDetent(activeDetent);

    this.targetDetent = openingDetent;

    if (shouldStep) {
      this.handleStateTransition({ type: EVENTS.STEP, detent: activeDetent });
    }
  }

  resetViewStyles() {
    this.domAttributes.resetViewStyles();
  }
}
