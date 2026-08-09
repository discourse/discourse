import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module("Unit | Service | sheet-layer-store", function (hooks) {
  setupTest(hooks);

  test("stale cleanup cannot unregister a replacement Root", function (assert) {
    const store = this.owner.lookup("service:sheet-layer-store");
    const originalRoot = {};
    const replacementRoot = {};

    store.registerRoot("shared-sheet", originalRoot);
    store.registerRoot("shared-sheet", replacementRoot);
    store.unregisterRoot("shared-sheet", originalRoot);

    assert.strictEqual(
      store.getRootByComponentId("shared-sheet"),
      replacementRoot,
      "registration cleanup is scoped to its owning Root"
    );

    store.unregisterRoot("shared-sheet", replacementRoot);
  });

  test("stale cleanup cannot unregister a replacement controller", function (assert) {
    const store = this.owner.lookup("service:sheet-layer-store");
    const originalController = { id: "shared-controller" };
    const replacementController = { id: "shared-controller" };

    store.registerSheet(originalController);
    store.registerSheet(replacementController);
    store.unregisterSheet(originalController);

    assert.false(
      store.hasSheet(originalController),
      "the stale controller no longer owns the registration"
    );
    assert.true(
      store.hasSheet(replacementController),
      "the replacement keeps its registration"
    );

    store.unregisterSheet(replacementController);
  });

  test("finds the nearest active sheet containing a nested Root", function (assert) {
    const store = this.owner.lookup("service:sheet-layer-store");
    const parentView = document.createElement("div");
    const childRoot = document.createElement("div");
    const parent = { id: "parent", view: parentView };
    const child = { id: "child", rootElement: childRoot };

    parentView.append(childRoot);
    document.body.append(parentView);
    store.registerSheet(parent);
    store.registerSheet(child);

    assert.strictEqual(
      store.findContainingSheet(childRoot, child),
      parent,
      "the child resolves its containing parent instead of itself"
    );

    store.unregisterSheet(child);
    store.unregisterSheet(parent);
    parentView.remove();
  });

  test("only dismisses for Silk's outside-click boundaries", function (assert) {
    const store = this.owner.lookup("service:sheet-layer-store");
    const outside = document.createElement("div");
    const view = document.createElement("div");
    const scrollContainer = document.createElement("div");
    const scrollContent = document.createElement("div");
    const backdrop = document.createElement("div");
    const viewSibling = document.createElement("button");
    const dismissedTargets = [];
    const sheet = {
      id: "click-boundaries",
      backdrop,
      canAcceptDismissRequest: true,
      onClickOutside: null,
      requestDismiss() {
        dismissedTargets.push(currentTarget);
      },
      role: "dialog",
      scrollContainer,
      view,
    };
    let currentTarget;

    scrollContainer.append(scrollContent);
    view.append(scrollContainer, backdrop, viewSibling);
    document.body.append(outside, view);
    store.registerSheet(sheet);

    const click = (target) => {
      currentTarget = target;
      store.consumeClickOutside({ target });
    };

    try {
      click(viewSibling);
      click(scrollContent);

      assert.deepEqual(
        dismissedTargets,
        [],
        "ordinary descendants and View siblings stay inside the layer"
      );

      click(scrollContainer);
      click(backdrop);
      click(outside);

      assert.deepEqual(
        dismissedTargets,
        [scrollContainer, backdrop, outside],
        "the empty scroll port, backdrop, and external elements dismiss"
      );
    } finally {
      store.unregisterSheet(sheet);
      outside.remove();
      view.remove();
    }
  });

  test("dismiss autofocus preserves newer connected outside focus", function (assert) {
    const store = this.owner.lookup("service:sheet-layer-store");
    const trigger = document.createElement("button");
    const view = document.createElement("div");
    const inside = document.createElement("button");
    const outside = document.createElement("button");
    const onDismissAutoFocus = sinon.spy();

    view.append(inside);
    document.querySelector("#qunit-fixture").append(trigger, view, outside);

    store.setLayerFocusedLastBeforeShowing("focus-sheet", trigger);
    inside.focus();
    store.captureLayerFocusWasInsideOnClose("focus-sheet", view);
    outside.focus();

    store.executeLayerDismissAutoFocus({
      onDismissAutoFocus,
      sheetId: "focus-sheet",
      viewElement: view,
    });

    assert.strictEqual(
      document.activeElement,
      outside,
      "dismissal does not steal focus that moved outside after closing began"
    );
    assert.false(
      onDismissAutoFocus.called,
      "the dismiss behavior is not invoked after focus deliberately moved outside"
    );
  });

  test("dismiss autofocus uses source-literal falsey behavior", function (assert) {
    const store = this.owner.lookup("service:sheet-layer-store");
    const trigger = document.createElement("button");
    const view = document.createElement("div");
    const inside = document.createElement("button");

    view.append(inside);
    document.querySelector("#qunit-fixture").append(trigger, view);

    store.setLayerFocusedLastBeforeShowing("focus-sheet", trigger);
    inside.focus();
    store.captureLayerFocusWasInsideOnClose("focus-sheet", view);

    store.executeLayerDismissAutoFocus({
      onDismissAutoFocus: { focus: null },
      sheetId: "focus-sheet",
      viewElement: view,
    });

    assert.strictEqual(
      document.activeElement,
      inside,
      "an explicit null focus behavior does not restore the trigger"
    );
  });

  test("Escape behavior fields use source-literal falsey values", function (assert) {
    const store = this.owner.lookup("service:sheet-layer-store");
    const dismissed = [];
    let preventDefaultCalls = 0;
    const underlyingSheet = {
      canAcceptDismissRequest: true,
      id: "underlying-sheet",
      onEscapeKeyDown: {
        dismiss: true,
        nativePreventDefault: false,
        stopOverlayPropagation: true,
      },
      requestDismiss() {
        dismissed.push(this.id);
      },
      role: "dialog",
    };
    const topSheet = {
      canAcceptDismissRequest: true,
      id: "top-sheet",
      onEscapeKeyDown: {
        dismiss: null,
        nativePreventDefault: null,
        stopOverlayPropagation: null,
      },
      requestDismiss() {
        dismissed.push(this.id);
      },
      role: "dialog",
    };

    store.registerSheet(underlyingSheet);
    store.registerSheet(topSheet);

    try {
      store.consumeEscapeKey({
        preventDefault() {
          preventDefaultCalls++;
        },
      });

      assert.deepEqual(
        dismissed,
        ["underlying-sheet"],
        "null skips the top dismissal and allows overlay propagation"
      );
      assert.strictEqual(
        preventDefaultCalls,
        0,
        "null does not prevent the native Escape behavior"
      );
    } finally {
      store.unregisterSheet(topSheet);
      store.unregisterSheet(underlyingSheet);
    }
  });

  test("clears its scheduled inert recalculation after it runs", function (assert) {
    const store = this.owner.lookup("service:sheet-layer-store");

    run(() => store.recalculateInertOutside());

    assert.strictEqual(
      store.recalculateInertTimeout,
      null,
      "the completed schedule is no longer retained"
    );
  });

  test("reuses inert containment until the protected roots change", function (assert) {
    const store = this.owner.lookup("service:sheet-layer-store");
    const inertElement = document.createElement("div");
    const layerHost = document.createElement("div");
    const automaticLayer = document.createElement("div");
    const view = document.createElement("div");
    const sheet = { id: "inert-sheet", inertOutside: true, view };
    let inert = false;
    let inertAssignments = 0;

    Object.defineProperty(inertElement, "inert", {
      configurable: true,
      get() {
        return inert;
      },
      set(value) {
        inert = value;
        inertAssignments++;
        this.toggleAttribute("inert", value);
      },
    });

    layerHost.append(automaticLayer);
    document.body.append(inertElement, layerHost, view);
    store.registerSheet(sheet);

    try {
      store.flushInertOutside();

      const initialBeforeGuard = view.previousElementSibling;
      const initialAfterGuard = view.nextElementSibling;
      assert.true(
        initialBeforeGuard.matches('[data-d-sheet~="focus-guard"]'),
        "focus containment is installed"
      );
      assert.strictEqual(inertAssignments, 1, "the outside element is inerted");

      store.flushInertOutside();

      assert.strictEqual(
        view.previousElementSibling,
        initialBeforeGuard,
        "unchanged roots keep the preceding focus guard"
      );
      assert.strictEqual(
        view.nextElementSibling,
        initialAfterGuard,
        "unchanged roots keep the following focus guard"
      );
      assert.strictEqual(
        inertAssignments,
        1,
        "unchanged roots do not assign inert again"
      );

      store.registerAutomaticLayerElement(automaticLayer);
      store.flushInertOutside();

      const rebuiltBeforeGuard = view.previousElementSibling;
      const rebuiltAfterGuard = view.nextElementSibling;
      assert.notStrictEqual(
        rebuiltBeforeGuard,
        initialBeforeGuard,
        "a protected-root change rebuilds focus containment"
      );
      assert.false(
        initialBeforeGuard.isConnected,
        "the previous focus containment is cleaned up"
      );
      assert.strictEqual(
        inertAssignments,
        3,
        "the rebuild restores and reapplies inert once"
      );

      store.flushInertOutside();

      assert.strictEqual(
        view.previousElementSibling,
        rebuiltBeforeGuard,
        "the rebuilt preceding guard is reused"
      );
      assert.strictEqual(
        view.nextElementSibling,
        rebuiltAfterGuard,
        "the rebuilt following guard is reused"
      );
      assert.strictEqual(
        inertAssignments,
        3,
        "the stable protected-root set remains assignment-free"
      );
    } finally {
      store.unregisterAutomaticLayerElement(automaticLayer);
      store.unregisterSheet(sheet);
      store.flushInertOutside();
      inertElement.remove();
      layerHost.remove();
      view.remove();
    }
  });
});
