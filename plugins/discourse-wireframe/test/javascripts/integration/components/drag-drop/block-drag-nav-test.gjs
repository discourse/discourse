import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// Center-point viewport coords of an element, for a realistic drag location.
function centerOf(selector) {
  const r = document.querySelector(selector).getBoundingClientRect();
  return { clientX: r.left + r.width / 2, clientY: r.top + r.height / 2 };
}

// Wraps coords as the PDND monitor `location` shape the service reads.
function dragAt({ clientX, clientY }) {
  return { location: { current: { input: { clientX, clientY } } } };
}

module("Integration | discourse-wireframe | block drag-nav", function (hooks) {
  setupRenderingTest(hooks);

  test("dwelling a tab reveals it by clicking the tab button", async function (assert) {
    const service = this.owner.lookup("service:wireframe-drag-dwell");
    const clicks = [];
    const record = (key) => clicks.push(key);

    // Stand-in for the editing tabs strip: each tab button carries the
    // `data-wf-tab-panel-key` marker the block adds in an editing context and
    // wires its own click handler (here, a spy) the way the real block wires
    // `selectTab`.
    await render(
      <template>
        <div class="d-block-tabs">
          <button
            id="tab-a"
            type="button"
            data-wf-tab-panel-key="a"
            {{on "click" (fn record "a")}}
          >A</button>
          <button
            id="tab-b"
            type="button"
            data-wf-tab-panel-key="b"
            {{on "click" (fn record "b")}}
          >B</button>
        </div>
      </template>
    );

    service.handleDragStart();
    service.handleDrag(dragAt(centerOf("#tab-b")));
    await settled();

    assert.deepEqual(
      clicks,
      ["b"],
      "after the dwell, the dwelled tab is clicked once"
    );
  });

  test("a tab's edge third does not reveal (reserved for the strip's insert zone)", async function (assert) {
    const service = this.owner.lookup("service:wireframe-drag-dwell");
    const clicks = [];
    const record = (key) => clicks.push(key);

    // A wide button so the cursor can sit clearly in an outer third.
    await render(
      <template>
        <button
          id="tab-a"
          type="button"
          data-wf-tab-panel-key="a"
          style="width: 120px;"
          {{on "click" (fn record "a")}}
        >A</button>
      </template>
    );

    const r = document.querySelector("#tab-a").getBoundingClientRect();
    service.handleDragStart();
    // Cursor in the LEFT edge third — the insert system's territory.
    service.handleDrag(
      dragAt({ clientX: r.left + r.width * 0.1, clientY: r.top + r.height / 2 })
    );
    await settled();

    assert.deepEqual(clicks, [], "an edge-third hover does not reveal the tab");
  });

  test("a steady dwell reveals once, not every frame", async function (assert) {
    const service = this.owner.lookup("service:wireframe-drag-dwell");
    const clicks = [];
    const record = (key) => clicks.push(key);

    await render(
      <template>
        <button
          id="tab-a"
          type="button"
          data-wf-tab-panel-key="a"
          {{on "click" (fn record "a")}}
        >A</button>
      </template>
    );

    service.handleDragStart();
    service.handleDrag(dragAt(centerOf("#tab-a")));
    await settled();
    // Still resting on the same tab: must not reschedule and re-click.
    service.handleDrag(dragAt(centerOf("#tab-a")));
    await settled();

    assert.deepEqual(clicks, ["a"], "a continuous hover reveals only once");
  });

  test("sweeping off a tab before the dwell elapses reveals nothing", async function (assert) {
    const service = this.owner.lookup("service:wireframe-drag-dwell");
    const clicks = [];
    const record = (key) => clicks.push(key);

    await render(
      <template>
        <button
          id="tab-a"
          type="button"
          data-wf-tab-panel-key="a"
          {{on "click" (fn record "a")}}
        >A</button>
      </template>
    );

    service.handleDragStart();
    service.handleDrag(dragAt(centerOf("#tab-a")));
    // Cursor leaves every control before the dwell fires: cancels the timer.
    service.handleDrag(dragAt({ clientX: -50, clientY: -50 }));
    await settled();

    assert.deepEqual(clicks, [], "no reveal fires for a sweep across a tab");
  });

  test("dwelling a carousel dot scrolls its slide into view", async function (assert) {
    const service = this.owner.lookup("service:wireframe-drag-dwell");

    await render(
      <template>
        <div class="d-block-carousel" data-wf-carousel="true">
          <div class="d-block-carousel__viewport" data-wf-drop-container="true">
            <div class="slide" id="slide-0">0</div>
            <div class="slide" id="slide-1">1</div>
          </div>
          <button
            id="dot-1"
            type="button"
            data-wf-carousel-nav="true"
            data-wf-carousel-slide-index="1"
          ></button>
        </div>
      </template>
    );

    // Observe the reveal on the specific slide element (real smooth scroll
    // isn't observable in the qunit harness; the carousel reveal is otherwise
    // browser-verified).
    const scrolled = [];
    const slide = document.querySelector("#slide-1");
    slide.scrollIntoView = () => scrolled.push("slide-1");

    service.handleDragStart();
    service.handleDrag(dragAt(centerOf("#dot-1")));
    await settled();

    assert.deepEqual(
      scrolled,
      ["slide-1"],
      "the dot's slide is scrolled into view after the dwell"
    );
  });
});
