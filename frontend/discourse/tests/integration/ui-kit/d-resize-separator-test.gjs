import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { trustHTML } from "@ember/template";
import {
  clearRender,
  find,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  settleGestureFrame,
  stubPointerCapture,
} from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";

module("Integration | ui-kit | DResizeSeparator", function (hooks) {
  setupRenderingTest(hooks);

  test("a vertical resize is announced as a horizontal separator", async function (assert) {
    const size = () => 300;
    const min = () => 100;
    const max = () => 500;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{max}}
          @min={{min}}
          @value={{size}}
        />
      </template>
    );

    assert
      .dom(".my-handle")
      .hasAttribute("role", "separator", "it is a separator")
      .hasAttribute(
        "aria-orientation",
        "horizontal",
        "a separator between vertically stacked regions is itself a horizontal bar, so the orientation is the opposite of the axis"
      )
      .hasAttribute("tabindex", "0", "it is a single tab stop")
      .hasAttribute(
        "aria-label",
        "Resize the thing",
        "the label names what is being resized"
      )
      .hasAttribute("aria-valuenow", "300", "the current size is announced")
      .hasAttribute("aria-valuemin", "100", "the lower bound is announced")
      .hasAttribute("aria-valuemax", "500", "the upper bound is announced");
  });

  test("carries a styling hook that does not depend on the ARIA", async function (assert) {
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @value={{size}}
        />
      </template>
    );

    // Stylesheets key off these, never off `role` or `aria-orientation`: those are
    // what the element promises assistive technology, and a consumer may override
    // them through attributes without meaning to restyle anything.
    assert
      .dom(".my-handle")
      .hasClass("d-resize-separator", "it carries its own class")
      .hasAttribute("data-resize-axis", "vertical");
    assert
      .dom(".my-handle")
      .hasClass(
        "my-handle",
        "and keeps the consumer's, rather than replacing it"
      );
  });

  test("the styling hook names the axis being resized, not the bar's direction", async function (assert) {
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="horizontal"
          @label="Resize the panel"
          @max={{500}}
          @min={{100}}
          @value={{size}}
        />
      </template>
    );

    assert.dom(".my-handle").hasAttribute("data-resize-axis", "horizontal");
    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-orientation",
        "vertical",
        "which is the opposite of what it announces, so the two must not be conflated"
      );
  });

  test("a horizontal resize is announced as a vertical separator", async function (assert) {
    const size = () => 240;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="horizontal"
          @label="Resize the panel"
          @max={{800}}
          @min={{0}}
          @value={{size}}
        />
      </template>
    );

    assert
      .dom(".my-handle")
      .hasAttribute("aria-orientation", "vertical")
      .hasAttribute("aria-valuenow", "240")
      .hasAttribute("aria-valuemin", "0", "a plain number is accepted too")
      .hasAttribute("aria-valuemax", "800");
  });

  test("nothing is announced as the size until it has been measured", async function (assert) {
    const unmeasured = () => null;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @value={{unmeasured}}
        />
      </template>
    );

    // Reporting zero would claim the box has no height. An absent value says
    // "not known yet", which is the honest answer before a measurement lands.
    assert.dom(".my-handle").doesNotHaveAttribute("aria-valuenow");
    assert.dom(".my-handle").hasAttribute("aria-valuemin", "100");
  });

  test("a pointer drag reports the new size and updates what is announced", async function (assert) {
    const reports = [];
    let current = 300;
    const size = () => current;
    const onResize = (next) => {
      current = next;
      reports.push(`resize:${next}`);
    };
    const onResizeEnd = (next) => reports.push(`end:${next}`);

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
          @side="end"
          @value={{size}}
        />
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 400,
    });
    // Docked against the block-end, so dragging up grows the box.
    await triggerEvent(handle, "pointermove", {
      pointerId: 1,
      clientX: 0,
      clientY: 360,
    });
    await triggerEvent(handle, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 360,
    });

    // Asserted on the outcome rather than the cadence: how many previews precede a
    // commit is the modifier's contract and is pinned by its own suite.
    assert.deepEqual(
      reports.filter((report) => report.startsWith("end:")),
      ["end:340"],
      "the gesture commits exactly once, at the size it ended on"
    );
    assert.true(
      reports.every((report) => report.endsWith(":340")),
      "the consumer is told the size, not the pointer position"
    );
    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuenow",
        "340",
        "and the announced size follows without the consumer wiring it"
      );
  });

  test("renders block content, for a handle that shows an affordance", async function (assert) {
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @value={{size}}
        ><span class="my-grip">grip</span></DResizeSeparator>
      </template>
    );

    // Some handles draw themselves with a pseudo-element, others put a real icon
    // inside. Both have to be possible without giving up the separator semantics.
    assert
      .dom(".my-handle .my-grip")
      .exists("content passed to the separator is rendered inside it");
  });

  test("the announced size settles on commit rather than following every move", async function (assert) {
    let current = 300;
    const size = () => current;
    const onResize = (next) => (current = next);

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @onResize={{onResize}}
          @side="end"
          @value={{size}}
        />
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 400,
    });
    await triggerEvent(handle, "pointermove", { pointerId: 1, clientY: 360 });

    // Deliberately unchanged mid-gesture. The modifier reports the last move and the
    // commit in one stack, so writing tracked state in between opens a runloop, and
    // a consumer callback reached with one already open loses the wrapper that hands
    // its exceptions to the framework. The composer's persistence-failure acceptance
    // test is what guards that consequence; this pins the behaviour that avoids it.
    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuenow",
        "300",
        "nothing is announced while it moves"
      );

    await triggerEvent(handle, "pointerup", { pointerId: 1, clientY: 360 });

    assert
      .dom(".my-handle")
      .hasAttribute("aria-valuenow", "340", "the committed size is announced");
  });

  test("the cursor is held on the page for the length of the gesture", async function (assert) {
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @value={{size}}
        />
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");

    assert.dom(document.body).doesNotHaveClass("d-resizing-ns");

    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 400,
    });

    // Keeping the cursor of the element a drag began on is engine-dependent, so
    // the intent is stated on the page for as long as the gesture lasts.
    assert
      .dom(document.body)
      .hasClass("d-resizing-ns", "the axis decides which cursor is held");

    await triggerEvent(handle, "pointerup", { pointerId: 1, clientY: 400 });

    assert
      .dom(document.body)
      .doesNotHaveClass("d-resizing-ns", "and it is given back on release");
  });

  test("a horizontal gesture holds the other cursor", async function (assert) {
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="horizontal"
          @label="Resize the panel"
          @max={{500}}
          @min={{100}}
          @value={{size}}
        />
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 200,
      clientY: 0,
    });

    assert.dom(document.body).hasClass("d-resizing-ew");
    assert.dom(document.body).doesNotHaveClass("d-resizing-ns");

    await triggerEvent(handle, "pointerup", { pointerId: 1, clientX: 200 });
    assert.dom(document.body).doesNotHaveClass("d-resizing-ew");
  });

  test("a held arrow key keeps the announced size in step", async function (assert) {
    let current = 300;
    const size = () => current;
    const onResize = (next) => (current = next);

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @onResize={{onResize}}
          @side="end"
          @value={{size}}
        />
      </template>
    );

    // A held key is one gesture spanning every repeat, so the commit that would
    // otherwise refresh the announcement does not arrive until release. Assistive
    // technology reading the value in between must not be told a stale one.
    await triggerKeyEvent(".my-handle", "keydown", "ArrowUp");
    await triggerKeyEvent(".my-handle", "keydown", "ArrowUp");

    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuenow",
        "332",
        "two repeats of a 16px step are announced before the key is released"
      );
  });

  test("arrow keys resize without a pointer", async function (assert) {
    const reports = [];
    let current = 300;
    const size = () => current;
    const onResize = (next) => {
      current = next;
      reports.push(next);
    };

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @onResize={{onResize}}
          @side="end"
          @value={{size}}
        />
      </template>
    );

    await triggerKeyEvent(".my-handle", "keydown", "ArrowUp");
    // The announced size settles when the key is released, the same way it
    // settles when a pointer is.
    await triggerKeyEvent(".my-handle", "keyup", "ArrowUp");

    assert.deepEqual(
      reports,
      [316],
      "one press reports once, a single 16px step above the starting size"
    );
    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuenow",
        "316",
        "the keyboard path keeps the announced size in step too"
      );
  });

  test("re-reads the size when the box it resizes changes on its own", async function (assert) {
    const size = () => find(".the-box")?.clientHeight ?? null;
    const resolve = (separator) => separator.parentElement;

    await render(
      <template>
        <div class="the-box" style="height: 300px">
          <DResizeSeparator
            class="my-handle"
            @axis="vertical"
            @label="Resize the thing"
            @max={{500}}
            @measure={{resolve}}
            @min={{100}}
            @value={{size}}
          />
        </div>
      </template>
    );

    assert.dom(".my-handle").hasAttribute("aria-valuenow", "300");

    // The box can be resized by things no gesture caused — a panel opening, a
    // preview toggling, the window changing — and the announced size has to follow
    // without the consumer wiring anything up.
    find(".the-box").style.height = "420px";
    await waitUntil(
      () => find(".my-handle").getAttribute("aria-valuenow") === "420"
    );

    assert.dom(".my-handle").hasAttribute("aria-valuenow", "420");
  });

  test("a plain value is announced as it changes, without waiting for a gesture", async function (assert) {
    const state = new (class {
      @tracked ceiling = 400;
    })();

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{state.ceiling}}
          @min={{0}}
          @value={{120}}
        />
      </template>
    );

    assert.dom(".my-handle").hasAttribute("aria-valuemax", "400");

    // A number given directly is already reactive, so it is read straight through
    // rather than mirrored: snapshotting it would freeze it until something else
    // happened to trigger a re-read.
    state.ceiling = 900;
    await settled();

    assert.dom(".my-handle").hasAttribute("aria-valuemax", "900");
  });

  test("re-reads the bounds when the viewport changes", async function (assert) {
    let ceiling = 500;
    const size = () => 300;
    const max = () => ceiling;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{max}}
          @min={{100}}
          @value={{size}}
        />
      </template>
    );

    assert.dom(".my-handle").hasAttribute("aria-valuemax", "500");

    // How large a box may grow is usually whatever is left of the window, and a
    // window change need not alter the box itself, so nothing else would notice.
    ceiling = 900;
    window.dispatchEvent(new Event("resize"));
    await settled();

    assert.dom(".my-handle").hasAttribute("aria-valuemax", "900");
  });

  test("starts observing a box that only exists after the first render", async function (assert) {
    const state = new (class {
      @tracked target = null;
    })();
    const size = () => find(".late-box")?.clientHeight ?? null;

    await render(
      <template>
        <div class="late-box" style="height: 200px"></div>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @measure={{state.target}}
          @min={{100}}
          @value={{size}}
        />
      </template>
    );

    // Nothing was being observed yet, so a change went unnoticed.
    find(".late-box").style.height = "260px";
    await settled();
    assert.dom(".my-handle").hasAttribute("aria-valuenow", "200");

    // A consumer that builds its own box after render hands it over once it exists.
    state.target = find(".late-box");
    await settled();

    find(".late-box").style.height = "340px";
    await waitUntil(
      () => find(".my-handle").getAttribute("aria-valuenow") === "340"
    );

    assert.dom(".my-handle").hasAttribute("aria-valuenow", "340");
  });

  test("a drag on an unmeasured size reports nothing rather than resizing from zero", async function (assert) {
    const unmeasured = () => null;
    const reports = [];
    const record = (size) => reports.push(size);

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @onResize={{record}}
          @onResizeEnd={{record}}
          @side="end"
          @value={{unmeasured}}
        />
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 400,
    });
    await triggerEvent(handle, "pointermove", { pointerId: 1, clientY: 360 });
    await settleGestureFrame();
    await triggerEvent(handle, "pointerup", { pointerId: 1, clientY: 360 });

    // Without a starting size there is nothing to resize *from*, so the honest
    // answer is to refuse. Reporting would clamp `null + delta` to a bound and
    // move the box somewhere the user never dragged.
    assert.deepEqual(
      reports,
      [],
      "an unmeasured size refuses the gesture instead of reporting a clamped one"
    );
  });

  test("resize keys on an unmeasured size are left to the browser", async function (assert) {
    const unmeasured = () => null;
    const reports = [];
    const record = (size) => reports.push(size);

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @onResize={{record}}
          @onResizeEnd={{record}}
          @value={{unmeasured}}
        />
      </template>
    );

    await triggerKeyEvent(".my-handle", "keydown", "ArrowUp");
    await triggerKeyEvent(".my-handle", "keyup", "ArrowUp");

    assert.deepEqual(
      reports,
      [],
      "an unmeasured size opens no keyboard gesture"
    );
  });

  test("onResizeStart reaches the consumer, once, before the first size", async function (assert) {
    const events = [];
    let current = 300;
    const size = () => current;

    const onResizeStart = () => events.push("start");
    const onResize = (next) => {
      current = next;
      events.push(`resize:${next}`);
    };
    const onResizeEnd = (next) => events.push(`end:${next}`);

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
          @onResizeStart={{onResizeStart}}
          @side="end"
          @value={{size}}
        />
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 400,
    });
    await triggerEvent(handle, "pointermove", { pointerId: 1, clientY: 360 });
    await triggerEvent(handle, "pointerup", { pointerId: 1, clientY: 360 });

    // Consumers that suppress transitions or open an overlay for the length of a
    // gesture hang off this, so it has to survive the component forwarding it.
    assert.strictEqual(
      events[0],
      "start",
      "the gesture opens before it reports"
    );
    assert.strictEqual(
      events.filter((event) => event === "start").length,
      1,
      "and opens exactly once"
    );
    assert.strictEqual(events.at(-1), "end:340", "with the commit last");
  });

  test("the announced size keeps up with a value that is a live DOM measurement", async function (assert) {
    // The suite's other fixtures are synchronous closures, which update before
    // the component re-reads them. A real measurement cannot: it only changes
    // once the consumer's tracked write has rendered, which is precisely the
    // case the function form of `@value` exists for.
    class Host extends Component {
      @tracked height = 300;
      registerBox = (element) => (this.#box = element);
      measure = () => (this.#box ? this.#box.offsetHeight : null);
      onResize = (size) => (this.height = size);
      #box;

      get boxStyle() {
        return trustHTML(`height: ${this.height}px`);
      }

      <template>
        <div
          class="the-box"
          style={{this.boxStyle}}
          {{didInsert this.registerBox}}
        ></div>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @onResize={{this.onResize}}
          @side="end"
          @value={{this.measure}}
        />
      </template>
    }

    await render(<template><Host /></template>);

    const { element: handle } = stubPointerCapture(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 400,
    });
    await triggerEvent(handle, "pointermove", { pointerId: 1, clientY: 360 });
    await triggerEvent(handle, "pointerup", { pointerId: 1, clientY: 360 });

    assert.dom(".the-box").hasStyle({ height: "340px" }, "the box resized");
    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuenow",
        "340",
        "and the announcement matches it rather than trailing a render behind"
      );
  });

  test("the announced size stays inside the announced bounds", async function (assert) {
    // A bound derived from the viewport can drop below a size the consumer has
    // not yet reduced. ARIA requires valuenow to lie within valuemin..valuemax,
    // and a screen reader reading 500 of a 400 maximum is nonsense.
    const shrinkingMax = () => 400;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{shrinkingMax}}
          @min={{100}}
          @value={{500}}
        />
      </template>
    );

    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuenow",
        "400",
        "a size beyond the maximum is announced as the maximum"
      );
  });

  test("@measure supplies the size and bounds when none are given", async function (assert) {
    const previews = [];
    const commits = [];
    const preview = (size) => previews.push(size);
    const commit = (size) => commits.push(size);
    const findBox = (separator) =>
      separator.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div
            class="box"
            style="height: 300px; min-height: 100px; max-height: 500px"
          ></div>
          <DResizeSeparator
            class="my-handle"
            @axis="vertical"
            @label="Resize the thing"
            @measure={{findBox}}
            @onResize={{preview}}
            @onResizeEnd={{commit}}
            @side="end"
          />
        </div>
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 400,
    });
    await triggerEvent(handle, "pointermove", { pointerId: 1, clientY: 360 });
    await settleGestureFrame();
    await triggerEvent(handle, "pointerup", { pointerId: 1, clientY: 360 });

    // On the outcome rather than the cadence, as the sibling drags do: how many
    // previews precede a commit belongs to the modifier's own suite.
    assert.deepEqual(
      commits,
      [340],
      "the gesture runs from the box's own height without being told it"
    );
    assert.true(previews.length > 0, "previews arrived at all");
    assert.true(
      previews.every((size) => size === 340),
      "and every one of them agrees with the commit"
    );
    assert
      .dom(".my-handle")
      .hasAttribute("aria-valuemin", "100", "the minimum comes from the box")
      .hasAttribute("aria-valuemax", "500", "and so does the maximum");
  });

  test("@measure re-reads the box, so a second drag starts where the first left it", async function (assert) {
    const commits = [];
    const commit = (size) => commits.push(size);
    const findBox = (separator) =>
      separator.closest(".fixture")?.querySelector(".box");
    // The box really takes the size, the way a consumer applies it.
    const apply = (size) => (find(".box").style.height = `${size}px`);

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="height: 300px; min-height: 100px"></div>
          <DResizeSeparator
            class="my-handle"
            @axis="vertical"
            @label="Resize the thing"
            @max={{900}}
            @measure={{findBox}}
            @onResize={{apply}}
            @onResizeEnd={{commit}}
            @side="end"
          />
        </div>
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");
    for (const [from, to] of [
      [400, 360],
      [400, 380],
    ]) {
      await triggerEvent(handle, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientY: from,
      });
      await triggerEvent(handle, "pointermove", { pointerId: 1, clientY: to });
      await settleGestureFrame();
      await triggerEvent(handle, "pointerup", { pointerId: 1, clientY: to });
    }

    // Read once and frozen, the second drag would start from 300 again and
    // commit 320. This is the trap that made every consumer pass a function.
    assert.deepEqual(
      commits,
      [340, 360],
      "the second gesture grows from the size the first one left"
    );
  });

  test("explicit sizes win over @measure", async function (assert) {
    const reports = [];
    const record = (size) => reports.push(size);
    const findBox = (separator) =>
      separator.closest(".fixture")?.querySelector(".box");
    const size = () => 120;

    await render(
      <template>
        <div class="fixture">
          <div
            class="box"
            style="height: 300px; min-height: 20px; max-height: 700px"
          ></div>
          <DResizeSeparator
            class="my-handle"
            @axis="vertical"
            @label="Resize the thing"
            @max={{800}}
            @measure={{findBox}}
            @min={{0}}
            @onResizeEnd={{record}}
            @side="end"
            @value={{size}}
          />
        </div>
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 400,
    });
    await triggerEvent(handle, "pointermove", { pointerId: 1, clientY: 360 });
    await settleGestureFrame();
    await triggerEvent(handle, "pointerup", { pointerId: 1, clientY: 360 });

    // A consumer whose number is not a measurement of the box keeps its own,
    // and the box's own 20/700 are not what bound it either.
    assert.deepEqual(
      reports,
      [160],
      "the supplied size is used, not the box's 300"
    );
    assert
      .dom(".my-handle")
      .hasAttribute("aria-valuemin", "0", "the supplied minimum wins")
      .hasAttribute("aria-valuemax", "800", "and so does the supplied maximum");
  });

  test("@measure takes its bounds from the axis being resized", async function (assert) {
    const findBox = (separator) =>
      separator.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div
            class="box"
            style="width: 220px; min-width: 60px; max-width: 400px;
              height: 300px; min-height: 111px; max-height: 999px"
          ></div>
          <DResizeSeparator
            class="my-handle"
            @axis="horizontal"
            @label="Resize the panel"
            @measure={{findBox}}
          />
        </div>
      </template>
    );

    // The vertical values are deliberately distinctive: reading `minHeight` or
    // `maxHeight` here would announce 111 or 999, which a size-only assertion
    // would not notice. Which viewport dimension caps which axis is pinned
    // separately below, since a declared maximum sits under both.
    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuemin",
        "60",
        "the width minimum, not the height's"
      )
      .hasAttribute("aria-valuemax", "400", "and the width maximum");
  });

  test("an undeclared maximum is capped by the viewport dimension of its own axis", async function (assert) {
    const findBox = (separator) =>
      separator.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 300px"></div>
          <DResizeSeparator
            class="my-handle"
            @axis="horizontal"
            @label="Resize the panel"
            @measure={{findBox}}
          />
        </div>
      </template>
    );

    // With nothing declared, the cap is all that bounds it, so this is the only
    // place the axis of the cap itself is observable. Every other fixture
    // declares a maximum below both viewport dimensions.
    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuemax",
        String(document.documentElement.clientWidth),
        "the width of the viewport, not its height"
      );
  });

  test("a minimum that is not a pixel length falls back to the floor", async function (assert) {
    const findBox = (separator) =>
      separator.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture" style="height: 800px">
          {{! A percentage is the dangerous one: unlike `min-content` it parses
            to a plausible number, so only checking the unit catches it. }}
          <div class="box" style="height: 300px; min-height: 50%"></div>
          <DResizeSeparator
            class="my-handle"
            @axis="vertical"
            @label="Resize the thing"
            @measure={{findBox}}
          />
        </div>
      </template>
    );

    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuemin",
        "250",
        "the floor stands in, rather than 50 being read as pixels"
      );
    // The floor is also what an unresolved box reports, so this separates
    // "fell back" from "never found the box at all".
    assert
      .dom(".my-handle")
      .hasAttribute("aria-valuenow", /\d/, "and the box itself was measured");
  });

  test("@measure reads the axis being resized", async function (assert) {
    const findBox = (separator) =>
      separator.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 300px"></div>
          <DResizeSeparator
            class="my-handle"
            @axis="horizontal"
            @label="Resize the panel"
            @measure={{findBox}}
          />
        </div>
      </template>
    );

    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuenow",
        "220",
        "a horizontal resize measures width, not height"
      );
  });

  test("a gesture that already ended is not committed again at teardown", async function (assert) {
    const ends = [];
    const record = (size) => ends.push(size);
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @onResizeEnd={{record}}
          @side="end"
          @value={{size}}
        />
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 400,
    });
    await triggerEvent(handle, "pointermove", { pointerId: 1, clientY: 360 });
    await settleGestureFrame();
    await triggerEvent(handle, "pointerup", { pointerId: 1, clientY: 360 });

    assert.deepEqual(ends, [340], "the release committed once");

    await clearRender();

    // Leaving the gesture marked open on a normal end would commit the same
    // size a second time here, which the sibling test above cannot see.
    assert.deepEqual(ends, [340], "and teardown has nothing left to commit");
  });

  test("a gesture still open at teardown is closed once", async function (assert) {
    const ends = [];
    const record = (size) => ends.push(size);
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          class="my-handle"
          @axis="vertical"
          @label="Resize the thing"
          @max={{500}}
          @min={{100}}
          @onResizeEnd={{record}}
          @side="end"
          @value={{size}}
        />
      </template>
    );

    const { element: handle } = stubPointerCapture(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 400,
    });
    await triggerEvent(handle, "pointermove", { pointerId: 1, clientY: 360 });
    await settleGestureFrame();

    assert.deepEqual(ends, [], "nothing committed while the gesture is held");

    // The pointer is still down. The gesture engine reports nothing when the
    // element goes, so without this the consumer never learns the gesture ended
    // and whatever it opened at the start stays open.
    await clearRender();

    assert.deepEqual(
      ends,
      [340],
      "teardown commits the last size the gesture reported"
    );
  });
});
