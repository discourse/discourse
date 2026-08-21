import { array } from "@ember/helper";
import {
  find,
  findAll,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import NestedTimeline, {
  branchShape,
} from "discourse/components/nested/timeline";
import { SCROLLER_HEIGHT } from "discourse/components/topic-timeline/container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";

function buildNodes(count) {
  return [...Array(count)].map((_, index) => ({
    post: {
      id: 1000 + index,
      post_number: index + 2,
      created_at: "2026-07-01T10:00:00Z",
    },
    children: [],
    _renderKey: 1000 + index,
  }));
}

module("Integration | Component | Nested | Timeline", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the current position against the total root count", async function (assert) {
    const nodes = buildNodes(2);

    await render(
      <template>
        <NestedTimeline @rootNodes={{nodes}} @rootCount={{40}} />
      </template>
    );

    assert
      .dom(".nested-timeline__position")
      .hasText("1 / 40", "shows the concise visible position");
    assert
      .dom(".nested-timeline__scrollarea")
      .hasAttribute("role", "slider", "exposes slider semantics")
      .hasAttribute("tabindex", "0", "is keyboard focusable")
      .hasAttribute("aria-label", "Topic branches", "names the slider")
      .hasAttribute("aria-orientation", "vertical", "sets its orientation")
      .hasAttribute("aria-valuemin", "1", "sets the first branch")
      .hasAttribute("aria-valuemax", "40", "sets the total branch count")
      .hasAttribute("aria-valuenow", "1", "sets the current branch")
      .hasAttribute(
        "aria-valuetext",
        "Branch 1 of 40",
        "describes the current branch"
      );
    assert
      .dom(".nested-timeline__date")
      .exists("shows the date of the current root");
    assert
      .dom(".nested-timeline__loaded-window")
      .exists("marks the part of the global axis with loaded details");
    assert
      .dom(".nested-timeline__metadata-range")
      .hasText(
        "Details loaded for branches 1–2",
        "explains that blank positions outside the range are unknown"
      );
  });

  test("marks branches with replies, scaled by subtree size", async function (assert) {
    const nodes = buildNodes(3);
    nodes[0].post.total_descendant_count = 0;
    nodes[0].post.direct_reply_count = 0;
    nodes[1].post.total_descendant_count = 2;
    nodes[1].post.direct_reply_count = 2;
    nodes[2].post.total_descendant_count = 80;
    nodes[2].post.direct_reply_count = 1;

    await render(
      <template>
        <NestedTimeline @rootNodes={{nodes}} @rootCount={{3}} />
      </template>
    );

    const marks = findAll(".nested-timeline__mark");
    assert.strictEqual(marks.length, 2, "reply-less roots get no mark");

    const widthOf = (mark) => parseFloat(mark.style.width);
    assert.true(
      widthOf(marks[1]) > widthOf(marks[0]),
      "bigger subtrees get longer marks"
    );
    assert.true(
      parseFloat(marks[1].style.top) > parseFloat(marks[0].style.top),
      "marks are ordered along the track"
    );
  });

  test("distinguishes a wide flat branch from a deep chain", async function (assert) {
    const wide = buildNodes(1)[0];
    wide.post.total_descendant_count = 80;
    wide.post.direct_reply_count = 80;
    wide.children = buildNodes(3).map((node, index) => ({
      ...node,
      post: { ...node.post, id: 2_000 + index },
    }));

    const deep = buildNodes(1)[0];
    deep.post.id = 3_000;
    deep.post.total_descendant_count = 80;
    deep.post.direct_reply_count = 1;
    let tip = deep;
    for (let depth = 1; depth <= 3; depth++) {
      const child = buildNodes(1)[0];
      child.post.id = 3_000 + depth;
      child.post.total_descendant_count = 80 - depth;
      child.post.direct_reply_count = 1;
      tip.children = [child];
      tip = child;
    }

    assert.deepEqual(branchShape(wide), { depth: 1, continues: false });
    assert.deepEqual(branchShape(deep), { depth: 5, continues: true });

    await render(
      <template>
        <NestedTimeline
          @rootNodes={{array wide deep}}
          @rootCount={{2}}
          style="display: block"
        />
      </template>
    );

    assert
      .dom(".nested-timeline__branch-summary")
      .hasText("80 replies · 1 level deep");
    assert
      .dom(".nested-timeline__legend")
      .hasText("Detailed range More replies Deeper Continues");
    assert
      .dom(".nested-timeline__legend-symbol.--loaded")
      .exists("shows the loaded-details key");
    assert
      .dom(".nested-timeline__legend-symbol.--amount")
      .exists("shows the reply amount key");
    assert
      .dom(".nested-timeline__legend-symbol.--depth")
      .exists("shows the nesting depth key");
    assert
      .dom(".nested-timeline__legend-symbol.--continuation")
      .exists("shows the continuation key");
    assert.strictEqual(
      findAll(".nested-timeline__mark")[0].querySelectorAll(
        ".nested-timeline__mark-notch"
      ).length,
      1,
      "flat branches have one depth notch"
    );
    assert
      .dom(findAll(".nested-timeline__mark")[1])
      .hasText("+", "deep branches expose a continuation sign");
  });

  test("falls back to the loaded roots when the total is unknown", async function (assert) {
    const nodes = buildNodes(3);

    await render(<template><NestedTimeline @rootNodes={{nodes}} /></template>);

    assert
      .dom(".nested-timeline__position")
      .hasText("1 / 3", "uses the loaded root count as its total");
  });

  test("spans the whole window when the total is unknown off page zero", async function (assert) {
    const nodes = buildNodes(3);

    await render(
      <template>
        <NestedTimeline
          @rootNodes={{nodes}}
          @rootWindowStart={{20}}
          style="display: block"
        />
      </template>
    );

    assert
      .dom(".nested-timeline__scrollarea")
      .hasAttribute(
        "aria-valuemax",
        "23",
        "spans the roots the window has already paged past"
      );
    assert
      .dom(".nested-timeline__metadata-range")
      .hasText(
        "Details loaded for branches 21–23",
        "places the loaded window on that axis"
      );
  });

  test("moves the handle in the direction of the pressed key", async function (assert) {
    const nodes = buildNodes(2);
    const jumps = [];
    const jumpToRoot = (index) => {
      jumps.push(index);
      return { index, reached: true };
    };

    await render(
      <template>
        <NestedTimeline
          @rootNodes={{nodes}}
          @rootCount={{40}}
          @jumpToRoot={{jumpToRoot}}
          style="display: block"
        />
      </template>
    );

    await triggerKeyEvent(
      ".nested-timeline__scrollarea",
      "keydown",
      "ArrowDown"
    );
    await triggerKeyEvent(
      ".nested-timeline__scrollarea",
      "keydown",
      "PageDown"
    );
    await triggerKeyEvent(".nested-timeline__scrollarea", "keydown", "End");
    await triggerKeyEvent(".nested-timeline__scrollarea", "keydown", "PageUp");
    await triggerKeyEvent(".nested-timeline__scrollarea", "keydown", "ArrowUp");
    await triggerKeyEvent(".nested-timeline__scrollarea", "keydown", "Home");

    assert.deepEqual(
      jumps,
      [1, 5, 39, 35, 34, 0],
      "follows the handle downwards and upwards, by one, by a page, and to both boundaries"
    );
    assert
      .dom(".nested-timeline__scrollarea")
      .hasAttribute("aria-valuenow", "1", "keeps ARIA state synchronized");
  });

  test("reports a bounded jump that stops before its target", async function (assert) {
    const nodes = buildNodes(2);
    const jumpToRoot = () => ({ index: 19, reached: false });

    await render(
      <template>
        <NestedTimeline
          @rootNodes={{nodes}}
          @rootCount={{40}}
          @jumpToRoot={{jumpToRoot}}
          style="display: block"
        />
      </template>
    );

    await triggerKeyEvent(".nested-timeline__scrollarea", "keydown", "End");

    assert
      .dom(".nested-timeline__position")
      .hasText("20 / 40", "returns the handle to the root that was reached");
    assert
      .dom(".nested-timeline__status")
      .hasText(
        "Reached 20 of 40. Activate again to continue.",
        "explains how to continue the bounded jump"
      );
  });

  test("clicking the track jumps to the matching root", async function (assert) {
    const nodes = buildNodes(2);
    const jumps = [];
    const jumpToRoot = (index) => {
      jumps.push(index);
    };

    await render(
      <template>
        <NestedTimeline
          @rootNodes={{nodes}}
          @rootCount={{40}}
          @jumpToRoot={{jumpToRoot}}
          style="display: block"
        />
      </template>
    );

    const scrollarea = find(".nested-timeline__scrollarea");
    const rect = scrollarea.getBoundingClientRect();

    await triggerEvent(scrollarea, "click", {
      clientY: rect.bottom + rect.height,
    });

    assert.deepEqual(
      jumps,
      [39],
      "clicking past the end targets the last root"
    );
    assert
      .dom(".nested-timeline__position")
      .hasText("40 / 40", "shows the final root");

    await triggerEvent(scrollarea, "click", {
      clientY: rect.top,
    });

    assert.deepEqual(jumps, [39, 0], "clicking the top targets the first root");
    assert
      .dom(".nested-timeline__position")
      .hasText("1 / 40", "shows the first root");
  });

  test("positions loaded branch metadata on the stable global axis", async function (assert) {
    const nodes = buildNodes(1);
    nodes[0].post.total_descendant_count = 9;

    await render(
      <template>
        <NestedTimeline
          @rootNodes={{nodes}}
          @rootCount={{40}}
          @rootWindowStart={{20}}
          style="display: block"
        />
      </template>
    );

    const scrollarea = find(".nested-timeline__scrollarea");
    const trackHeight = scrollarea.offsetHeight - SCROLLER_HEIGHT;
    const markTop = parseFloat(find(".nested-timeline__mark").style.top);
    const expectedTop = trackHeight / 2 + SCROLLER_HEIGHT / 2;

    assert.true(
      Math.abs(markTop - expectedTop) < 0.2,
      "places root 21 halfway along a forty-root topic"
    );
    assert
      .dom(".nested-timeline__metadata-range")
      .hasText(
        "Details loaded for branches 21–21",
        "labels the sparse metadata window on the global axis"
      );
  });

  test("dragging tracks the pointer's travel and commits once on release", async function (assert) {
    const nodes = buildNodes(2);
    const jumps = [];
    const jumpToRoot = (index) => {
      jumps.push(index);
    };

    await render(
      <template>
        <NestedTimeline
          @rootNodes={{nodes}}
          @rootCount={{40}}
          @jumpToRoot={{jumpToRoot}}
          style="display: block"
        />
      </template>
    );

    const scroller = find(".nested-timeline__scroller");
    const scrollarea = find(".nested-timeline__scrollarea");
    const trackHeight = scrollarea.offsetHeight - scroller.offsetHeight;
    stubPointerCapture(scroller);

    // Grabbing off-centre must not move the handle: travel is measured from
    // wherever the press landed.
    const grabY = scroller.getBoundingClientRect().top + 10;
    await triggerEvent(scroller, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: grabY,
    });
    assert
      .dom(".nested-timeline__position")
      .hasText("1 / 40", "grabbing off-centre does not move the position");
    assert
      .dom(".nested-timeline__scroller")
      .hasClass("is-dragging", "the gesture owns the dragging class");

    await triggerEvent(scroller, "pointermove", {
      pointerId: 1,
      clientX: 0,
      clientY: grabY + trackHeight / 2,
    });
    assert
      .dom(".nested-timeline__position")
      .hasText("21 / 40", "the handle follows the pointer's travel");
    assert.deepEqual(jumps, [], "no jump while dragging");

    await triggerEvent(scroller, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: grabY + trackHeight / 2,
    });
    assert.deepEqual(jumps, [20], "commits a single jump on release");
    assert
      .dom(".nested-timeline__scroller")
      .doesNotHaveClass("is-dragging", "the dragging class is released");
  });

  test("a press that never travelled does not jump", async function (assert) {
    const nodes = buildNodes(2);
    const jumps = [];
    const jumpToRoot = (index) => {
      jumps.push(index);
    };

    await render(
      <template>
        <NestedTimeline
          @rootNodes={{nodes}}
          @rootCount={{40}}
          @jumpToRoot={{jumpToRoot}}
          style="display: block"
        />
      </template>
    );

    const scroller = find(".nested-timeline__scroller");
    stubPointerCapture(scroller);
    const grabY = scroller.getBoundingClientRect().top + 10;

    await triggerEvent(scroller, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: grabY,
    });
    await triggerEvent(scroller, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: grabY,
    });

    assert.deepEqual(jumps, [], "a click on the handle is not a scrub");
  });

  test("an interrupted gesture releases the handle instead of freezing it", async function (assert) {
    const nodes = buildNodes(2);
    const jumps = [];
    const jumpToRoot = (index) => {
      jumps.push(index);
    };

    await render(
      <template>
        <NestedTimeline
          @rootNodes={{nodes}}
          @rootCount={{40}}
          @jumpToRoot={{jumpToRoot}}
          style="display: block"
        />
      </template>
    );

    const scroller = find(".nested-timeline__scroller");
    const scrollarea = find(".nested-timeline__scrollarea");
    const trackHeight = scrollarea.offsetHeight - scroller.offsetHeight;
    stubPointerCapture(scroller);
    const grabY = scroller.getBoundingClientRect().top + 10;

    await triggerEvent(scroller, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: grabY,
    });
    await triggerEvent(scroller, "pointermove", {
      pointerId: 1,
      clientX: 0,
      clientY: grabY + trackHeight / 2,
    });
    assert.dom(".nested-timeline__position").hasText("21 / 40");

    // The browser or OS takes the gesture away mid-scrub.
    await triggerEvent(scroller, "pointercancel", {
      pointerId: 1,
      clientX: 0,
      clientY: grabY + trackHeight / 2,
    });

    assert.deepEqual(jumps, [], "a cancelled scrub does not commit");
    assert
      .dom(".nested-timeline__scroller")
      .doesNotHaveClass(
        "is-dragging",
        "the handle is no longer held by the gesture"
      );
    assert
      .dom(".nested-timeline__position")
      .hasText("1 / 40", "the preview is dropped and the position resyncs");
  });
});
