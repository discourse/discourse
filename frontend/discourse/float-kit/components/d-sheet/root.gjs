import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { untrack } from "@glimmer/validator";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
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
  @tracked viewConfigurationProvider = null;
  sheetId = guidFor(this);
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
  syncViewConfiguration = modifier((_element, [sheet, provider]) => {
    provider?.configureSheetController(sheet);
  });
  advanceFlushingState = modifier((_element, [sheet, shouldFlushView]) => {
    if (!shouldFlushView || this.#flushingStateTask) {
      return;
    }

    this.#flushingStateTask = schedule("afterRender", () => {
      this.#flushingStateTask = null;

      if (
        !this.isDestroying &&
        !this.isDestroyed &&
        sheet === this.sheet &&
        sheet.shouldFlushView
      ) {
        sheet.timeoutManager.clear("pendingFlush");
        sheet.state.advanceClosedStatus();
      }
    });
  });
  registerRootElement = modifier((element, [sheet]) => {
    sheet.registerRootElement(element);

    return () => sheet.unregisterRootElement(element);
  });
  syncComponentId = modifier((_element, [componentId]) => {
    this.#updateComponentIdRegistration(componentId);
  });
  syncStackTarget = modifier((_element, [stackId]) => {
    this.#updateStackTarget(stackId);
  });
  #lastPresented;
  #flushingStateTask = null;
  #presentationTask = null;
  #pendingOpenSubscription = null;
  #pendingOpenToken = 0;
  #reopenAfterClose = false;
  #registeredComponentId = null;
  #sheetLayerActive = false;
  #stackSyncTask = null;
  #stackSyncToken = 0;
  #stackTarget = null;

  constructor(owner, args) {
    super(owner, args);

    this.#stackTarget = this.stackId;
    this.createController();
    this.sheet.rootComponent = this;

    if (!this.isControlled && this.args.defaultPresented) {
      this.internalPresented = true;
    }

    this.#updateComponentIdRegistration(this.args.componentId);

    registerDestructor(this, () => {
      this.#cancelFlushingStateTask();
      this.#cancelPresentationTask();
      this.#cancelStackSyncTask();
      this.#cleanupPendingOpen();
      this.#updateComponentIdRegistration(null);
      this.#cleanupCurrentSheet();
    });
  }

  #updateComponentIdRegistration(componentId) {
    const nextComponentId = componentId || null;

    if (nextComponentId === this.#registeredComponentId) {
      return;
    }

    if (this.#registeredComponentId) {
      this.sheetLayerStore.unregisterRoot(this.#registeredComponentId, this);
    }

    this.#registeredComponentId = nextComponentId;

    if (nextComponentId) {
      this.sheetLayerStore.registerRoot(nextComponentId, this);
    }
  }

  #cancelPresentationTask() {
    if (this.#presentationTask) {
      cancel(this.#presentationTask);
      this.#presentationTask = null;
    }
  }

  #cancelFlushingStateTask() {
    if (this.#flushingStateTask) {
      cancel(this.#flushingStateTask);
      this.#flushingStateTask = null;
    }
  }

  #cancelStackSyncTask() {
    this.#stackSyncToken++;

    if (this.#stackSyncTask) {
      cancel(this.#stackSyncTask);
      this.#stackSyncTask = null;
    }
  }

  #updateStackTarget(stackId) {
    const nextStackTarget = stackId || null;

    if (nextStackTarget === this.#stackTarget) {
      return;
    }

    this.#stackTarget = nextStackTarget;
    this.#scheduleStackTargetSync();
  }

  #scheduleStackTargetSync() {
    this.#cancelStackSyncTask();

    const stackTarget = this.#stackTarget;
    if (!stackTarget) {
      return;
    }

    const token = this.#stackSyncToken;
    this.#stackSyncTask = schedule("afterRender", () => {
      this.#stackSyncTask = null;

      if (
        token !== this.#stackSyncToken ||
        this.isDestroying ||
        this.isDestroyed ||
        stackTarget !== this.#stackTarget ||
        stackTarget !== this.stackId
      ) {
        return;
      }

      this.#reconcileStackTarget(stackTarget);
    });
  }

  #reconcileStackTarget(stackTarget) {
    if (this.#pendingOpenSubscription) {
      this.#cleanupPendingOpen();

      if (this.effectivePresented) {
        this.openSheet();
      }
      return;
    }

    if (
      this.sheet.stackId === stackTarget ||
      !this.sheet.state.openness.isOpen ||
      !this.sheet.state.staging.isNone
    ) {
      return;
    }

    this.sheetStackRegistry.reparentSheet(stackTarget, this.sheet);
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

  registerViewConfigurationProvider(provider) {
    this.viewConfigurationProvider = provider;
  }

  unregisterViewConfigurationProvider(provider) {
    if (this.viewConfigurationProvider === provider) {
      this.viewConfigurationProvider = null;
    }
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
    this.#pendingOpenToken++;

    if (this.#pendingOpenSubscription) {
      this.#pendingOpenSubscription();
      this.#pendingOpenSubscription = null;
    }
  }

  createController() {
    this.sheet = new Controller();
    this.sheet.id = this.sheetId;

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
        this.#scheduleStackTargetSync();
      },
    });

    this.sheet.state.subscribe("staging", {
      timing: "immediate",
      state: "none",
      callback: () => this.#scheduleStackTargetSync(),
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
      this.#reopenAfterClose =
        this.sheet.state.staging.isClosing ||
        this.sheet.state.openness.isClosing ||
        this.sheet.state.openness.isClosedPending;
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

    const pendingOpenToken = ++this.#pendingOpenToken;
    this.#pendingOpenSubscription = animatingParent.state.subscribe(
      "position",
      {
        timing: "immediate",
        state: ["out", "front.status:idle", "covered.status:idle"],
        callback: () => {
          if (pendingOpenToken !== this.#pendingOpenToken) {
            return;
          }

          this.#cleanupPendingOpen();
          if (!this.effectivePresented) {
            return;
          }

          if (this.stackId !== stackId) {
            this.openSheet();
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
      {{this.syncComponentId @componentId}}
      {{this.syncStackTarget @forComponent}}
      {{this.syncConfiguration
        this.sheet
        defaultActiveDetent=@defaultActiveDetent
        activeDetent=@activeDetent
        onActiveDetentChange=@onActiveDetentChange
        onSafeToUnmountChange=@onSafeToUnmountChange
        role=this.sheetRole
      }}
      {{this.syncViewConfiguration this.sheet this.viewConfigurationProvider}}
      {{this.advanceFlushingState this.sheet this.sheet.shouldFlushView}}
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
