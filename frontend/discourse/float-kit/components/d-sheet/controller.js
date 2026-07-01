import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { trackedArray } from "@ember/reactive/collections";
import { next } from "@ember/runloop";
import { capabilities } from "discourse/services/capabilities";
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
import ThemeColorAdapter from "./theme-color-adapter";
import TimeoutManager from "./timeout-manager";
import { TouchHandler } from "./touch-handler";

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

  static get browserSupportsRequiredFeatures() {
    return BROWSER_SUPPORTS_REQUIRED_FEATURES;
  }

  @tracked view = null;
  @tracked rootElement = null;
  @tracked content = null;
  @tracked contentWrapper = null;
  @tracked scrollContainer = null;
  @tracked backdrop = null;

  @tracked titleElement = null;
  @tracked descriptionElement = null;

  @tracked bleedingBackgroundPresent = false;
  @tracked isPresented = false;
  @tracked safeToUnmount = true;
  @tracked detentsConfig = null;
  @tracked swipeOvershoot = true;
  @tracked backdropSwipeable = true;
  @tracked inertOutside = true;
  detentMarkers = trackedArray();
  id = guidFor(this);
  contentPlacement = "bottom";
  dimensions = null;
  activeDetent = 0;
  targetDetent = 1;
  currentSegment = [0, 0];
  travelStatus = "idleOutside";
  previousTravelStatus = "idleOutside";
  travelRange = { start: 0, end: 0 };
  lastProcessedProgress = null;
  progressSmoother = null;
  role = "dialog";
  tracks = "bottom";
  swipe = true;
  swipeDismissal = true;
  swipeTrap = true;
  nativeFocusScrollPrevention = true;
  pageScroll = false;
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
  onTravelProgressChange = null;
  onSafeToUnmountChange = null;
  onFocusInside = null;
  focusManagement = null;
  touchHandler;
  timeoutManager;
  detentManager;
  domAttributes;
  observerManager;
  scrollProgressCalculator;
  stackingAdapter;
  state;
  animationTravel;
  themeColorAdapter;
  rootComponent = null;
  isDestroying = false;
  isDestroyed = false;
  #subscriptionDefinitions = [];

  constructor() {
    this.touchHandler = new TouchHandler(this);
    this.focusManagement = new FocusManagement(this);
    this.timeoutManager = new TimeoutManager();
    this.detentManager = new DetentManager(this);
    this.domAttributes = new DOMAttributes(this);
    this.observerManager = new ObserverManager(this);
    this.scrollProgressCalculator = new ScrollProgressCalculator(this);
    this.stackingAdapter = new StackingAdapter(this);
    this.state = new StateHelper();
    this.animationTravel = new AnimationTravel(this);
    this.themeColorAdapter = new ThemeColorAdapter();
    this.#subscriptionDefinitions = buildStateEffects(this);
    this.setupSubscriptions();
  }

  configure(options = {}) {
    if (options.role !== undefined) {
      this.role = options.role;
    }

    if (options.activeDetent !== undefined) {
      this.syncActiveDetent(options.activeDetent);
    } else if (options.defaultActiveDetent !== undefined) {
      this.targetDetent = options.defaultActiveDetent;
    }

    if ("onActiveDetentChange" in options) {
      this.onActiveDetentChange = options.onActiveDetentChange ?? null;
    }

    if ("onSafeToUnmountChange" in options) {
      this.onSafeToUnmountChange = options.onSafeToUnmountChange ?? null;
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
      "sheetStackRegistry",
      "sheetRegistry",
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
    const trapValue = this.inertOutside ? true : this.swipeTrap;

    let n;
    if (typeof trapValue === "boolean") {
      n = { x: trapValue, y: trapValue };
    } else if (trapValue && typeof trapValue === "object") {
      n = { x: trapValue.x, y: trapValue.y };
    } else {
      n = { x: false, y: false };
    }

    let a, r;
    const travelAxis = this.isHorizontalTrack ? "horizontal" : "vertical";

    if (travelAxis === "vertical") {
      a = n.x;
      r = n.y !== false && n.y !== null && n.y !== undefined ? n.y : true;
    } else if (travelAxis === "horizontal") {
      r = n.y;
      a = n.x !== false && n.x !== null && n.x !== undefined ? n.x : true;
    }

    if (a && !r) {
      return "horizontal";
    } else if (!a && r) {
      return "vertical";
    } else if (a && r) {
      return "both";
    }
    return "none";
  }

  get ancestorPrimarySwipeTrapActiveOnYAxis() {
    const resolved = this.resolvedSwipeTrap;
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
    const oldValue = this.detentsConfig;
    this.detentsConfig = value;

    if (oldValue !== value) {
      this.detentMarkers = trackedArray();

      if (this.view && this.content && this.scrollContainer) {
        this.recalculateDimensionsFromResize();
      }
    }
  }

  get swipeDisabled() {
    if (this.swipe === false || !Controller.browserSupportsRequiredFeatures) {
      return true;
    }

    const dismissalDisabled =
      this.role === "alertdialog" || !this.swipeDismissal;
    if (
      dismissalDisabled &&
      (this.detentsConfig === null || this.detentsConfig === undefined)
    ) {
      return true;
    }

    return false;
  }

  get canAcceptDismissRequest() {
    return this.state.openness.isOpen || this.state.openness.isOpening;
  }

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

  get edgeAlignedNoOvershoot() {
    if (this.swipeOvershoot) {
      return false;
    }

    const isDismissalDisabled =
      this.role === "alertdialog" || !this.swipeDismissal;
    return !this.isCenteredTrack || isDismissalDisabled;
  }

  get webkitSmallSpacerMode() {
    return (
      capabilities.browserEngine === "webkit" &&
      this.state.openness.isOpen &&
      !this.state.staging.isClosing &&
      !this.edgeAlignedNoOvershoot
    );
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

  notifyTravel(progress) {
    this.onTravel?.({ progress });
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

  @action
  handleStateTransition(message) {
    this.state.openness.send(message);
  }

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

  #startOpeningAnimation() {
    this.resetViewStyles();
    this.calculateDimensionsIfReady();
    this.domAttributes.setHidden();
    this.animationTravel.animateToDetent(this.targetDetent);
  }

  startOpeningAnimation() {
    this.#startOpeningAnimation();
  }

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

  handleOpen(message) {
    if (this.state.longRunning.isActive) {
      this.state.longRunning.end();
    }

    this.updateScrollSnapBehavior();
    this.updateTravelRange(this.activeDetent, this.activeDetent);
    this.updateTravelStatus("idleInside");
    this.applyInertOutside();

    if (message?.type !== EVENTS.STEP) {
      this.executeAutoFocusOnPresent();
    }

    if (this.state.staging.matches("opening")) {
      this.state.staging.advance();
    }

    this.#setupIntersectionObserver();

    if (message?.type === EVENTS.STEP) {
      this.handleStepMessage(message);
    }
  }

  #setupIntersectionObserver() {
    if (this.swipeDisabled || this.swipeOutDisabledWithDetent) {
      return;
    }

    requestAnimationFrame(() => {
      if (
        this.state.openness.isOpen &&
        !this.swipeDisabled &&
        !this.swipeOutDisabledWithDetent
      ) {
        this.setupIntersectionObserver();
      }
    });
  }

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

  handleClosing() {
    this.focusManagement.captureFocusWasInsideOnClose();
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

  handleClosingWithoutAnimation() {
    this.state.skip.disableClosing();

    this.stackingAdapter.notifyBelowSheets(0);

    requestAnimationFrame(() => {
      this.handleStateTransition({ type: EVENTS.NEXT });
    });
  }

  handleClosedPending() {
    this.state.longRunning.end();
    this.#handleImmediateCloseIfNeeded();
    this.#scheduleFlushToSafeToUnmount();
  }

  #handleImmediateCloseIfNeeded() {
    if (!this.state.skip.isClosing) {
      return;
    }

    this.focusManagement.captureFocusWasInsideOnClose();
    this.state.beginImmediateClose(true);
    this.updateTravelStatus("travellingOut");
    this.state.skip.disableClosing();
    this.state.position.goOut();
    this.stackingAdapter.notifyParentOfClosingImmediate();

    this.stackingAdapter.notifyBelowSheets(0);
  }

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

  cleanupIntersectionObserver() {
    this.observerManager.cleanupIntersectionObserver();
  }

  @action
  registerView(view) {
    this.view = view;
    this.resetViewStyles();
    this.calculateDimensionsIfReady();
    this.setupResizeObserver();
    this.sheetRegistry?.sheetLayerStore?.recalculateInertOutside();
    this.#notifyElementsRegisteredIfReady();
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

  recalculateDimensionsFromResize() {
    this.dimensions = this.#calculateDimensions();

    if (this.state.openness.isOpen) {
      if (!this.swipeDisabled && !this.swipeOutDisabledWithDetent) {
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

  cleanup() {
    this.timeoutManager.cleanup();

    this.touchHandler.detach();
    this.observerManager.cleanup();
    this.unregisterBackdrop(this.backdrop);
    this.domAttributes.cleanup();
    this.focusManagement.cleanup();
    this.state.cleanup();
    this.stackingAdapter?.removeStagingFromStack();
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
  registerScrollContainer(scrollContainer) {
    this.scrollContainer = scrollContainer;

    this.calculateDimensionsIfReady();
    this.#notifyElementsRegisteredIfReady();
  }

  updateScrollSnapBehavior() {
    if (!this.scrollContainer || !this.dimensions || !this.content) {
      return;
    }

    this.domAttributes.enableScrollSnap();
  }

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
        this.updateTravelStatus("stepping");
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
    if (!this.scrollContainer || !this.scrollContainer.contains(event.target)) {
      return;
    }

    if (this.onFocusInside) {
      this.onFocusInside({
        nativeEvent: event,
      });
    }
  }

  onTouchGestureStart() {
    this.state.openness.swipeStart();
    this.updateTravelStatus("stepping");
  }

  onTouchGestureEnd() {
    this.state.openness.swipeEnd();
    if (this.state.openness.isOpen) {
      this.updateTravelStatus("idleInside");
    }

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

  @action
  registerDetentMarker(detentMarker) {
    this.detentMarkers.push(detentMarker);
    this.calculateDimensionsIfReady();
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

  @action
  open() {
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

  @action
  close() {
    const wasOpen = this.state.openness.isOpen;
    this.handleStateTransition({ type: EVENTS.CLOSE });

    if (wasOpen && this.state.openness.isOpen) {
      this.evaluateCloseMessage();
    }
  }

  @action
  requestDismiss() {
    if (this.rootComponent) {
      this.rootComponent.dismiss();
    }

    this.close();
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
    const rootRequestedDismiss =
      this.rootComponent?.effectivePresented === false;
    const canActuallyClose =
      this.state.position.isFront &&
      (!atInitialSegment || rootRequestedDismiss) &&
      !isSteppingWithSwipeOutDisabled;

    if (!canActuallyClose) {
      if (rootRequestedDismiss) {
        return;
      }

      if (this.rootComponent?.effectivePresented === false) {
        this.rootComponent.present();
      }
      return;
    }

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

    const nextDetent = this.detentManager.calculateStep("up");
    if (nextDetent !== null) {
      this.handleStateTransition({ type: EVENTS.STEP, detent: nextDetent });
    }
  }

  @action
  stepDown() {
    if (!this.state.openness.isOpen) {
      return;
    }

    const prevDetent = this.detentManager.calculateStep("down");
    if (prevDetent !== null) {
      this.handleStateTransition({ type: EVENTS.STEP, detent: prevDetent });
    }
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

  syncActiveDetent(activeDetent) {
    const shouldStep =
      this.state.openness.isOpen &&
      this.currentSegment[0] !== activeDetent &&
      this.currentSegment[1] !== activeDetent &&
      this.targetDetent !== activeDetent &&
      this.detentManager.isValidDetent(activeDetent);

    this.targetDetent = activeDetent;

    if (shouldStep) {
      this.handleStateTransition({ type: EVENTS.STEP, detent: activeDetent });
    }
  }

  resetViewStyles() {
    this.domAttributes.resetViewStyles();
  }
}
