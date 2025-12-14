import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import effect from "discourse/float-kit/helpers/effect";
import Controller from "./controller";

/**
 * Root component for the sheet. Manages presentation and detent state.
 * Behavioral/visual props should be passed to View, not Root.
 *
 * @component DSheetRoot
 * @param {string} componentId - Optional ID to identify this sheet for forComponent lookups
 * @param {boolean} defaultPresented - Whether the sheet is initially presented (default: false, uncontrolled mode only)
 * @param {boolean} presented - Controls the presented state (required for controlled mode)
 * @param {Function} onPresentedChange - Callback when presented state changes (required for controlled mode)
 * @param {number} defaultActiveDetent - Initial detent index (defaults to 1)
 * @param {number} activeDetent - Controlled detent index (for controlled mode)
 * @param {Function} onActiveDetentChange - Callback when active detent changes
 * @param {string} forComponent - Stack association: "closest" or explicit stackId
 * @param {string} role - Accessibility role (default: "dialog")
 * @param {boolean} inertOutside - Whether to make content outside sheet inert (default: true)
 */
export default class Root extends Component {
  @service sheetRegistry;
  @service sheetStackRegistry;
  @service themeColorManager;

  /**
   * The sheet controller instance. Created immediately and replaced after each close cycle.
   *
   * @type {Controller}
   */
  @tracked sheet;

  /** @type {boolean|undefined} */
  #previousPresented;

  /** @type {boolean} */
  #hasAppliedDefaultPresented = false;

  /** @type {Function|null} */
  #pendingOpenSubscription = null;

  constructor(owner, args) {
    super(owner, args);

    this.createController();
    this.sheet.rootComponent = this;

    if (this.args.componentId) {
      this.sheetRegistry.registerRoot(this.args.componentId, this);
    }

    registerDestructor(this, () => {
      this.#cleanupPendingOpen();
      if (this.args.componentId) {
        this.sheetRegistry.unregisterRoot(this.args.componentId);
      }
      this.#cleanupCurrentSheet();
    });
  }

  /**
   * Whether the component is in controlled mode.
   * Controlled mode requires both @presented and @onPresentedChange.
   *
   * @type {boolean}
   */
  get isControlled() {
    return (
      this.args.presented !== undefined &&
      this.args.onPresentedChange !== undefined
    );
  }

  /**
   * Cleanup the current sheet controller.
   * Unregisters from stack and registry, then calls controller cleanup.
   *
   * @private
   */
  #cleanupCurrentSheet() {
    if (this.sheet.stackId) {
      this.sheetStackRegistry.unregisterSheetFromStack(this.sheet);
    }
    this.sheetRegistry.unregister(this.sheet);
    this.sheet.cleanup();
  }

  /**
   * Cleanup any pending open subscription.
   *
   * @private
   */
  #cleanupPendingOpen() {
    if (this.#pendingOpenSubscription) {
      this.#pendingOpenSubscription();
      this.#pendingOpenSubscription = null;
    }
  }

  /**
   * Create a new Controller instance with subscriptions and initial configuration.
   * Called in constructor and after each close cycle to prepare for the next open.
   *
   * @private
   */
  createController() {
    this.sheet = new Controller();

    this.sheet.stateMachine.subscribe({
      timing: "immediate",
      state: "closed.safe-to-unmount",
      callback: () => this.handleSheetClosed(),
    });

    this.sheet.onTravelProgressChange = (progress) => {
      this.sheetStackRegistry.updateSheetTravelProgress(this.sheet, progress);
    };

    this.sheet.configure({
      defaultActiveDetent: this.args.defaultActiveDetent,
      activeDetent: this.args.activeDetent,
      onActiveDetentChange: this.args.onActiveDetentChange,
      role: this.args.role,
      themeColorManager: this.themeColorManager,
      sheetStackRegistry: this.sheetStackRegistry,
      sheetRegistry: this.sheetRegistry,
    });
  }

  /**
   * Whether the View should be rendered.
   * True when sheet should be visible OR during exit animation.
   *
   * @type {boolean}
   */
  get shouldRenderView() {
    if (this.isControlled) {
      return this.args.presented || !this.sheet.safeToUnmount;
    }
    return !this.sheet.safeToUnmount;
  }

  /**
   * Reacts to @presented and @defaultPresented changes.
   * Handles both controlled mode (reacting to @presented) and
   * uncontrolled mode (applying @defaultPresented once).
   *
   * @param {boolean} presented - The controlled presented state
   * @param {boolean} defaultPresented - The initial presented state for uncontrolled mode
   */
  @action
  syncPresentedState(presented, defaultPresented) {
    // Controlled mode: react to @presented changes
    if (this.isControlled) {
      const previous = this.#previousPresented;
      this.#previousPresented = presented;

      if (presented && !previous && this.sheet.safeToUnmount) {
        schedule("afterRender", () => this.openSheet());
      } else if (!presented && previous) {
        schedule("afterRender", () => this.sheet.close());
      }
    }

    // Uncontrolled mode: apply defaultPresented once
    if (
      !this.#hasAppliedDefaultPresented &&
      !this.isControlled &&
      defaultPresented
    ) {
      this.#hasAppliedDefaultPresented = true;
      schedule("afterRender", () => this.openSheet());
    }
  }

  /**
   * The stack ID based on forComponent prop.
   *
   * @type {string|null}
   */
  get stackId() {
    return this.args.forComponent ?? null;
  }

  /**
   * Check if parent sheet in stack is ready (in position:idle state).
   *
   * @returns {Object|null} Parent sheet if animating, null if ready
   */
  getAnimatingParentSheet(stackId) {
    if (!stackId) {
      return null;
    }

    const topmostSheet =
      this.sheetStackRegistry.getTopmostSheetInStack(stackId);
    if (!topmostSheet) {
      return null;
    }

    const positionState = topmostSheet.positionMachine?.current;
    if (!positionState) {
      return null;
    }

    const isIdle =
      positionState === "out" ||
      positionState === "front-idle" ||
      positionState === "covered-idle";

    return isIdle ? null : topmostSheet;
  }

  /**
   * Open the sheet, waiting for parent animations if needed.
   */
  @action
  openSheet() {
    const stackId = this.stackId;

    if (!stackId) {
      this.doOpenSheet(null);
      return;
    }

    const animatingParent = this.getAnimatingParentSheet(stackId);

    if (!animatingParent) {
      this.doOpenSheet(stackId);
      return;
    }

    this.#pendingOpenSubscription = animatingParent.positionMachine.subscribe({
      timing: "immediate",
      state: ["front-idle", "covered-idle", "out"],
      callback: () => {
        this.#cleanupPendingOpen();
        this.doOpenSheet(stackId);
      },
    });
  }

  /**
   * Register the sheet and open it.
   *
   * @param {string|null} stackId
   * @private
   */
  doOpenSheet(stackId) {
    this.sheetRegistry.register(this.sheet);

    if (stackId) {
      this.sheetStackRegistry.registerSheetWithStack(stackId, this.sheet);
    }

    this.sheet.open();
  }

  /**
   * Handle sheet closed state for cleanup.
   * Creates a fresh controller for the next open cycle.
   *
   * @private
   */
  @action
  handleSheetClosed() {
    this.#cleanupCurrentSheet();
    this.createController();
    this.sheet.rootComponent = this;

    if (this.isControlled && this.args.presented) {
      this.args.onPresentedChange?.(false);
    }
  }

  <template>
    {{effect this.syncPresentedState @presented @defaultPresented}}
    {{yield this.sheet}}
  </template>
}
