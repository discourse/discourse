import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import {
  click,
  find,
  render,
  resetOnerror,
  settled,
  setupOnerror,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import DOverflowControls from "discourse/ui-kit/d-overflow-controls";

const EDGE_BUTTON_CLASSES = {
  left: "consumer-left",
  right: "consumer-right",
  up: "consumer-up",
  down: "consumer-down",
};

class ConditionalScrollerState {
  @tracked show = false;

  scrollToEnd = (element) => (element.scrollLeft = element.scrollWidth);
}

class RevealState {
  capture = (strip, element) => {
    this.strip = strip;
    this.target = element;
  };

  strip = null;
  target = null;
}

function nextFrame() {
  return new Promise((resolve) =>
    requestAnimationFrame(() => requestAnimationFrame(resolve))
  );
}

function layoutOffset(element) {
  let x = 0;
  let y = 0;
  let node = element;

  while (node) {
    x += node.offsetLeft;
    y += node.offsetTop;
    node = node.offsetParent instanceof HTMLElement ? node.offsetParent : null;
  }

  return { x, y };
}

function stubReducedMotion(matches) {
  return sinon.stub(window, "matchMedia").returns({ matches });
}

async function scrollTo(selector, props) {
  const element = document.querySelector(selector);
  Object.assign(element, props);
  await triggerEvent(element, "scroll");
}

module("Integration | ui-kit | DOverflowControls", function (hooks) {
  setupRenderingTest(hooks);

  test("no buttons when content fits", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 200px; overflow: auto">
          <div style="width: 50px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    assert.dom(".d-overflow-controls__btn").doesNotExist();
  });

  test("no buttons when the overflowing axis is not scrollable", async function (assert) {
    await render(
      <template>
        {{! content overflows horizontally but the axis is clipped, not scrollable }}
        <DOverflowControls style="width: 100px; overflow: hidden">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    assert.dom(".d-overflow-controls__btn").doesNotExist();
  });

  test("horizontal overflow shows the trailing button, then the leading one", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    assert
      .dom(".d-overflow-controls__btn.--right")
      .exists("shows the scroll-right button at the start");
    assert
      .dom(".d-overflow-controls__btn.--left")
      .doesNotExist("hides the scroll-left button at the start");

    const content = document.querySelector(".d-overflow-controls__content");
    await scrollTo(".d-overflow-controls__content", {
      scrollLeft: content.scrollWidth,
    });

    assert
      .dom(".d-overflow-controls__btn.--left")
      .exists("shows the scroll-left button at the end");
    assert
      .dom(".d-overflow-controls__btn.--right")
      .doesNotExist("hides the scroll-right button at the end");
  });

  test("vertical overflow shows the bottom button, then the top one", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="height: 100px; overflow-y: auto">
          <div style="height: 500px; width: 20px"></div>
        </DOverflowControls>
      </template>
    );

    assert
      .dom(".d-overflow-controls__btn.--down")
      .exists("shows the scroll-down button at the top");
    assert
      .dom(".d-overflow-controls__btn.--up")
      .doesNotExist("hides the scroll-up button at the top");

    const content = document.querySelector(".d-overflow-controls__content");
    await scrollTo(".d-overflow-controls__content", {
      scrollTop: content.scrollHeight,
    });

    assert
      .dom(".d-overflow-controls__btn.--up")
      .exists("shows the scroll-up button at the bottom");
    assert
      .dom(".d-overflow-controls__btn.--down")
      .doesNotExist("hides the scroll-down button at the bottom");
  });

  test("clamps button scroll targets to the content edges", async function (assert) {
    const matchMediaStub = stubReducedMotion(false);
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    const content = document.querySelector(".d-overflow-controls__content");
    let target;
    content.scrollTo = (options) => (target = options);

    await scrollTo(".d-overflow-controls__content", { scrollLeft: 350 });
    await click(".d-overflow-controls__btn.--right");
    assert.deepEqual(
      target,
      { left: 400, behavior: "smooth" },
      "forward tap targets the right edge instead of overshooting"
    );

    await scrollTo(".d-overflow-controls__content", { scrollLeft: 50 });
    await click(".d-overflow-controls__btn.--left");
    assert.deepEqual(
      target,
      { left: 0, behavior: "smooth" },
      "backward tap targets the start instead of overshooting"
    );
    matchMediaStub.restore();
  });

  test("targets only the tapped axis when both axes overflow", async function (assert) {
    const matchMediaStub = stubReducedMotion(false);
    await render(
      <template>
        {{! scrollbar-width: none keeps offset sizes exact across platforms }}
        <DOverflowControls
          style="width: 100px; height: 100px; overflow: auto; scrollbar-width: none"
        >
          <div style="width: 500px; height: 500px"></div>
        </DOverflowControls>
      </template>
    );

    const content = document.querySelector(".d-overflow-controls__content");
    let target;
    content.scrollTo = (options) => (target = options);

    await scrollTo(".d-overflow-controls__content", {
      scrollLeft: 50,
      scrollTop: 50,
    });

    await click(".d-overflow-controls__btn.--right");
    assert.deepEqual(
      target,
      { left: 150, behavior: "smooth" },
      "horizontal tap targets the horizontal axis only"
    );

    await click(".d-overflow-controls__btn.--down");
    assert.deepEqual(
      target,
      { top: 150, behavior: "smooth" },
      "vertical tap targets the vertical axis only"
    );
    matchMediaStub.restore();
  });

  test("uses instant scrolling when reduced motion is preferred", async function (assert) {
    const matchMediaStub = stubReducedMotion(true);

    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    const content = find(".d-overflow-controls__content");
    let target;
    content.scrollTo = (options) => (target = options);

    await click(".d-overflow-controls__btn.--right");

    assert.deepEqual(
      target,
      { left: content.clientWidth, behavior: "instant" },
      "a click respects the reduced-motion preference"
    );
    matchMediaStub.restore();
  });

  test("applies consumer classes and attributes", async function (assert) {
    await render(
      <template>
        <DOverflowControls
          @wrapperClass="my-wrap"
          @class="my-content"
          @buttonClass="my-btn"
          style="width: 100px; overflow-x: auto"
          data-test="yes"
        >
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    assert
      .dom(".d-overflow-controls.my-wrap")
      .exists("wrapper gets @wrapperClass");
    assert
      .dom(".d-overflow-controls__content.my-content")
      .hasAttribute(
        "data-test",
        "yes",
        "content gets @class and ...attributes"
      );
    assert
      .dom(".d-overflow-controls__btn.my-btn")
      .exists("buttons get @buttonClass");
  });

  test("overflow strip: default mode stamps its measured horizontal state", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    assert
      .dom(".d-overflow-controls__content")
      .hasAttribute(
        "data-d-scroll-overflow",
        "",
        "the content reports overflow"
      );
    assert
      .dom(".d-overflow-controls__content")
      .hasAttribute(
        "data-d-scroll-at-start",
        "",
        "the content reports its start edge"
      );
    assert
      .dom(".d-overflow-controls__content")
      .doesNotHaveAttribute(
        "data-d-scroll-at-end",
        "the end remains out of view"
      );
    assert
      .dom(".d-overflow-controls__content")
      .hasAttribute(
        "data-d-scroll-axis",
        "horizontal",
        "the content reports the measured axis"
      );
  });

  test("overflow strip: owned mode uses the consumer element as the scroller", async function (assert) {
    await render(
      <template>
        <DOverflowControls
          data-wrapper="yes"
          @axis="horizontal"
          @ownedScroller={{true}}
          @wrapperClass="consumer-wrapper"
          as |strip|
        >
          <div
            class="mine"
            style="width: 100px; overflow-x: auto"
            {{strip.scroller}}
          >
            <div style="width: 500px; height: 20px"></div>
          </div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    assert
      .dom(".d-overflow-controls.--owned-scroller.consumer-wrapper")
      .hasAttribute(
        "data-wrapper",
        "yes",
        "owned-mode splattributes land on the wrapper"
      );
    assert
      .dom(".mine")
      .hasAttribute(
        "data-d-scroll-overflow",
        "",
        "the consumer element is measured"
      );
    assert
      .dom(".mine")
      .hasAttribute(
        "data-d-scroll-at-start",
        "",
        "the consumer element is at start"
      );
    assert
      .dom(".mine")
      .hasAttribute(
        "data-d-scroll-axis",
        "horizontal",
        "the consumer element carries the axis"
      );
    assert
      .dom(".d-overflow-controls__btn.--right")
      .exists("owned mode renders its trailing button");
    assert
      .dom(".d-overflow-controls__content")
      .doesNotExist("owned mode renders no generated content scroller");
  });

  test("overflow strip: an explicit vertical axis ignores horizontal overflow", async function (assert) {
    await render(
      <template>
        <DOverflowControls
          style="width: 100px; height: 100px; overflow: auto"
          @axis="vertical"
        >
          <div style="width: 500px; height: 500px"></div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    assert
      .dom(".d-overflow-controls__content")
      .hasAttribute(
        "data-d-scroll-axis",
        "vertical",
        "the explicit axis is stamped"
      );
    assert
      .dom(".d-overflow-controls__btn.--down")
      .exists("the vertical trailing button renders");
    assert
      .dom(".d-overflow-controls__btn.--right")
      .doesNotExist("horizontal overflow is ignored");
  });

  test("overflow strip: an explicit hidden axis never renders owned-mode buttons", async function (assert) {
    await render(
      <template>
        <DOverflowControls
          @axis="horizontal"
          @ownedScroller={{true}}
          as |strip|
        >
          <div
            class="mine"
            style="width: 100px; overflow-x: hidden"
            {{strip.scroller}}
          >
            <div style="width: 500px; height: 20px"></div>
          </div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    assert
      .dom(".d-overflow-controls.--owned-scroller")
      .exists("the consumer element owns the scroller");
    assert.true(
      find(".mine").scrollWidth > find(".mine").clientWidth,
      "the fixture has geometric overflow"
    );
    assert
      .dom(".d-overflow-controls__btn")
      .doesNotExist("hidden overflow is not treated as scrollable");
  });

  test("overflow strip: edge button classes are applied per physical edge", async function (assert) {
    await render(
      <template>
        <DOverflowControls
          style="width: 100px; height: 100px; overflow: auto; scrollbar-width: none"
          @edgeButtonClasses={{EDGE_BUTTON_CLASSES}}
        >
          <div style="width: 500px; height: 500px"></div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    assert
      .dom(".d-overflow-controls__btn.--right.consumer-right")
      .exists("the right edge receives only its class");
    for (const className of ["consumer-left", "consumer-up", "consumer-down"]) {
      assert
        .dom(".d-overflow-controls__btn.--right")
        .doesNotHaveClass(className, `the right edge excludes ${className}`);
    }
    assert
      .dom(".d-overflow-controls__btn.--down.consumer-down")
      .exists("the bottom edge receives only its class");
    for (const className of [
      "consumer-left",
      "consumer-right",
      "consumer-up",
    ]) {
      assert
        .dom(".d-overflow-controls__btn.--down")
        .doesNotHaveClass(className, `the bottom edge excludes ${className}`);
    }

    const content = find(".d-overflow-controls__content");
    await scrollTo(".d-overflow-controls__content", {
      scrollLeft: content.scrollWidth - content.clientWidth,
      scrollTop: content.scrollHeight - content.clientHeight,
    });
    await nextFrame();

    assert
      .dom(".d-overflow-controls__btn.--left.consumer-left")
      .exists("the left edge receives only its class");
    for (const className of [
      "consumer-right",
      "consumer-up",
      "consumer-down",
    ]) {
      assert
        .dom(".d-overflow-controls__btn.--left")
        .doesNotHaveClass(className, `the left edge excludes ${className}`);
    }
    assert
      .dom(".d-overflow-controls__btn.--up.consumer-up")
      .exists("the top edge receives only its class");
    for (const className of [
      "consumer-left",
      "consumer-right",
      "consumer-down",
    ]) {
      assert
        .dom(".d-overflow-controls__btn.--up")
        .doesNotHaveClass(className, `the top edge excludes ${className}`);
    }
  });

  test("overflow strip: touch skips hold while mouse hold scrolls continuously", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    const content = find(".d-overflow-controls__content");
    const button = find(".d-overflow-controls__btn.--right");
    stubPointerCapture(button);

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "touch",
    });
    await nextFrame();
    await nextFrame();

    assert.strictEqual(content.scrollLeft, 0, "a touch press never arms hold");

    await triggerEvent(button, "pointerup", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "touch",
    });

    let touchClicks = 0;
    const nativeScrollTo = content.scrollTo.bind(content);
    content.scrollTo = () => touchClicks++;
    await click(button);
    assert.strictEqual(
      touchClicks,
      1,
      "a touch tap keeps the plain-click path"
    );
    content.scrollTo = nativeScrollTo;

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 2,
      isPrimary: true,
      pointerType: "mouse",
    });
    await nextFrame();

    assert.true(content.scrollLeft > 0, "the hold advances the content");
    const firstOffset = content.scrollLeft;

    await nextFrame();
    assert.true(
      content.scrollLeft > firstOffset,
      "the hold continues advancing on later frames"
    );

    await triggerEvent(button, "pointerup", {
      button: 0,
      pointerId: 2,
      isPrimary: true,
      pointerType: "mouse",
    });

    let clicks = 0;
    content.scrollTo = () => clicks++;
    await click(button);
    assert.strictEqual(clicks, 0, "the click following a hold is swallowed");

    await click(button);
    assert.strictEqual(clicks, 1, "the next plain click scrolls exactly once");
  });

  test("overflow strip: reveal supports nearest and center without moving the page", async function (assert) {
    const state = new RevealState();
    const pageScroll = window.scrollY;

    await render(
      <template>
        <DOverflowControls
          style="width: 160px; overflow-x: auto; white-space: nowrap"
          @axis="horizontal"
          as |strip|
        >
          <span
            style="display: inline-block; width: 320px; height: 20px"
          ></span>
          <button
            class="reveal-target"
            style="display: inline-block; width: 80px"
            type="button"
            {{didInsert (fn state.capture strip)}}
          >Target</button>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    const content = find(".d-overflow-controls__content");
    const target = find(".reveal-target");
    const contentPosition = layoutOffset(content);
    const targetPosition = layoutOffset(target);
    const targetStart = targetPosition.x - contentPosition.x;
    const paddingRight =
      Number.parseFloat(getComputedStyle(content).scrollPaddingRight) || 0;
    let scrollTarget;
    content.scrollTo = (options) => (scrollTarget = options);
    const reveal = state.strip?.reveal;

    assert.strictEqual(
      typeof reveal,
      "function",
      "the yielded strip exposes reveal"
    );

    if (typeof reveal !== "function") {
      // eslint-disable-next-line qunit/no-early-return
      return;
    }

    reveal(target);
    assert.strictEqual(
      scrollTarget.left,
      targetStart + target.offsetWidth + paddingRight - content.clientWidth,
      "nearest reveals the measured trailing edge clear of scroll padding"
    );
    assert.strictEqual(
      scrollTarget.behavior,
      "instant",
      "nearest reveal is instant"
    );

    reveal(target, { align: "center" });
    assert.strictEqual(
      scrollTarget.left,
      targetStart + target.offsetWidth / 2 - content.clientWidth / 2,
      "center aligns the measured target and viewport centers"
    );
    assert.strictEqual(
      scrollTarget.behavior,
      "instant",
      "center reveal is instant"
    );
    assert.strictEqual(window.scrollY, pageScroll, "the page does not move");
  });

  test("overflow strip: reveal leaves a fully visible horizontal item in place", async function (assert) {
    const state = new RevealState();

    await render(
      <template>
        <DOverflowControls
          style="width: 160px; overflow-x: auto; white-space: nowrap"
          @axis="horizontal"
          as |strip|
        >
          <button
            class="visible-reveal-target"
            style="display: inline-block; width: 80px"
            type="button"
            {{didInsert (fn state.capture strip)}}
          >Visible target</button>
          <span
            style="display: inline-block; width: 320px; height: 20px"
          ></span>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    const content = find(".d-overflow-controls__content");
    const target = find(".visible-reveal-target");
    const contentRect = content.getBoundingClientRect();
    const targetRect = target.getBoundingClientRect();
    assert.true(
      targetRect.left >= contentRect.left,
      "the measured target starts after the viewport's leading edge"
    );
    assert.true(
      targetRect.right <= contentRect.right,
      "the measured target ends before the viewport's trailing edge"
    );

    const scrollToSpy = sinon.spy();
    content.scrollTo = scrollToSpy;
    state.strip.reveal(target);

    assert.true(
      scrollToSpy.notCalled,
      "revealing an already visible item does not request any scroll"
    );
  });

  test("overflow strip: a scroller mounted later inside a conditional is observed", async function (assert) {
    const state = new ConditionalScrollerState();

    await render(
      <template>
        <DOverflowControls
          @axis="horizontal"
          @ownedScroller={{true}}
          as |strip|
        >
          {{#if state.show}}
            <div
              class="late-scroller"
              style="width: 100px; overflow-x: auto"
              {{strip.scroller}}
            >
              <div style="width: 500px; height: 20px"></div>
            </div>
          {{/if}}
        </DOverflowControls>
      </template>
    );

    assert
      .dom(".late-scroller")
      .doesNotExist("the consumer has not mounted its scroller yet");

    state.show = true;
    await settled();
    await nextFrame();

    assert
      .dom(".late-scroller")
      .hasAttribute(
        "data-d-scroll-overflow",
        "",
        "the late scroller is measured"
      );
    assert
      .dom(".d-overflow-controls__btn.--right")
      .exists("the late scroller receives a trailing button");
  });

  test("overflow strip: removes buttons when an owned scroller unmounts", async function (assert) {
    const state = new ConditionalScrollerState();
    state.show = true;

    await render(
      <template>
        <DOverflowControls
          @axis="horizontal"
          @ownedScroller={{true}}
          as |strip|
        >
          {{#if state.show}}
            <div
              class="conditional-scroller"
              style="width: 100px; overflow-x: auto"
              {{strip.scroller}}
            >
              <div style="width: 500px; height: 20px"></div>
            </div>
          {{/if}}
        </DOverflowControls>
      </template>
    );
    await nextFrame();
    assert
      .dom(".d-overflow-controls__btn.--right")
      .exists("the overflowing owned scroller initially has a button");

    state.show = false;
    await settled();
    await nextFrame();

    assert
      .dom(".d-overflow-controls__btn")
      .doesNotExist("unmounting the owned scroller removes its buttons");
  });

  test("overflow strip: replaces edge state when owned scrollers swap", async function (assert) {
    const state = new ConditionalScrollerState();
    state.show = true;

    await render(
      <template>
        <DOverflowControls
          @axis="horizontal"
          @ownedScroller={{true}}
          as |strip|
        >
          {{#if state.show}}
            <div
              class="first-conditional-scroller"
              style="width: 100px; overflow-x: auto"
              {{strip.scroller}}
            >
              <div style="width: 500px; height: 20px"></div>
            </div>
          {{else}}
            <div
              class="second-conditional-scroller"
              style="width: 100px; overflow-x: auto"
              {{didInsert state.scrollToEnd}}
              {{strip.scroller}}
            >
              <div style="width: 500px; height: 20px"></div>
            </div>
          {{/if}}
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    assert
      .dom(".d-overflow-controls__btn.--right")
      .exists("the first scroller starts with only the trailing button");
    assert
      .dom(".d-overflow-controls__btn.--left")
      .doesNotExist("the first scroller has no leading button");

    state.show = false;
    await settled();
    await nextFrame();

    assert
      .dom(".first-conditional-scroller")
      .doesNotExist("the first owned scroller unmounts during the swap");
    assert
      .dom(".second-conditional-scroller")
      .exists("the second owned scroller mounts during the same render");
    assert
      .dom(".d-overflow-controls__btn.--left")
      .exists("the second scroller at its end has a leading button");
    assert
      .dom(".d-overflow-controls__btn.--right")
      .doesNotExist(
        "the first scroller's stale trailing flag does not survive"
      );
  });

  test("overflow strip: hold stops when the window loses focus", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    const content = find(".d-overflow-controls__content");
    const button = find(".d-overflow-controls__btn.--right");
    const { captured, released } = stubPointerCapture(button);

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "mouse",
    });
    await nextFrame();
    await nextFrame();

    assert.true(content.scrollLeft > 0, "the hold advances the content");
    assert.true(captured.has(1), "the hold captures its pointer");

    await triggerEvent(window, "blur");
    const offsetAfterBlur = content.scrollLeft;
    await nextFrame();
    await nextFrame();

    assert.strictEqual(
      content.scrollLeft,
      offsetAfterBlur,
      "losing window focus stops the hold"
    );
    assert.true(
      released.includes(1),
      "losing window focus releases the pointer capture"
    );
  });

  test("overflow strip: a touch click is not swallowed after blur ends a mouse hold", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    const content = find(".d-overflow-controls__content");
    const button = find(".d-overflow-controls__btn.--right");
    stubPointerCapture(button);

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "mouse",
    });

    await nextFrame();
    await nextFrame();
    await triggerEvent(window, "blur");

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 2,
      isPrimary: true,
      pointerType: "touch",
    });
    await triggerEvent(button, "pointerup", {
      button: 0,
      pointerId: 2,
      isPrimary: true,
      pointerType: "touch",
    });

    const scrollToSpy = sinon.spy();
    content.scrollTo = scrollToSpy;
    await click(button);

    assert.strictEqual(
      scrollToSpy.callCount,
      1,
      "the touch click scrolls once after blur cancels the mouse hold"
    );
  });

  test("overflow strip: a click is not swallowed after pointercancel ends a mouse hold", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    const content = find(".d-overflow-controls__content");
    const button = find(".d-overflow-controls__btn.--right");
    stubPointerCapture(button);

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "mouse",
    });
    await nextFrame();
    await nextFrame();
    await triggerEvent(button, "pointercancel", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "mouse",
    });

    const scrollToSpy = sinon.spy();
    content.scrollTo = scrollToSpy;
    await click(button);

    assert.strictEqual(
      scrollToSpy.callCount,
      1,
      "the click scrolls once after pointercancel ends the mouse hold"
    );
  });

  test("overflow strip: scrolling does not reread computed styles", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    const getComputedStyleSpy = sinon.spy(window, "getComputedStyle");
    const content = find(".d-overflow-controls__content");

    try {
      for (const scrollLeft of [50, 100, 150]) {
        await scrollTo(".d-overflow-controls__content", { scrollLeft });
        await nextFrame();
      }

      assert.strictEqual(
        getComputedStyleSpy
          .getCalls()
          .filter((call) => call.args[0] === content).length,
        0,
        "scrolling remeasures geometry without rereading scrollability"
      );
    } finally {
      getComputedStyleSpy.restore();
    }
  });

  test("overflow strip: rejects a second concurrent owned scroller", async function (assert) {
    const expectedMessage =
      "d-overflow-controls: strip.scroller was applied to a second element while another scroller is still mounted";
    let errors = 0;
    setupOnerror((error) => {
      errors++;
      assert.true(
        error.message.endsWith(expectedMessage),
        "the assertion identifies the second concurrently owned scroller"
      );
      assert.true(
        /d-overflow-controls: .*second/i.test(error.message),
        "the assertion names d-overflow-controls and the second scroller"
      );
    });

    await render(
      <template>
        <DOverflowControls @ownedScroller={{true}} as |strip|>
          <div class="first-owned-scroller" {{strip.scroller}}></div>
          <div class="second-owned-scroller" {{strip.scroller}}></div>
        </DOverflowControls>
      </template>
    );

    assert.strictEqual(errors, 1, "a second owned scroller raises one error");
    resetOnerror();
  });

  test("overflow strip: percentage scroll padding uses the scrollport", async function (assert) {
    const state = new RevealState();

    await render(
      <template>
        <DOverflowControls
          style="width: 160px; overflow-x: auto; white-space: nowrap; scroll-padding-right: 25%"
          as |strip|
        >
          <span
            style="display: inline-block; width: 320px; height: 20px"
          ></span>
          <button
            class="percentage-padding-target"
            style="display: inline-block; width: 80px"
            type="button"
            {{didInsert (fn state.capture strip)}}
          >Target</button>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    const content = find(".d-overflow-controls__content");
    const target = find(".percentage-padding-target");
    const contentPosition = layoutOffset(content);
    const targetPosition = layoutOffset(target);
    const targetStart = targetPosition.x - contentPosition.x;
    let scrollTarget;
    content.scrollTo = (options) => (scrollTarget = options);
    const reveal = state.strip?.reveal;

    assert.strictEqual(
      typeof reveal,
      "function",
      "the yielded strip exposes reveal"
    );

    if (typeof reveal !== "function") {
      // eslint-disable-next-line qunit/no-early-return
      return;
    }

    reveal(target);
    assert.strictEqual(
      scrollTarget.left,
      targetStart +
        target.offsetWidth +
        0.25 * content.clientWidth -
        content.clientWidth,
      "nearest resolves percentage padding against the measured scrollport"
    );
  });

  test("overflow strip: a second pointer's release does not end another pointer's hold", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    const content = find(".d-overflow-controls__content");
    const button = find(".d-overflow-controls__btn.--right");
    const { captured, released } = stubPointerCapture(button);

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "mouse",
    });
    await nextFrame();
    await nextFrame();

    assert.true(content.scrollLeft > 0, "the mouse hold advances the content");
    assert.true(captured.has(1), "the mouse hold captures its pointer");

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 2,
      isPrimary: true,
      pointerType: "touch",
    });
    await triggerEvent(button, "pointerup", {
      button: 0,
      pointerId: 2,
      isPrimary: true,
      pointerType: "touch",
    });
    const offsetAfterTouchRelease = content.scrollLeft;
    await nextFrame();
    await nextFrame();

    assert.true(
      content.scrollLeft > offsetAfterTouchRelease,
      "another pointer's release leaves the mouse hold running"
    );
    assert.false(
      released.includes(1),
      "another pointer's release does not release the mouse capture"
    );

    await triggerEvent(button, "pointerup", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "mouse",
    });
    const offsetAfterMouseRelease = content.scrollLeft;
    await nextFrame();
    await nextFrame();

    assert.strictEqual(
      content.scrollLeft,
      offsetAfterMouseRelease,
      "the matching pointer's release stops the hold"
    );
    assert.true(
      released.includes(1),
      "the matching pointer's release releases its capture"
    );
  });

  test("overflow strip: a second pointer's press does not replace an active hold", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );
    await nextFrame();

    const content = find(".d-overflow-controls__content");
    const button = find(".d-overflow-controls__btn.--right");
    const { captured, released } = stubPointerCapture(button);
    const offsetBeforeMouseHold = content.scrollLeft;

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "mouse",
    });
    await nextFrame();
    await nextFrame();

    assert.true(
      content.scrollLeft > offsetBeforeMouseHold,
      "the mouse hold advances the content"
    );

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 3,
      isPrimary: true,
      pointerType: "pen",
    });
    const offsetAfterPenPress = content.scrollLeft;
    await nextFrame();
    await nextFrame();

    assert.true(
      content.scrollLeft > offsetAfterPenPress,
      "the pen press leaves the mouse hold running"
    );
    assert.false(
      released.includes(1),
      "the pen press does not release the mouse capture"
    );
    assert.false(captured.has(3), "the ignored pen press is not captured");

    await triggerEvent(button, "pointerup", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "mouse",
    });
    const offsetAfterMouseRelease = content.scrollLeft;
    await nextFrame();
    await nextFrame();

    assert.strictEqual(
      content.scrollLeft,
      offsetAfterMouseRelease,
      "the mouse release stops its hold"
    );
    assert.true(released.includes(1), "the mouse release releases its capture");
  });
});
