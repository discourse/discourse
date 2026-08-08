import { tracked } from "@glimmer/tracking";
import {
  find,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
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
          @axis="vertical"
          @value={{size}}
          @min={{min}}
          @max={{max}}
          @label="Resize the thing"
          class="my-handle"
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
          @axis="vertical"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          class="my-handle"
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
          @axis="horizontal"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the panel"
          class="my-handle"
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
          @axis="horizontal"
          @value={{size}}
          @min={{0}}
          @max={{800}}
          @label="Resize the panel"
          class="my-handle"
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
          @axis="vertical"
          @value={{unmeasured}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          class="my-handle"
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
          @axis="vertical"
          @side="end"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
          class="my-handle"
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
          @axis="vertical"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          class="my-handle"
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
          @axis="vertical"
          @side="end"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          @onResize={{onResize}}
          class="my-handle"
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
          @axis="vertical"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          class="my-handle"
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
          @axis="horizontal"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the panel"
          class="my-handle"
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
          @axis="vertical"
          @side="end"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          @onResize={{onResize}}
          class="my-handle"
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
          @axis="vertical"
          @side="end"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          @onResize={{onResize}}
          class="my-handle"
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
            @axis="vertical"
            @value={{size}}
            @min={{100}}
            @max={{500}}
            @label="Resize the thing"
            @observe={{resolve}}
            class="my-handle"
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
          @axis="vertical"
          @value={{120}}
          @min={{0}}
          @max={{state.ceiling}}
          @label="Resize the thing"
          class="my-handle"
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
          @axis="vertical"
          @value={{size}}
          @min={{100}}
          @max={{max}}
          @label="Resize the thing"
          class="my-handle"
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
          @axis="vertical"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          @observe={{state.target}}
          class="my-handle"
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
});
