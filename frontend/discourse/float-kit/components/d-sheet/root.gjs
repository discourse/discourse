import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import Backdrop from "./backdrop";
import Controller from "./controller";
import Description from "./description";
import Handle from "./handle";
import Portal from "./portal";
import Title from "./title";
import Trigger from "./trigger";
import View from "./view";

/**
 * Root component for the sheet. Manages presentation and detent state.
 * Behavioral/visual props should be passed to View, not Root.
 *
 * @component DSheetRoot
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
   * The sheet controller instance, created fresh each open cycle.
   *
   * @type {Controller|null}
   */
  @tracked sheet = null;
  /**
   * Track the previous presented value to detect changes.
   *
   * @type {boolean|undefined}
   */
  previousPresented = undefined;

  /**
   * Track whether defaultPresented has been applied.
   *
   * @type {boolean}
   */
  hasAppliedDefaultPresented = false;

  constructor(owner, args) {
    super(owner, args);

    registerDestructor(this, () => {
      if (this.sheet) {
        if (this.sheet.stackId) {
          this.sheetStackRegistry.unregisterSheetFromStack(this.sheet);
        }
        this.sheetRegistry.unregister(this.sheet);
        this.sheet.cleanup();
        this.sheet = null;
      }
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
   * Whether the View should be rendered.
   * True when sheet should be visible OR during exit animation.
   *
   * @type {boolean}
   */
  get shouldRenderView() {
    if (!this.sheet) {
      return false;
    }
    if (this.isControlled) {
      return this.args.presented || !this.sheet.safeToUnmount;
    }
    return !this.sheet.safeToUnmount;
  }

  /**
   * Reacts to @presented changes in controlled mode.
   * Called during render via helper invocation.
   *
   * @param {boolean} presented
   */
  @action
  syncPresented(presented) {
    if (!this.isControlled) {
      return;
    }

    const previousPresented = this.previousPresented;
    this.previousPresented = presented;

    const safeToUnmount = this.sheet?.safeToUnmount ?? true;

    if (presented && !previousPresented && safeToUnmount) {
      schedule("afterRender", () => {
        this.openSheet();
      });
    } else if (!presented && previousPresented && this.sheet) {
      schedule("afterRender", () => {
        this.sheet?.close();
      });
    }
  }

  /**
   * Applies defaultPresented on initial render (uncontrolled mode only).
   * Called during render via helper invocation.
   */
  @action
  applyDefaultPresented() {
    if (this.hasAppliedDefaultPresented || this.isControlled) {
      return;
    }

    this.hasAppliedDefaultPresented = true;

    if (this.args.defaultPresented) {
      schedule("afterRender", () => {
        this.openSheet();
      });
    }
  }

  /**
   * Resolve the stack ID based on forComponent prop.
   *
   * @returns {string|null}
   */
  resolveStackId() {
    return this.args.forComponent || null;
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
    const stackId = this.resolveStackId();
    const animatingParent = this.getAnimatingParentSheet(stackId);

    if (animatingParent) {
      const checkAndOpen = () => {
        const stillAnimating = this.getAnimatingParentSheet(stackId);
        if (!stillAnimating) {
          this.doOpenSheet(stackId);
        } else {
          requestAnimationFrame(checkAndOpen);
        }
      };

      requestAnimationFrame(checkAndOpen);
      return;
    }

    this.doOpenSheet(stackId);
  }

  /**
   * Register the sheet and open it.
   *
   * @param {string|null} stackId
   * @private
   */
  doOpenSheet(stackId) {
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

    this.sheetRegistry.register(this.sheet);

    if (stackId) {
      this.sheetStackRegistry.registerSheetWithStack(stackId, this.sheet);
    }

    this.sheet.open();
  }

  /**
   * Handle sheet closed state for cleanup.
   *
   * @private
   */
  @action
  handleSheetClosed() {
    if (this.sheet) {
      if (this.sheet.stackId) {
        this.sheetStackRegistry.unregisterSheetFromStack(this.sheet);
      }
      this.sheetRegistry.unregister(this.sheet);
      this.sheet.cleanup();
      this.sheet = null;
    }

    if (this.isControlled && this.args.presented) {
      this.args.onPresentedChange?.(false);
    }
  }

  <template>
    {{(this.syncPresented @presented)}}
    {{(this.applyDefaultPresented)}}

    {{yield this.sheet}}
  </template>
}
