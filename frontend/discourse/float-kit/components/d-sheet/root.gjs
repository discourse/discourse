import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { untrack } from "@glimmer/validator";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import Controller from "./controller";
import outletAnimationModifier from "./outlet-animation-modifier";

export default class Root extends Component {
  @service sheetRegistry;
  @service sheetLayerStore;
  @service sheetStackRegistry;

  @tracked sheet;
  @tracked internalPresented = false;
  syncPresented = modifier((_element, [presented]) => {
    if (presented === this.#lastPresented) {
      return;
    }

    this.#cancelPresentationTask();
    const previous = this.#lastPresented;
    this.#lastPresented = presented;

    this.#presentationTask = schedule("afterRender", () => {
      this.#presentationTask = null;

      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      if (presented) {
        this.openSheet();
      } else if (previous !== undefined) {
        this.#cleanupPendingOpen();
        this.#reopenAfterClose = false;
        this.sheet.close();
      }
    });
  });
  syncConfiguration = modifier((_element, [sheet], options) => {
    const configuration = { ...options };
    untrack(() => sheet.configure(configuration));
  });
  registerRootElement = modifier((element, [sheet]) => {
    sheet.registerRootElement(element);

    return () => sheet.unregisterRootElement(element);
  });
  #lastPresented;
  #presentationTask = null;
  #pendingOpenSubscription = null;
  #reopenAfterClose = false;
  #sheetLayerActive = false;

  constructor(owner, args) {
    super(owner, args);

    this.createController();
    this.sheet.rootComponent = this;

    if (!this.isControlled && this.args.defaultPresented) {
      this.internalPresented = true;
    }

    if (this.args.componentId) {
      this.sheetLayerStore.registerRoot(this.args.componentId, this);
    }

    registerDestructor(this, () => {
      this.#cancelPresentationTask();
      this.#cleanupPendingOpen();
      if (this.args.componentId) {
        this.sheetLayerStore.unregisterRoot(this.args.componentId);
      }
      this.#cleanupCurrentSheet();
    });
  }

  #cancelPresentationTask() {
    if (this.#presentationTask) {
      cancel(this.#presentationTask);
      this.#presentationTask = null;
    }
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

  get sheetRole() {
    return this.args.sheetRole !== undefined
      ? this.args.sheetRole
      : this.args.role;
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

  #cleanupCurrentSheet(focusOnDismiss = false) {
    if (this.sheet.stackId) {
      this.sheetStackRegistry.unregisterSheetFromStack(this.sheet);
    }
    this.deactivateSheetLayer(focusOnDismiss);

    this.sheet.cleanup();
  }

  #activateSheetLayer() {
    if (this.#sheetLayerActive) {
      return;
    }

    this.sheetRegistry.register(this.sheet);
    this.#sheetLayerActive = true;
  }

  deactivateSheetLayer(focusOnDismiss = false) {
    if (!this.#sheetLayerActive) {
      return;
    }

    this.sheetRegistry.unregister(this.sheet);
    this.#sheetLayerActive = false;

    if (focusOnDismiss) {
      this.sheetLayerStore.flushInertOutside();
      this.sheet.executeAutoFocusOnDismiss();
    }
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

    this.sheet.configure({
      defaultActiveDetent: this.args.defaultActiveDetent,
      activeDetent: this.args.activeDetent,
      onActiveDetentChange: this.args.onActiveDetentChange,
      onSafeToUnmountChange: this.args.onSafeToUnmountChange,
      role: this.sheetRole,
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
      this.#activateSheetLayer();
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
    this.#activateSheetLayer();

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
    <div
      {{this.syncPresented this.effectivePresented}}
      {{this.syncConfiguration
        this.sheet
        activeDetent=@activeDetent
        onActiveDetentChange=@onActiveDetentChange
        onSafeToUnmountChange=@onSafeToUnmountChange
        role=this.sheetRole
        inertOutside=@inertOutside
      }}
      {{this.registerRootElement this.sheet}}
      {{outletAnimationModifier this.sheet @travelAnimation @stackingAnimation}}
      ...attributes
      {{mergeSheetAttributes
        "outlet"
        "root"
        (if this.sheet.isStackAnimating "animating")
      }}
    >
      {{yield this.sheet}}
    </div>
  </template>
}
