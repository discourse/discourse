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
  /** @type {import("discourse/float-kit/services/sheet-registry").default} */
  @service sheetRegistry;

  /** @type {import("discourse/float-kit/services/sheet-layer-store").default} */
  @service sheetLayerStore;

  /** @type {import("discourse/float-kit/services/sheet-stack-registry").default} */
  @service sheetStackRegistry;

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
   * Tracks the last known presented value to detect changes in syncPresented.
   *
   * @type {boolean|undefined}
   * @private
   */
  #lastPresented;

  /**
   * Unsubscribe function for a deferred open waiting on a parent sheet animation.
   *
   * @type {Function|null}
   * @private
   */
  #pendingOpenSubscription = null;

  /**
   * Whether an open request happened while closing and should be replayed
   * once the controller reaches safe-to-unmount.
   *
   * @type {boolean}
   * @private
   */
  #reopenAfterClose = false;

  /**
   * Initializes the controller, registers with the sheet registry, and sets up destructors.
   *
   * @param {unknown} owner - The Ember owner instance
   * @param {Object} args - Component arguments
   */
  constructor(owner, args) {
    super(owner, args);

    this.createController();
    this.sheet.rootComponent = this;

    // Apply defaultPresented for uncontrolled mode
    if (!this.isControlled && this.args.defaultPresented) {
      this.internalPresented = true;
    }

    if (this.args.componentId) {
      this.sheetLayerStore.registerRoot(this.args.componentId, this);
    }

    registerDestructor(this, () => {
      this.#cleanupPendingOpen();
      if (this.args.componentId) {
        this.sheetLayerStore.unregisterRoot(this.args.componentId);
      }
      this.#cleanupCurrentSheet();
    });
  }

  /**
   * Syncs the effective presented state, opening or closing the sheet when it changes.
   * Used as an effect callback to react to presented value transitions.
   *
   * @param {boolean} presented - The current effective presented state
   */
  @action
  syncPresented(presented) {
    if (presented === this.#lastPresented) {
      return;
    }

    const previous = this.#lastPresented;
    this.#lastPresented = presented;

    schedule("afterRender", () => {
      if (presented) {
        this.openSheet();
      } else if (previous !== undefined) {
        this.#cleanupPendingOpen();
        this.#reopenAfterClose = false;
        this.sheet.close();
      }
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
  #cleanupCurrentSheet(focusOnDismiss = false) {
    if (this.sheet.stackId) {
      this.sheetStackRegistry.unregisterSheetFromStack(this.sheet);
    }
    this.sheetRegistry.unregister(this.sheet);

    if (focusOnDismiss) {
      this.sheetLayerStore.flushInertOutside();
      this.sheet.executeAutoFocusOnDismiss();
    }

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

    this.sheet.state.subscribe("openness", {
      timing: "immediate",
      state: "closed.status:safe-to-unmount",
      callback: () => this.handleSheetClosed(),
    });

    this.sheet.state.subscribe("openness", {
      timing: "immediate",
      state: "open",
      callback: () => {
        this.#reopenAfterClose = false;
      },
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
      inertOutside: this.args.inertOutside,
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
   * @param {string|null} stackId - The stack ID to look up the topmost sheet
   * @returns {Controller|null} Parent sheet if animating, null if ready
   */
  getAnimatingParentSheet(stackId) {
    if (!stackId) {
      return null;
    }

    const topmostSheet =
      this.sheetStackRegistry.getTopmostSheetInStack(stackId);
    if (!topmostSheet?.state?.position) {
      return null;
    }

    return topmostSheet.state.position.isIdle ? null : topmostSheet;
  }

  /**
   * Opens the sheet, deferring if a parent sheet in the stack is still animating.
   * Subscribes to the parent's position state machine to wait for idle before opening.
   */
  @action
  openSheet() {
    this.#cleanupPendingOpen();

    if (!this.sheet.safeToUnmount) {
      this.#reopenAfterClose = true;
      this.sheet.open();
      return;
    }

    this.#reopenAfterClose = false;

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

    this.#pendingOpenSubscription = animatingParent.state.subscribe(
      "position",
      {
        timing: "immediate",
        state: ["out", "front.status:idle", "covered.status:idle"],
        callback: () => {
          this.#cleanupPendingOpen();
          if (!this.effectivePresented) {
            return;
          }
          this.doOpenSheet(stackId);
        },
      }
    );
  }

  /**
   * Register the sheet and open it.
   *
   * @param {string|null} stackId - The stack ID to associate with the sheet
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
    const shouldReopen = this.#reopenAfterClose;
    this.#reopenAfterClose = false;

    this.#cleanupCurrentSheet(true);
    this.createController();
    this.sheet.rootComponent = this;

    if (shouldReopen) {
      this.openSheet();
    } else {
      this.dismiss();
    }

    this.args.onClosed?.();
  }

  <template>
    {{effect this.syncPresented this.effectivePresented}}
    {{yield this.sheet}}
  </template>
}
