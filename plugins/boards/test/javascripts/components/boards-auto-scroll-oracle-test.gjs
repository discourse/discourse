import { clearRender, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import { dragToScroll } from "discourse/plugins/boards/discourse/lib/boards-auto-scroll";

const draggingClass = "discourse-boards-board-container--drag-scrolling";

/** Controls the browser scheduling boundary without replacing the pan or coast. */
function controlFrames() {
  const originalRequest = window.requestAnimationFrame;
  const originalCancel = window.cancelAnimationFrame;
  const pending = new Map();
  let id = 0;
  let time = 1000;
  window.requestAnimationFrame = (callback) => {
    pending.set(++id, callback);
    return id;
  };
  window.cancelAnimationFrame = (frame) => pending.delete(frame);
  return {
    pending,
    step(count = 1) {
      for (let i = 0; i < count; i++) {
        time += 1000 / 60;
        const callbacks = [...pending.values()];
        pending.clear();
        for (const callback of callbacks) {
          callback(time);
        }
      }
    },
    restore() {
      window.requestAnimationFrame = originalRequest;
      window.cancelAnimationFrame = originalCancel;
    },
  };
}

/** Synthetic timestamps keep velocity independent of test-runner load. */
function pointer(element, type, x, time, options = {}) {
  const event = new PointerEvent(type, {
    bubbles: true,
    cancelable: true,
    pointerId: 41,
    pointerType: "mouse",
    button: 0,
    buttons: type === "pointerup" ? 0 : 1,
    clientX: x,
    clientY: 20,
    ...options,
  });
  Object.defineProperty(event, "timeStamp", { value: time });
  element.dispatchEvent(event);
  return event;
}

function dispatchClick(element) {
  const event = new MouseEvent("click", { bubbles: true, cancelable: true });
  element.dispatchEvent(event);
  return event;
}

async function renderBoard() {
  await render(
    <template>
      <div
        class="discourse-boards-board-container"
        data-pan-oracle
        style="width: 240px; height: 100px; flex: none; padding: 0; overflow: auto; direction: ltr; scroll-behavior: auto;"
        {{dragToScroll}}
      >
        <div
          data-pan-content
          style="width: 2400px; height: 60px; flex: none;"
        ></div>
      </div>
    </template>
  );
  const element = find("[data-pan-oracle]");
  stubPointerCapture(element);
  element.scrollLeft = element.clientWidth * 2;
  return element;
}

function startPan(element, frames, direction = -1) {
  const from = element.clientWidth;
  const to = from + direction * (element.clientWidth / 4);
  pointer(element, "pointerdown", from, 1000);
  pointer(element, "pointermove", to, 1020);
  frames.step();
  return to;
}

function releasePan(element, frames, direction = -1) {
  const to = startPan(element, frames, direction);
  pointer(element, "pointerup", to, 1021);
  return to;
}

module(
  "Boards | Integration | Modifier | boards-auto-scroll",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(async function () {
      try {
        await clearRender();
      } finally {
        this.frames?.restore();
      }
    });

    test("pan-scroll-oracle: background pans both ways and release ends the gesture", async function (assert) {
      const element = await renderBoard();
      const frames = (this.frames = controlFrames());
      const initial = element.scrollLeft;
      const from = element.clientWidth;
      pointer(element, "pointerdown", from, 1000);
      assert
        .dom(element)
        .doesNotHaveClass(draggingClass, "press does not change drag styling");
      for (const to of [from / 2, from * 1.5]) {
        pointer(element, "pointermove", to, 1020);
        frames.step();
        assert.strictEqual(
          element.scrollLeft,
          initial - (to - from),
          "scroll follows pointer displacement in either direction"
        );
        assert
          .dom(element)
          .hasClass(draggingClass, "panning enables drag styling");
      }
      pointer(element, "pointerup", from * 1.5, 2000);
      assert
        .dom(element)
        .doesNotHaveClass(draggingClass, "release clears drag styling");
      const released = element.scrollLeft;
      pointer(element, "pointermove", 0, 2010);
      frames.step(10);
      assert.strictEqual(
        element.scrollLeft,
        released,
        "movement after release has no effect"
      );
    });

    test("pan-scroll-oracle: subthreshold movement preserves clicks and styling", async function (assert) {
      const element = await renderBoard();
      const frames = (this.frames = controlFrames());
      const initial = element.scrollLeft;
      let clicks = 0;
      element.addEventListener("click", () => clicks++);
      pointer(element, "pointerdown", element.clientWidth, 1000);
      for (const dx of [-3, 3]) {
        pointer(element, "pointermove", element.clientWidth + dx, 1020);
        frames.step();
        assert.strictEqual(
          element.scrollLeft,
          initial,
          "less than four horizontal pixels never pans"
        );
        assert
          .dom(element)
          .doesNotHaveClass(
            draggingClass,
            "click-sized motion never enables drag styling"
          );
      }
      pointer(element, "pointerup", element.clientWidth + 3, 1021);
      assert.false(
        dispatchClick(element).defaultPrevented,
        "ordinary click is not canceled"
      );
      assert.strictEqual(clicks, 1, "ordinary click reaches its handler");
    });

    for (const [label, tag, attributes, nested] of [
      ["card descendant", "div", { class: "discourse-boards-card" }, true],
      ["button descendant", "button", {}, true],
      ["anchor descendant", "a", { href: "#" }, true],
      ["input", "input", {}, false],
      ["textarea", "textarea", {}, false],
      ["select", "select", {}, false],
      [
        "empty contenteditable descendant",
        "div",
        { contenteditable: "" },
        true,
      ],
      [
        "true contenteditable descendant",
        "div",
        { contenteditable: "true" },
        true,
      ],
    ]) {
      test(`pan-scroll-oracle: skip ${label} preserves clicks`, async function (assert) {
        const element = await renderBoard();
        const frames = (this.frames = controlFrames());
        const control = document.createElement(tag);
        Object.entries(attributes).forEach(([name, value]) =>
          control.setAttribute(name, value)
        );
        const target = nested
          ? control.appendChild(document.createElement("span"))
          : control;
        find("[data-pan-content]").append(control);
        let clicks = 0;
        control.addEventListener("click", (event) => {
          clicks++;
          event.preventDefault();
        });
        const initial = element.scrollLeft;
        const from = element.clientWidth;
        const down = pointer(target, "pointerdown", from, 1000);
        assert.false(
          down.defaultPrevented,
          "skip gate leaves the press available to the control"
        );
        assert
          .dom(element)
          .doesNotHaveClass(
            draggingClass,
            "skipped press does not change styling"
          );
        pointer(target, "pointermove", from / 2, 1020);
        frames.step();
        assert.strictEqual(
          element.scrollLeft,
          initial,
          "even large movement on a skipped target cannot pan"
        );
        assert
          .dom(element)
          .doesNotHaveClass(
            draggingClass,
            "skipped movement does not disable descendants"
          );
        dispatchClick(target);
        assert.strictEqual(
          clicks,
          1,
          "click reaches the control even before release"
        );
        pointer(target, "pointerup", from / 2, 1021);
        dispatchClick(target);
        assert.strictEqual(
          clicks,
          2,
          "click still reaches the control after release"
        );
        assert.strictEqual(
          frames.pending.size,
          0,
          "skipped gesture starts no animation"
        );
      });
    }

    for (const [label, options] of [
      ["touch", { pointerType: "touch" }],
      ["middle button", { button: 1 }],
      ["right button", { button: 2 }],
    ]) {
      test(`pan-scroll-oracle: ignores ${label}`, async function (assert) {
        const element = await renderBoard();
        const frames = (this.frames = controlFrames());
        const initial = element.scrollLeft;
        const down = pointer(
          element,
          "pointerdown",
          element.clientWidth,
          1000,
          options
        );
        pointer(element, "pointermove", 0, 1020, options);
        frames.step();
        pointer(element, "pointerup", 0, 1021, options);
        assert.false(
          down.defaultPrevented,
          "ignored press retains native handling"
        );
        assert.strictEqual(
          element.scrollLeft,
          initial,
          "ignored pointer cannot pan"
        );
        assert
          .dom(element)
          .doesNotHaveClass(
            draggingClass,
            "ignored pointer never enables styling"
          );
        assert.strictEqual(
          frames.pending.size,
          0,
          "ignored pointer starts no animation"
        );
      });
    }

    test("pan-scroll-oracle: no overflow starts nothing", async function (assert) {
      const element = await renderBoard();
      find("[data-pan-content]").style.width = "100%";
      assert.true(
        element.scrollWidth <= element.clientWidth,
        "fixture does not overflow"
      );
      const frames = (this.frames = controlFrames());
      const down = pointer(element, "pointerdown", element.clientWidth, 1000);
      pointer(element, "pointermove", 0, 1020);
      frames.step();
      assert.false(
        down.defaultPrevented,
        "nonoverflowing press retains native handling"
      );
      assert
        .dom(element)
        .doesNotHaveClass(
          draggingClass,
          "nonoverflowing movement never starts panning"
        );
      pointer(element, "pointerup", 0, 1021);
      assert.strictEqual(frames.pending.size, 0, "no coast is scheduled");
    });

    test("pan-scroll-oracle: native horizontal touch action stays allowed", async function (assert) {
      const element = await renderBoard();
      const touchAction = getComputedStyle(element).touchAction.split(" ");
      assert.true(
        touchAction.some((value) =>
          ["auto", "manipulation", "pan-x"].includes(value)
        ),
        "computed touch action permits native horizontal scrolling"
      );
    });

    test("pan-scroll-oracle: active pan suppresses clicks and cancel clears styling without coasting", async function (assert) {
      const element = await renderBoard();
      const frames = (this.frames = controlFrames());
      let clicks = 0;
      find("[data-pan-content]").addEventListener("click", () => clicks++);
      const to = startPan(element, frames);
      assert.true(
        dispatchClick(find("[data-pan-content]")).defaultPrevented,
        "active pan cancels the click"
      );
      assert.strictEqual(
        clicks,
        0,
        "capture suppression prevents descendant activation"
      );
      const beforeCancel = element.scrollLeft;
      pointer(element, "pointercancel", to, 1021);
      assert
        .dom(element)
        .doesNotHaveClass(draggingClass, "cancel clears drag styling");
      pointer(element, "pointermove", 0, 1030);
      frames.step(120);
      assert.strictEqual(
        element.scrollLeft,
        beforeCancel,
        "cancel prevents further panning and coast"
      );
      assert.strictEqual(frames.pending.size, 0, "cancel leaves no animation");
    });

    test("pan-scroll-oracle: threshold uses horizontal movement and stays latched", async function (assert) {
      const element = await renderBoard();
      const frames = (this.frames = controlFrames());
      const from = element.clientWidth;
      const initial = element.scrollLeft;
      pointer(element, "pointerdown", from, 1000);
      pointer(element, "pointermove", from + 3, 1020, {
        clientY: element.clientHeight,
      });
      frames.step();
      assert.strictEqual(
        element.scrollLeft,
        initial,
        "vertical travel cannot turn subthreshold horizontal travel into a pan"
      );
      assert
        .dom(element)
        .doesNotHaveClass(
          draggingClass,
          "vertical travel does not disable descendant clicks"
        );
      pointer(element, "pointermove", from + 4, 1040);
      frames.step();
      assert.strictEqual(
        element.scrollLeft,
        initial - 4,
        "four horizontal pixels starts panning"
      );
      assert.dom(element).hasClass(draggingClass, "threshold enables styling");
      pointer(element, "pointermove", from + 1, 1060);
      frames.step();
      assert.strictEqual(
        element.scrollLeft,
        initial - 1,
        "returning inside threshold still pans once latched"
      );
      assert
        .dom(element)
        .hasClass(draggingClass, "returning inside threshold keeps styling");
      pointer(element, "pointercancel", from + 1, 1061);
    });

    /** The current modifier clears click suppression on release; this pins the refactor baseline. */
    test("pan-scroll-oracle: current post-release click is delivered (baseline finding)", async function (assert) {
      const element = await renderBoard();
      const frames = (this.frames = controlFrames());
      let clicks = 0;
      const target = find("[data-pan-content]");
      target.addEventListener("click", () => clicks++);
      releasePan(element, frames);
      assert.false(
        dispatchClick(target).defaultPrevented,
        "current implementation does not cancel a click after pointerup"
      );
      assert.strictEqual(
        clicks,
        1,
        "post-release click currently reaches the descendant"
      );
    });

    test("pan-scroll-oracle: unrelated pointer cannot move or end the pan", async function (assert) {
      const element = await renderBoard();
      const frames = (this.frames = controlFrames());
      const to = startPan(element, frames);
      const initial = element.scrollLeft;
      pointer(element, "pointermove", 0, 1021, { pointerId: 99 });
      pointer(element, "pointerup", 0, 1022, { pointerId: 99 });
      pointer(element, "pointercancel", 0, 1023, { pointerId: 99 });
      frames.step();
      assert.strictEqual(
        element.scrollLeft,
        initial,
        "unrelated move does not scroll"
      );
      assert
        .dom(element)
        .hasClass(
          draggingClass,
          "unrelated terminal events do not end the pan"
        );
      pointer(element, "pointermove", to - element.clientWidth / 4, 1040);
      frames.step();
      assert.strictEqual(
        element.scrollLeft,
        initial + element.clientWidth / 4,
        "original pointer still controls panning"
      );
      pointer(element, "pointercancel", to, 1041);
    });

    test("pan-scroll-oracle: momentum coasts then settles away from limits", async function (assert) {
      const element = await renderBoard();
      const frames = (this.frames = controlFrames());
      releasePan(element, frames);
      const released = element.scrollLeft;
      frames.step(2);
      assert.true(
        element.scrollLeft > released,
        "release continues scrolling in the pan direction"
      );
      frames.step(600);
      const settled = element.scrollLeft;
      assert.true(
        settled < element.scrollWidth - element.clientWidth,
        "coast settles before hitting the boundary"
      );
      assert.strictEqual(
        frames.pending.size,
        0,
        "coast eventually stops scheduling frames"
      );
      frames.step(60);
      assert.strictEqual(
        element.scrollLeft,
        settled,
        "settled position remains stable"
      );
    });

    for (const cancel of ["press", "wheel"]) {
      test(`pan-scroll-oracle: ${cancel} cancels a running coast`, async function (assert) {
        const element = await renderBoard();
        const frames = (this.frames = controlFrames());
        releasePan(element, frames);
        const released = element.scrollLeft;
        frames.step(2);
        assert.true(
          element.scrollLeft > released,
          "coast was moving before cancellation"
        );
        if (cancel === "press") {
          pointer(element, "pointerdown", element.clientWidth, 1100);
        } else {
          element.dispatchEvent(new WheelEvent("wheel", { bubbles: true }));
        }
        const stopped = element.scrollLeft;
        frames.step(120);
        assert.strictEqual(
          element.scrollLeft,
          stopped,
          "cancellation immediately stops coast"
        );
        assert.strictEqual(frames.pending.size, 0, "no coast frame remains");
      });
    }

    for (const direction of [-1, 1]) {
      test(`pan-scroll-oracle: coast stops at ${direction === -1 ? "end" : "start"} limit`, async function (assert) {
        const element = await renderBoard();
        const frames = (this.frames = controlFrames());
        const limit =
          direction === -1 ? element.scrollWidth - element.clientWidth : 0;
        element.scrollLeft = limit + direction * (element.clientWidth / 4 + 1);
        releasePan(element, frames, direction);
        assert.notStrictEqual(
          element.scrollLeft,
          limit,
          "release is just inside the scrollable range"
        );
        frames.step(600);
        assert.strictEqual(
          element.scrollLeft,
          limit,
          "browser clamps coast to the boundary"
        );
        assert.strictEqual(
          frames.pending.size,
          0,
          "boundary stops the animation loop"
        );
      });
    }

    for (const phase of ["pending move", "active pan", "coast"]) {
      test(`pan-scroll-oracle: teardown during ${phase} removes event effects and frames`, async function (assert) {
        const element = await renderBoard();
        const frames = (this.frames = controlFrames());
        const to = startPan(element, frames);
        if (phase === "pending move") {
          pointer(element, "pointermove", to / 2, 1025);
        } else if (phase === "coast") {
          pointer(element, "pointerup", to, 1021);
          frames.step();
        }
        await clearRender();
        assert.strictEqual(
          frames.pending.size,
          0,
          "teardown cancels all scheduled work"
        );
        assert.false(
          dispatchClick(element).defaultPrevented,
          "detached element has no click suppression listener"
        );
        const move = pointer(element, "pointermove", 0, 1030);
        assert.false(
          move.defaultPrevented,
          "old gesture listener no longer handles moves"
        );
        pointer(element, "pointerup", 0, 1031);
        pointer(element, "pointerdown", element.clientWidth, 1040);
        pointer(element, "pointermove", 0, 1060);
        frames.step(120);
        assert.strictEqual(
          frames.pending.size,
          0,
          "detached events cannot restart animation"
        );
      });
    }
  }
);
