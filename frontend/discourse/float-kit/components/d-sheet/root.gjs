import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { helper as helperFn } from "@ember/component/helper";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import Controller from "./controller";

/**
 * Root component for the sheet. Manages presentation and detent state.
 * Behavioral/visual props should be passed to View, not Root.
 *
 * Controlled mode:
 *   <DSheet.Root @presented={{this.isOpen}} @onPresentedChange={{this.setIsOpen}}>
 *
 * Uncontrolled mode:
 *   <DSheet.Root> or <DSheet.Root @defaultPresented={{true}}>
 *
 * @component DSheetRoot
 * @param {string} componentId - Optional ID to identify this sheet for forComponent lookups
 * @param {boolean} defaultPresented - Whether the sheet is initially presented (default: false, uncontrolled mode only)
 * @param {boolean} presented - Controls the presented state (controlled mode)
 * @param {Function} onPresentedChange - Callback when presented state changes (controlled mode)
 * @param {number} defaultActiveDetent - Initial detent index (defaults to 1)
 * @param {number} activeDetent - Controlled detent index (for controlled mode)
 * @param {Function} onActiveDetentChange - Callback when active detent changes
 * @param {string} forComponent - Stack association: "closest" or explicit stackId
 * @param {string} role - Accessibility role (default: "dialog")
 * @param {boolean} inertOutside - Whether to make content outside sheet inert (default: true)
 * @param {Function} onSafeToUnmountChange - Callback when safe to unmount changes
 * @param {Function} onClosed - Callback when sheet has fully closed
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

  /**
   * Internal presented state for uncontrolled mode.
   *
   * @type {boolean}
   */
  @tracked internalPresented = false;

  /**
   * Inline helper that syncs presented state changes with the controller.
   * Runs on each render when effectivePresented changes.
   */
  syncPresented = helperFn(([presented]) => {
    const previous = this.#lastPresented;
    this.#lastPresented = presented;

    if (previous === undefined) {
      // Initial render - open if presented
      if (presented) {
        schedule("afterRender", () => this.openSheet());
      }
      return;
    }

    if (presented && !previous && this.sheet.safeToUnmount) {
      schedule("afterRender", () => this.openSheet());
    } else if (!presented && previous) {
      schedule("afterRender", () => this.sheet.close());
    }
  });
  /**
   * Tracks the last presented value we acted upon.
   *
   * @type {boolean|undefined}
   */
  #lastPresented;

  /** @type {Function|null} */
  #pendingOpenSubscription = null;

  constructor(owner, args) {
    super(owner, args);

    this.createController();
    this.sheet.rootComponent = this;

    // Apply defaultPresented for uncontrolled mode
    if (!this.isControlled && this.args.defaultPresented) {
      this.internalPresented = true;
    }

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
   * Controlled mode is active when both @presented and @onPresentedChange are provided.
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
   * The effective presented state, from either controlled or uncontrolled source.
   *
   * @type {boolean}
   */
  get effectivePresented() {
    return this.isControlled ? this.args.presented : this.internalPresented;
  }

  /**
   * Whether the View should be rendered.
   * True when sheet should be visible OR during exit animation.
   *
   * @type {boolean}
   */
  get shouldRenderView() {
    return this.effectivePresented || !this.sheet.safeToUnmount;
  }

  /**
   * Present the sheet.
   * In controlled mode, calls onPresentedChange(true).
   * In uncontrolled mode, sets internal state.
   */
  @action
  present() {
    if (this.isControlled) {
      this.args.onPresentedChange?.(true);
    } else {
      this.internalPresented = true;
    }
  }

  /**
   * Dismiss the sheet.
   * In controlled mode, calls onPresentedChange(false).
   * In uncontrolled mode, sets internal state.
   */
  @action
  dismiss() {
    if (this.isControlled) {
      this.args.onPresentedChange?.(false);
    } else {
      this.internalPresented = false;
    }
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
      state: "closed.status:safe-to-unmount",
      callback: () => this.handleSheetClosed(),
    });

    this.sheet.onTravelProgressChange = (progress) => {
      this.sheetStackRegistry.updateSheetTravelProgress(this.sheet, progress);
    };

    this.sheet.configure({
      defaultActiveDetent: this.args.defaultActiveDetent,
      activeDetent: this.args.activeDetent,
      onActiveDetentChange: this.args.onActiveDetentChange,
      onSafeToUnmountChange: this.args.onSafeToUnmountChange,
      role: this.args.role,
      themeColorManager: this.themeColorManager,
      sheetStackRegistry: this.sheetStackRegistry,
      sheetRegistry: this.sheetRegistry,
    });
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
      topmostSheet.positionMachine?.matches("front.status:idle") ||
      topmostSheet.positionMachine?.matches("covered.status:idle");

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
      state: ["out", "front.status:idle", "covered.status:idle"],
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

    this.dismiss();
    this.args.onClosed?.();
  }

  <template>
    {{this.syncPresented this.effectivePresented}}
    {{yield this.sheet}}
  </template>
}
