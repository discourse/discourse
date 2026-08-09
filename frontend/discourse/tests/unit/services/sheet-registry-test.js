import { getOwner } from "@ember/owner";
import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import FocusManagement from "discourse/float-kit/components/d-sheet/focus-management";

module("Unit | Service | sheet-registry", function (hooks) {
  setupTest(hooks);

  let fixedElement;
  let registry;
  let sandbox;

  hooks.beforeEach(function () {
    sandbox = sinon.createSandbox();
    registry = getOwner(this).lookup("service:sheet-registry");
    fixedElement = document.createElement("div");
    fixedElement.setAttribute("data-d-sheet", "view");
    document.body.append(fixedElement);
  });

  hooks.afterEach(function () {
    if (!registry.isDestroying) {
      while (registry.scrollLockCount > 0) {
        registry.removeScrollLock();
      }
    }

    fixedElement.remove();
    document.body.style.removeProperty("overflow");
    document.body.style.removeProperty("padding-right");
    document.body.style.removeProperty("padding-bottom");
    sandbox.restore();
  });

  test("compensates for collapsed scrollbars while locked", function (assert) {
    const xScrollbarThickness = `${
      window.innerWidth - document.documentElement.clientWidth
    }px`;
    const yScrollbarThickness = `${
      window.innerHeight - document.documentElement.clientHeight
    }px`;

    registry.applyScrollLock();

    assert.strictEqual(
      document.body.style.getPropertyValue("overflow"),
      "hidden",
      "body scrolling is disabled"
    );
    assert.strictEqual(
      document.body.style.getPropertyValue("padding-right"),
      xScrollbarThickness,
      "the body compensates for the collapsed vertical scrollbar"
    );
    assert.strictEqual(
      document.body.style.getPropertyValue("padding-bottom"),
      yScrollbarThickness,
      "the body compensates for the collapsed horizontal scrollbar"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--x-collapsed-scrollbar-thickness"),
      xScrollbarThickness,
      "fixed sheet elements receive the horizontal compensation"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--y-collapsed-scrollbar-thickness"),
      yScrollbarThickness,
      "fixed sheet elements receive the vertical compensation"
    );

    registry.removeScrollLock();

    assert.strictEqual(
      document.body.style.getPropertyValue("overflow"),
      "",
      "body scrolling is restored"
    );
    assert.strictEqual(
      document.body.style.getPropertyValue("padding-right"),
      "",
      "the body horizontal compensation is removed"
    );
    assert.strictEqual(
      document.body.style.getPropertyValue("padding-bottom"),
      "",
      "the body vertical compensation is removed"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--x-collapsed-scrollbar-thickness"),
      "",
      "the fixed-element horizontal compensation is removed"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--y-collapsed-scrollbar-thickness"),
      "",
      "the fixed-element vertical compensation is removed"
    );
  });

  test("restores preexisting scroll-lock styles and priorities", function (assert) {
    document.body.style.setProperty("overflow", "auto", "important");
    document.body.style.setProperty("padding-right", "7px", "important");
    document.body.style.setProperty("padding-bottom", "9px", "important");
    fixedElement.style.setProperty(
      "--x-collapsed-scrollbar-thickness",
      "11px",
      "important"
    );
    fixedElement.style.setProperty(
      "--y-collapsed-scrollbar-thickness",
      "13px",
      "important"
    );

    registry.applyScrollLock();
    registry.removeScrollLock();

    assert.strictEqual(
      document.body.style.getPropertyValue("overflow"),
      "auto",
      "the original body overflow is restored"
    );
    assert.strictEqual(
      document.body.style.getPropertyPriority("overflow"),
      "important",
      "the original body overflow priority is restored"
    );
    assert.strictEqual(
      document.body.style.getPropertyValue("padding-right"),
      "7px",
      "the original body right padding is restored"
    );
    assert.strictEqual(
      document.body.style.getPropertyPriority("padding-right"),
      "important",
      "the original body right padding priority is restored"
    );
    assert.strictEqual(
      document.body.style.getPropertyValue("padding-bottom"),
      "9px",
      "the original body bottom padding is restored"
    );
    assert.strictEqual(
      document.body.style.getPropertyPriority("padding-bottom"),
      "important",
      "the original body bottom padding priority is restored"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--x-collapsed-scrollbar-thickness"),
      "11px",
      "the original horizontal compensation value is restored"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyPriority(
        "--x-collapsed-scrollbar-thickness"
      ),
      "important",
      "the original horizontal compensation priority is restored"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--y-collapsed-scrollbar-thickness"),
      "13px",
      "the original vertical compensation value is restored"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyPriority(
        "--y-collapsed-scrollbar-thickness"
      ),
      "important",
      "the original vertical compensation priority is restored"
    );
  });

  test("preserves consumer style changes made while locked", function (assert) {
    registry.applyScrollLock();

    document.body.style.setProperty("overflow", "scroll", "important");
    document.body.style.setProperty("padding-right", "17px", "important");
    fixedElement.style.setProperty(
      "--x-collapsed-scrollbar-thickness",
      "19px",
      "important"
    );

    registry.removeScrollLock();

    assert.strictEqual(
      document.body.style.getPropertyValue("overflow"),
      "scroll",
      "consumer overflow is not replaced during cleanup"
    );
    assert.strictEqual(
      document.body.style.getPropertyPriority("overflow"),
      "important",
      "consumer overflow priority is retained"
    );
    assert.strictEqual(
      document.body.style.getPropertyValue("padding-right"),
      "17px",
      "consumer padding is not replaced during cleanup"
    );
    assert.strictEqual(
      document.body.style.getPropertyPriority("padding-right"),
      "important",
      "consumer padding priority is retained"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--x-collapsed-scrollbar-thickness"),
      "19px",
      "consumer compensation is not replaced during cleanup"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyPriority(
        "--x-collapsed-scrollbar-thickness"
      ),
      "important",
      "consumer compensation priority is retained"
    );
    assert.strictEqual(
      document.body.style.getPropertyValue("padding-bottom"),
      "",
      "an untouched body compensation is removed"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--y-collapsed-scrollbar-thickness"),
      "",
      "an untouched fixed-element compensation is removed"
    );

    registry.applyScrollLock();
    registry.removeScrollLock();

    assert.strictEqual(
      document.body.style.getPropertyValue("padding-right"),
      "17px",
      "a reopened lock snapshots the current consumer padding"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--x-collapsed-scrollbar-thickness"),
      "19px",
      "a reopened lock snapshots the current consumer compensation"
    );
  });

  test("compensates a view registered after locking", function (assert) {
    const xScrollbarThickness = `${
      window.innerWidth - document.documentElement.clientWidth
    }px`;
    const yScrollbarThickness = `${
      window.innerHeight - document.documentElement.clientHeight
    }px`;

    const controller = { id: "late-view", inertOutside: true };

    fixedElement.remove();
    registry.register(controller);

    fixedElement = document.createElement("div");
    fixedElement.setAttribute("data-d-sheet", "view");
    document.body.append(fixedElement);
    registry.viewRegistered(controller, fixedElement);

    assert.strictEqual(
      fixedElement.style.getPropertyValue("--x-collapsed-scrollbar-thickness"),
      xScrollbarThickness,
      "the late view receives the active horizontal compensation"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--y-collapsed-scrollbar-thickness"),
      yScrollbarThickness,
      "the late view receives the active vertical compensation"
    );
    assert.strictEqual(
      fixedElement.getAttribute("aria-modal"),
      "true",
      "the late view immediately receives its modal semantics"
    );

    registry.unregister(controller);
  });

  test("a rendered inactive view is not exposed as modal", function (assert) {
    const controller = { id: "inactive-view", inertOutside: true };

    registry.applyScrollLock();
    fixedElement.setAttribute("aria-modal", "true");
    registry.viewRegistered(controller, fixedElement);

    assert.false(
      fixedElement.hasAttribute("aria-modal"),
      "only registered sheet layers receive modal semantics"
    );
    assert.notStrictEqual(
      fixedElement.style.getPropertyValue("--x-collapsed-scrollbar-thickness"),
      "",
      "global scrollbar compensation still reaches the rendered view"
    );
  });

  test("a removed View is hidden from accessibility until reactivated", function (assert) {
    const button = document.createElement("button");
    const link = document.createElement("a");
    link.href = "#target";
    link.tabIndex = 3;
    fixedElement.append(button, link);

    const controller = {
      id: "reactivated-view",
      inertOutside: false,
      view: fixedElement,
    };

    registry.register(controller);
    registry.unregister(controller);

    assert.strictEqual(
      fixedElement.getAttribute("aria-hidden"),
      "true",
      "the pending View is hidden from assistive technology"
    );
    assert.strictEqual(
      button.getAttribute("tabindex"),
      "-1",
      "a natively tabbable descendant is removed from the tab order"
    );
    assert.strictEqual(
      link.getAttribute("tabindex"),
      "-1",
      "an explicit positive tab index is removed from the tab order"
    );

    registry.register(controller);

    assert.false(
      fixedElement.hasAttribute("aria-hidden"),
      "reactivation exposes the View again"
    );
    assert.false(
      button.hasAttribute("tabindex"),
      "reactivation restores the native tab order"
    );
    assert.strictEqual(
      link.getAttribute("tabindex"),
      "3",
      "reactivation restores an explicit tab index"
    );

    registry.unregister(controller);
  });

  test("enabling inert outside recovers focus through present autofocus", function (assert) {
    const outside = document.createElement("button");
    const inside = document.createElement("button");
    const onPresentAutoFocus = sandbox.spy();
    const controller = {
      canAcceptDismissRequest: true,
      id: "dynamic-inert-view",
      inertOutside: false,
      onPresentAutoFocus,
      sheetRegistry: registry,
      view: fixedElement,
    };
    const focusManagement = new FocusManagement(controller);
    controller.executeAutoFocusOnPresent = () => {
      focusManagement.executeAutoFocusOnPresent();
    };

    inside.style.width = "1px";
    inside.style.height = "1px";
    fixedElement.append(inside);
    document.querySelector("#qunit-fixture").append(outside);

    registry.register(controller);
    registry.sheetLayerStore.flushInertOutside();
    outside.focus();

    try {
      controller.inertOutside = true;
      registry.updateInertOutside(controller, true);
      registry.sheetLayerStore.flushInertOutside();

      assert.true(
        onPresentAutoFocus.calledOnce,
        "the dynamic modal transition runs the present focus behavior once"
      );
      assert.strictEqual(
        document.activeElement,
        inside,
        "the transition focuses the first safe target instead of the View"
      );
    } finally {
      registry.unregister(controller);
      registry.sheetLayerStore.flushInertOutside();
    }
  });

  test("initial layer registration leaves autofocus to the opening lifecycle", function (assert) {
    const executeAutoFocusOnPresent = sandbox.spy();
    const controller = {
      canAcceptDismissRequest: true,
      executeAutoFocusOnPresent,
      id: "opening-inert-view",
      inertOutside: true,
      view: fixedElement,
    };

    registry.register(controller);

    try {
      registry.sheetLayerStore.flushInertOutside();

      assert.false(
        executeAutoFocusOnPresent.called,
        "registration does not duplicate the controller's opening autofocus"
      );
    } finally {
      registry.unregister(controller);
      registry.sheetLayerStore.flushInertOutside();
    }
  });

  test("controller replacement keeps one identity-scoped scroll lock", function (assert) {
    const view = document.createElement("div");
    const originalController = {
      id: "stable-controller-id",
      inertOutside: true,
      view,
    };
    const replacementController = {
      id: "stable-controller-id",
      inertOutside: true,
      view,
    };

    registry.register(originalController);
    registry.register(replacementController);

    assert.strictEqual(
      registry.scrollLockCount,
      1,
      "replacement does not acquire a duplicate body lock"
    );

    registry.unregister(originalController);

    assert.strictEqual(
      registry.scrollLockCount,
      1,
      "stale cleanup cannot release the replacement's lock"
    );
    assert.strictEqual(
      view.getAttribute("aria-modal"),
      "true",
      "stale cleanup cannot alter the replacement's modal semantics"
    );

    registry.unregister(replacementController);

    assert.strictEqual(
      registry.scrollLockCount,
      0,
      "the owning controller releases the lock"
    );
  });

  test("re-enables scroll enforcement after closing during resize", function (assert) {
    const scrollTo = sandbox.stub(window, "scrollTo");

    registry.applyScrollLock();
    window.dispatchEvent(new Event("resize"));
    window.dispatchEvent(new Event("scroll"));

    assert.false(
      scrollTo.called,
      "scroll enforcement pauses during the resize"
    );

    registry.removeScrollLock();

    assert.strictEqual(
      registry.resizeTimeout,
      null,
      "closing clears the pending resize reset"
    );
    assert.false(
      registry.isResizing,
      "closing clears the transient resize state"
    );

    registry.applyScrollLock();
    window.dispatchEvent(new Event("scroll"));

    assert.true(
      scrollTo.calledOnceWithExactly(...registry.savedScrollPosition),
      "the reopened lock immediately restores the saved scroll position"
    );
  });

  test("service destruction fully releases an active scroll lock", function (assert) {
    const scrollTo = sandbox.stub(window, "scrollTo");
    document.body.style.setProperty("overflow", "auto", "important");
    document.body.style.setProperty("padding-right", "5px", "important");
    fixedElement.style.setProperty(
      "--x-collapsed-scrollbar-thickness",
      "7px",
      "important"
    );

    registry.applyScrollLock();
    window.dispatchEvent(new Event("resize"));

    run(() => registry.destroy());

    assert.strictEqual(
      document.body.style.getPropertyValue("overflow"),
      "auto",
      "destruction restores the original body overflow"
    );
    assert.strictEqual(
      document.body.style.getPropertyPriority("overflow"),
      "important",
      "destruction restores the original body overflow priority"
    );
    assert.strictEqual(
      document.body.style.getPropertyValue("padding-right"),
      "5px",
      "destruction restores the original body right padding"
    );
    assert.strictEqual(
      document.body.style.getPropertyPriority("padding-right"),
      "important",
      "destruction restores the original body right padding priority"
    );
    assert.strictEqual(
      document.body.style.getPropertyValue("padding-bottom"),
      "",
      "destruction removes the body vertical compensation"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--x-collapsed-scrollbar-thickness"),
      "7px",
      "destruction restores the original horizontal compensation"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyPriority(
        "--x-collapsed-scrollbar-thickness"
      ),
      "important",
      "destruction restores the horizontal compensation priority"
    );
    assert.strictEqual(
      fixedElement.style.getPropertyValue("--y-collapsed-scrollbar-thickness"),
      "",
      "destruction removes the fixed-element vertical compensation"
    );
    assert.strictEqual(
      registry.resizeTimeout,
      null,
      "destruction cancels the resize reset"
    );
    assert.false(registry.isResizing, "destruction clears the resize state");

    window.dispatchEvent(new Event("scroll"));

    assert.false(scrollTo.called, "destruction removes the scroll listener");
  });
});
