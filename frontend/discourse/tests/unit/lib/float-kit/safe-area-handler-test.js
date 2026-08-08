import { module, test } from "qunit";
import sinon from "sinon";
import SafeAreaHandler, {
  waitForScrollEnd,
} from "discourse/float-kit/components/d-scroll/safe-area-handler";

module("Unit | Lib | float-kit | safe-area-handler", function (hooks) {
  let clock;

  hooks.beforeEach(function () {
    clock = sinon.useFakeTimers();
  });

  hooks.afterEach(function () {
    clock.restore();
  });

  test("waitForScrollEnd cleanup cancels its listener and timer", function (assert) {
    const element = document.createElement("div");
    const callback = sinon.spy();
    const cleanup = waitForScrollEnd(element, callback, 50);

    cleanup();
    cleanup();
    element.dispatchEvent(new Event("scroll"));
    clock.tick(51);

    assert.false(callback.called, "the callback remains canceled");
  });

  test("replacing a wait and cleaning up cancels both callbacks", function (assert) {
    const viewElement = document.createElement("div");
    const contentElement = document.createElement("div");
    const updateSpacerHeights = sinon.spy();
    let viewportBottom = 80;

    Object.defineProperty(viewElement, "offsetHeight", { value: 100 });
    Object.defineProperty(contentElement, "offsetHeight", { value: 50 });
    viewElement.scrollTo = sinon.spy();

    const handler = new SafeAreaHandler({
      args: { axis: "y", safeArea: "visual-viewport" },
      controller: {
        contentElement,
        endSpacerElement: {
          getBoundingClientRect: () => ({ top: 0 }),
        },
        startSpacerElement: document.createElement("div"),
        updateSpacerHeights,
      },
      viewElement,
    });

    sinon
      .stub(handler, "getViewBoundsWithBorder")
      .returns({ top: 0, bottom: 100 });
    sinon.stub(handler, "getVisualViewportBounds").callsFake(() => ({
      top: 0,
      bottom: viewportBottom,
    }));

    handler.update({ scrollBehavior: "smooth" });
    viewportBottom = 70;
    handler.update({ scrollBehavior: "smooth" });
    handler.cleanup();

    viewElement.dispatchEvent(new Event("scroll"));
    clock.tick(301);

    assert.false(
      updateSpacerHeights.called,
      "neither the replaced nor active callback runs after cleanup"
    );
  });

  test("predicts safe-area bounds at a sheet's resting detent", function (assert) {
    const viewportHeight = window.innerHeight;
    const viewElement = document.createElement("div");
    const contentElement = document.createElement("div");
    const updateSpacerHeights = sinon.spy();

    const handler = new SafeAreaHandler({
      args: {
        axis: "y",
        safeArea: "layout-viewport",
        sheet: {
          content: {
            getBoundingClientRect: () => ({
              top: viewportHeight + 200,
              bottom: viewportHeight + 500,
            }),
          },
          contentPlacement: "bottom",
          dimensions: {
            view: { travelAxis: { unitless: viewportHeight + 100 } },
            content: { travelAxis: { unitless: 300 } },
          },
          isVerticalTrack: true,
          view: {
            getBoundingClientRect: () => ({
              top: 0,
              bottom: viewportHeight + 100,
            }),
          },
        },
      },
      controller: {
        contentElement,
        endSpacerElement: {
          getBoundingClientRect: () => ({ top: viewportHeight + 480 }),
        },
        startSpacerElement: document.createElement("div"),
        updateSpacerHeights,
      },
      viewElement,
    });

    sinon.stub(handler, "getViewBoundsWithBorder").returns({
      top: viewportHeight + 220,
      bottom: viewportHeight + 480,
    });

    handler.update({ scrollBehavior: "instant" });

    assert.true(
      updateSpacerHeights.calledOnceWith(0, 80),
      "the opening sheet geometry is remapped to its resting content bounds"
    );
  });
});
