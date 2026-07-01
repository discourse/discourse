import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import effect from "discourse/float-kit/helpers/effect";
import Controller from "./controller";

export default class Root extends Component {
  @service sheetRegistry;
  @service sheetLayerStore;
  @service sheetStackRegistry;

  @tracked sheet;
  @tracked internalPresented = false;
  #lastPresented;
  #pendingOpenSubscription = null;
  #reopenAfterClose = false;

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

  @action
  syncConfiguration(
    activeDetent,
    onActiveDetentChange,
    onSafeToUnmountChange,
    role,
    inertOutside
  ) {
    const sheet = this.sheet;

    schedule("afterRender", () => {
      if (this.sheet !== sheet) {
        return;
      }

      sheet.configure({
        activeDetent,
        onActiveDetentChange,
        onSafeToUnmountChange,
        role,
        inertOutside,
      });
    });
  }

  get isControlled() {
    return (
      this.args.presented !== undefined &&
      this.args.onPresentedChange !== undefined
    );
  }

  get effectivePresented() {
    return this.isControlled ? this.args.presented : this.internalPresented;
  }

  get shouldRenderView() {
    return this.effectivePresented || !this.sheet.safeToUnmount;
  }

  @action
  present() {
    if (this.isControlled) {
      this.args.onPresentedChange?.(true);
    } else {
      this.internalPresented = true;
    }
  }

  @action
  dismiss() {
    if (this.isControlled) {
      this.args.onPresentedChange?.(false);
    } else {
      this.internalPresented = false;
    }
  }

  @action
  registerRootElement(element) {
    this.sheet.registerRootElement(element);
  }

  @action
  unregisterRootElement(element) {
    this.sheet.unregisterRootElement(element);
  }

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

  #cleanupPendingOpen() {
    if (this.#pendingOpenSubscription) {
      this.#pendingOpenSubscription();
      this.#pendingOpenSubscription = null;
    }
  }

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

  get stackId() {
    return this.args.forComponent ?? null;
  }

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

  doOpenSheet(stackId) {
    this.sheetRegistry.register(this.sheet);

    if (stackId) {
      this.sheetStackRegistry.registerSheetWithStack(stackId, this.sheet);
    }

    this.sheet.open();
  }

  @action
  handleSheetClosed() {
    const shouldReopen = this.#reopenAfterClose;
    this.#reopenAfterClose = false;

    this.#cleanupCurrentSheet(true);
    this.createController();
    this.sheet.rootComponent = this;

    if (shouldReopen) {
      this.openSheet();
    } else if (!this.isControlled) {
      this.internalPresented = false;
    }

    this.args.onClosed?.();
  }

  <template>
    {{effect this.syncPresented this.effectivePresented}}
    {{effect
      this.syncConfiguration
      @activeDetent
      @onActiveDetentChange
      @onSafeToUnmountChange
      @role
      @inertOutside
    }}
    <div
      data-d-sheet="root"
      {{didInsert this.registerRootElement}}
      {{willDestroy this.unregisterRootElement}}
      ...attributes
    >
      {{yield this.sheet}}
    </div>
  </template>
}
