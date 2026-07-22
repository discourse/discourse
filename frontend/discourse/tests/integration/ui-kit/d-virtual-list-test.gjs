import { tracked } from "@glimmer/tracking";
import { render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const estimate = () => 40;

module("Integration | ui-kit | DVirtualList", function (hooks) {
  setupRenderingTest(hooks);

  // A rendering container has no real scroll height, so exercise the render-all
  // fallback. Windowing-with-geometry is covered by the windowing module below.
  hooks.beforeEach(function () {
    disableVirtualization();
  });

  hooks.afterEach(function () {
    enableVirtualization();
  });

  test("renders each item and wraps it in a measured row", async function (assert) {
    const items = [
      { id: 1, text: "one" },
      { id: 2, text: "two" },
      { id: 3, text: "three" },
    ];

    await render(
      <template>
        <DVirtualList @items={{items}} @estimateSize={{estimate}} as |item|>
          <span class="row">{{item.text}}</span>
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list__item")
      .exists({ count: 3 }, "renders every item");
    assert.dom(".row").exists({ count: 3 });
    assert.dom(".d-virtual-list__item:last-child .row").hasText("three");
  });

  test("emits no ARIA position attributes without a row role", async function (assert) {
    // aria-setsize/posinset are undefined on a bare div, so AT discards them.
    // Emitting them unconditionally is noise, not accessibility.
    const items = [{ id: 1, text: "one" }];

    await render(
      <template>
        <DVirtualList @items={{items}} @estimateSize={{estimate}} as |item|>
          <span class="row">{{item.text}}</span>
        </DVirtualList>
      </template>
    );

    assert.dom(".d-virtual-list").doesNotHaveAttribute("role");
    assert.dom(".d-virtual-list__item").doesNotHaveAttribute("role");
    assert.dom(".d-virtual-list__item").doesNotHaveAttribute("aria-setsize");
    assert.dom(".d-virtual-list__item").doesNotHaveAttribute("aria-posinset");
  });

  test("threads listbox roles through with a true set size", async function (assert) {
    // The listbox shape a select consumer needs. @role lands on the inner sizer
    // container (the semantic element), and wrapped rows carry role=option as its
    // direct children — no intervening presentation wrappers to break the required
    // listbox->option ownership. The outer .d-virtual-list viewport stays role-less.
    const items = [
      { id: 1, text: "one" },
      { id: 2, text: "two" },
      { id: 3, text: "three" },
    ];

    await render(
      <template>
        <DVirtualList
          @items={{items}}
          @estimateSize={{estimate}}
          @role="listbox"
          @itemRole="option"
          as |item|
        >
          <span class="row">{{item.text}}</span>
        </DVirtualList>
      </template>
    );

    assert.dom(".d-virtual-list").doesNotHaveAttribute("role");
    assert
      .dom(".d-virtual-list__sizer")
      .hasAttribute("role", "listbox", "the inner container is the listbox");
    assert
      .dom(".d-virtual-list__item:first-child")
      .hasAttribute("role", "option");
    assert
      .dom(".d-virtual-list__item:first-child")
      .hasAttribute("aria-posinset", "1", "position is absolute, not windowed");
    assert
      .dom(".d-virtual-list__item:first-child")
      .hasAttribute("aria-setsize", "3", "set size is the true total");
  });

  test("yields the empty block when there are no items", async function (assert) {
    const items = [];

    await render(
      <template>
        <DVirtualList @items={{items}} @estimateSize={{estimate}}>
          <:default as |item|><span>{{item.text}}</span></:default>
          <:empty><span class="empty">Nothing here</span></:empty>
        </DVirtualList>
      </template>
    );

    assert.dom(".empty").hasText("Nothing here");
    assert.dom(".d-virtual-list__item").doesNotExist();
  });
});

const ROW_PX = 40;

// Consumers hand DVirtualList a new array reference on change; this is the
// smallest tracked holder that lets a test do the same.
class State {
  @tracked value;

  constructor(value) {
    this.value = value;
  }
}

function buildRows(count) {
  return Array.from({ length: count }, (_, i) => ({ id: i, text: `row ${i}` }));
}

function scroller() {
  return document.querySelector(".d-virtual-list");
}

// Setting scrollTop dispatches `scroll` asynchronously, and the bridge modifier
// then schedules an afterRender flush. triggerEvent fires the event and awaits
// settled(), collapsing both hops deterministically.
async function scrollTo(top) {
  const el = scroller();
  el.scrollTop = top;
  await triggerEvent(el, "scroll");
}

module("Integration | ui-kit | DVirtualList | windowing", function (hooks) {
  setupRenderingTest(hooks);

  // Inverts the suite default: these tests need the real engine driving a real
  // scroll container. Geometry is genuine (headless Chrome), not stubbed — the
  // 0.5 scale on #ember-testing does not distort offsetHeight/borderBoxSize,
  // which is all virtual-core reads. The scroll viewport is the outer
  // .d-virtual-list; it is sized via CSS, not `...attributes` (which route to the
  // inner container).
  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("renders only a window of a large list", async function (assert) {
    const items = buildRows(1000);

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>
        <DVirtualList @items={{items}} @estimateSize={{estimate}} as |item|>
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    const rendered = document.querySelectorAll(".d-virtual-list__item").length;

    assert.true(rendered > 0, "renders some rows");
    assert.true(
      rendered < 40,
      `windows a small slice of 1000 rows (rendered ${rendered})`
    );
    assert
      .dom(".d-virtual-list__sizer")
      .hasStyle(
        { height: `${ROW_PX * 1000}px` },
        "the sizer spans the full list so the scrollbar is honest"
      );
    assert
      .dom(".d-virtual-list__item:first-child")
      .hasAttribute("data-index", "0", "window starts at the first row");
  });

  test("owned rows are stamped with data-index for measurement", async function (assert) {
    // virtual-core's measureElement identifies a row by its data-index, so an owned
    // consumer that applies {{row.place}}/{{row.measure}} but does NOT set data-index
    // itself must still get it — otherwise every row measures at index -1 and shares
    // one bogus cache key. The modifiers stamp it; this pins that.
    const items = buildRows(1000);

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>

        <DVirtualList
          @items={{items}}
          @estimateSize={{estimate}}
          @as="ul"
          @role="listbox"
          @ownedRow={{true}}
          as |item row|
        >
          {{! deliberately NO data-index attribute — the modifiers must supply it.
              The listbox role is on the dElement-rendered container, which the
              linter can't see through, so the option-in-listbox rule is disabled. }}
          {{! eslint-disable ember/template-require-context-role }}
          <li
            class="row"
            role="option"
            style="height: 40px"
            {{row.place row.start row.index}}
            {{row.measure}}
          >
            {{item.text}}
          </li>
        </DVirtualList>
      </template>
    );

    const owned = [...document.querySelectorAll(".row")];
    assert.true(owned.length > 0, "mounts a window of owned rows");
    assert.true(
      owned.every((el) => el.hasAttribute("data-index")),
      "every owned row is stamped with data-index"
    );
    assert
      .dom(".row")
      .hasAttribute("data-index", "0", "first owned row is index 0");
  });

  test("scrolling advances the window and unmounts rows above it", async function (assert) {
    const items = buildRows(1000);

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>
        <DVirtualList @items={{items}} @estimateSize={{estimate}} as |item|>
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(ROW_PX * 500);

    assert
      .dom(".d-virtual-list__item[data-index='0']")
      .doesNotExist("the first row is unmounted once scrolled away");

    const first = document.querySelector(".d-virtual-list__item");
    const firstIndex = Number(first.getAttribute("data-index"));

    assert.true(
      firstIndex > 480,
      `window advanced with the scroll (first mounted index ${firstIndex})`
    );
    assert.true(
      firstIndex <= 500,
      `window did not overshoot the scroll position (first mounted index ${firstIndex})`
    );
  });

  test("re-syncing options with unchanged geometry does not republish state", async function (assert) {
    // Guards the equality signature gate in d-virtualizer's #flush. Without it,
    // getVirtualItems() returning a fresh array each call plus unconditional
    // @tracked invalidation is itself a render loop.
    //
    // This must force a real modify() -> setOptions -> scheduled flush. Merely
    // awaiting settled() after render proves nothing: render has already settled,
    // so no engine callback fires and the assertion holds even with the gate removed.
    const items = buildRows(200);
    const state = new State(() => 40);
    let ranges = 0;
    const onVisibleRangeChange = () => ranges++;

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>
        <DVirtualList
          @items={{items}}
          @estimateSize={{state.value}}
          @onVisibleRangeChange={{onVisibleRangeChange}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    const baseline = ranges;

    // A fresh function identity re-runs modify() and busts the engine's
    // measurement memo, but every size is identical, so the published window is
    // byte-for-byte the same and the gate must swallow it.
    state.value = () => 40;
    await settled();

    assert.strictEqual(
      ranges,
      baseline,
      "an options re-sync that changes no geometry publishes nothing"
    );
  });

  test("prepending preserves the viewport position on a top-resting list", async function (assert) {
    // Cursor-paginated sources have no total, so loading older content means
    // genuinely inserting above the viewport. Without anchoring, every row the
    // user is reading jumps down by the height of whatever arrived.
    //
    // The engine anchors by key across a count change, but gates that on
    // anchorTo:"end" — which does NOT control resting position (it is consulted
    // only at the prepend-anchor gate and the wasAtEnd resize branch), so a
    // top-resting list can opt in without becoming bottom-anchored.
    const state = new State(buildRows(200));

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>
        <DVirtualList
          @items={{state.value}}
          @estimateSize={{estimate}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(ROW_PX * 50);

    // Identify the row actually being read, and where it sits on screen.
    // Asserting only that scrollTop moved by the prepended height proves
    // arithmetic, not preservation: a broken key-to-item mapping could satisfy
    // the number while swapping the content under the reader.
    const anchorRow = document.querySelector(".d-virtual-list__item");
    const anchorText = anchorRow.querySelector(".row").textContent.trim();
    const anchorTop = anchorRow.getBoundingClientRect().top;

    const older = Array.from({ length: 100 }, (_, i) => ({
      id: -100 + i,
      text: `older ${i}`,
    }));
    state.value = [...older, ...state.value];
    await settled();

    const movedRow = [
      ...document.querySelectorAll(".d-virtual-list__item"),
    ].find((el) => el.querySelector(".row")?.textContent.trim() === anchorText);

    assert.strictEqual(
      movedRow?.textContent.trim(),
      anchorText,
      "the row being read is still rendered after the prepend"
    );
    assert.strictEqual(
      Math.round(movedRow.getBoundingClientRect().top),
      Math.round(anchorTop),
      "it holds its exact viewport position"
    );
  });

  test("replacing an interior item republishes its key", async function (assert) {
    // The flush signature hashes totalSize + range + the FIRST and LAST keys only.
    // Swapping an item strictly inside the window leaves all four identical, so the
    // freshly computed window is discarded and the component keeps pairing stale
    // virtual keys with current items[index] — keyed row state then belongs to the
    // wrong object.
    const state = new State(buildRows(1000));

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>
        <DVirtualList
          @items={{state.value}}
          @estimateSize={{estimate}}
          as |item row|
        >
          <div class="row" style="height: 40px" data-key={{row.key}}>
            {{item.text}}
          </div>
        </DVirtualList>
      </template>
    );

    const keyBefore = document
      .querySelector(".d-virtual-list__item[data-index='5'] .row")
      .getAttribute("data-key");

    const next = state.value.slice();
    next[5] = { id: 5, text: "replaced" };
    state.value = next;
    await settled();

    const keyAfter = document
      .querySelector(".d-virtual-list__item[data-index='5'] .row")
      .getAttribute("data-key");

    assert.notStrictEqual(
      keyAfter,
      keyBefore,
      "a new object at an interior index publishes a new virtual key"
    );
  });
});
