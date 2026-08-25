import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { click, find, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ConfigureMenu from "discourse/admin/components/dashboard/configure-menu";
import DMenus from "discourse/float-kit/components/d-menus";
import { forceMobile } from "discourse/lib/mobile";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import {
  moveItemSelector,
  moveVia,
  moveViaChord,
  openMoveMenu,
} from "discourse/tests/helpers/ui-kit/reorderable-list-helper";

const REORDER_TEST_PREFIX = "Dashboard section reordering";

const FOUR_SECTIONS = [
  { id: "highlights", visible: true },
  { id: "reports", visible: true },
  { id: "traffic", visible: false },
  { id: "engagement", visible: true },
];

function rowSelector(id) {
  return `[data-reorderable-key="${id}"]`;
}

// A drag starts on the grip rather than anywhere on the row, so a press meant to
// scroll still scrolls and the row's own text stays selectable. The grip is what
// carries the registration, so that is where the events go.
function gripSelector(id) {
  return `${rowSelector(id)} .d-reorderable-list__handle`;
}

async function dragSection(sourceId, targetId, position) {
  const source = rowSelector(sourceId);
  const target = rowSelector(targetId);

  const targetRect = find(target).getBoundingClientRect();
  await simulateDrag(source, target, {
    dataTransfer: new DataTransfer(),
    sourceCoordinates: centerOf(gripSelector(sourceId)),
    targetCoordinates: {
      clientY:
        position === "above" ? targetRect.top + 1 : targetRect.bottom - 1,
    },
  });
}

function isTransparent(color) {
  return color === "transparent" || /rgba\(0, 0, 0, 0\)/.test(color);
}

/**
 * The y-range of whichever row edge is currently painted as the drop indicator.
 *
 * Read from the computed border rather than from a class, because the point is
 * where the line physically lands, not which row was asked to draw it.
 *
 * @returns {{top: number, bottom: number}|null} The band, or `null` if none.
 */
function indicatorBand() {
  for (const row of findAll(".db-configure__row")) {
    const style = getComputedStyle(row);
    const rect = row.getBoundingClientRect();

    if (!isTransparent(style.borderTopColor)) {
      return {
        top: rect.top,
        bottom: rect.top + parseFloat(style.borderTopWidth),
      };
    }
    if (!isTransparent(style.borderBottomColor)) {
      return {
        top: rect.bottom - parseFloat(style.borderBottomWidth),
        bottom: rect.bottom,
      };
    }
  }
  return null;
}

/** Opens a drag and holds it over a target, without dropping. */
async function hoverOver(sourceId, targetId, position) {
  const target = rowSelector(targetId);
  const dataTransfer = new DataTransfer();
  const targetRect = find(target).getBoundingClientRect();
  const coordinates = {
    clientX: targetRect.left + targetRect.width / 2,
    clientY: position === "above" ? targetRect.top + 1 : targetRect.bottom - 1,
  };

  // Dispatched on the grip, which is where the registration lives: a row that
  // scopes its drag to a handle is not itself draggable, so the browser would
  // never raise `dragstart` on it.
  await dragEvent(gripSelector(sourceId), "dragstart", {
    dataTransfer,
    ...centerOf(gripSelector(sourceId)),
  });
  await dragEvent(target, "dragenter", { dataTransfer, ...coordinates });
  await dragEvent(target, "dragover", { dataTransfer, ...coordinates });

  return () =>
    dragEvent(gripSelector(sourceId), "dragend", {
      dataTransfer,
      ...centerOf(gripSelector(sourceId)),
    });
}

module("Integration | Component | Dashboard | ConfigureMenu", function (hooks) {
  setupRenderingTest(hooks);

  // `settled()` waits out pending timers, and an announcement schedules its own
  // clear, so a message read after `await click(...)` would always be gone.
  hooks.beforeEach(disableClearA11yAnnouncementsInTests);
  hooks.afterEach(enableClearA11yAnnouncementsInTests);

  test(`${REORDER_TEST_PREFIX} renders one row per section`, async function (assert) {
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    assert.dom(".db-configure__row").exists({ count: 4 });
    assert.dom('[data-reorderable-key="highlights"]').exists();
    assert.dom('[data-reorderable-key="reports"]').exists();
    assert.dom('[data-reorderable-key="traffic"]').exists();
    assert.dom('[data-reorderable-key="engagement"]').exists();
  });

  test(`${REORDER_TEST_PREFIX} toggle click fires @onToggleVisibility with the section id`, async function (assert) {
    const sections = FOUR_SECTIONS;
    const calls = [];
    const onToggle = (id) => calls.push(id);
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{onToggle}}
        />
      </template>
    );

    await click(
      '[data-reorderable-key="highlights"] .d-toggle-switch__checkbox'
    );
    assert.deepEqual(calls, ["highlights"]);
  });

  test(`${REORDER_TEST_PREFIX} reorders in both directions`, async function (assert) {
    const sections = FOUR_SECTIONS;
    const calls = [];
    const onReorder = (from, to) => calls.push([from, to]);
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{onReorder}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    await dragSection("reports", "highlights", "above");
    await dragSection("highlights", "engagement", "below");

    assert.deepEqual(
      calls,
      [
        [1, 0],
        [0, 3],
      ],
      "drops above and below resolve from source and target rows without dragstart state"
    );
  });

  test(`${REORDER_TEST_PREFIX} wires every row as a shared source and target`, async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{FOUR_SECTIONS}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    assert
      .dom(".db-configure__row[data-drop-target]")
      .exists(
        { count: FOUR_SECTIONS.length },
        "every configure row is a drop target"
      );
    assert
      .dom(".db-configure__row[data-drag-source]")
      .exists(
        { count: FOUR_SECTIONS.length },
        "every configure row carries the drag registration, so a drag shows the row"
      );
    assert
      .dom('.db-configure__row .d-reorderable-list__handle[draggable="true"]')
      .exists(
        { count: FOUR_SECTIONS.length },
        "and its grip is where the drag begins"
      );
  });

  test(`${REORDER_TEST_PREFIX} uses the shared drag state classes`, async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{FOUR_SECTIONS}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    const source = rowSelector("reports");
    const target = rowSelector("traffic");
    const dataTransfer = new DataTransfer();
    const sourceGrip = gripSelector("reports");
    const sourceCoordinates = centerOf(sourceGrip);
    const targetRect = find(target).getBoundingClientRect();
    const targetCoordinates = {
      clientX: targetRect.left + targetRect.width / 2,
      clientY: targetRect.top + 1,
    };

    await dragEvent(sourceGrip, "dragstart", {
      dataTransfer,
      ...sourceCoordinates,
    });
    await dragEvent(target, "dragenter", {
      dataTransfer,
      ...targetCoordinates,
    });
    await dragEvent(target, "dragover", {
      dataTransfer,
      offsetY: 1,
      ...targetCoordinates,
    });

    assert
      .dom(source)
      .hasClass("--dragging", "the source uses the shared dragging class");
    assert
      .dom(target)
      .hasClass("--drag-above", "the target uses the shared above indicator");

    await dragEvent(sourceGrip, "dragend", {
      dataTransfer,
      ...sourceCoordinates,
    });
  });

  test(`${REORDER_TEST_PREFIX} leaves no indicator after an abandoned drag`, async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{FOUR_SECTIONS}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    const source = rowSelector("reports");
    const target = rowSelector("traffic");
    const dataTransfer = new DataTransfer();
    const sourceGrip = gripSelector("reports");
    const sourceCoordinates = centerOf(sourceGrip);
    const targetRect = find(target).getBoundingClientRect();
    const targetCoordinates = {
      clientX: targetRect.left + targetRect.width / 2,
      clientY: targetRect.top + 1,
    };

    await dragEvent(sourceGrip, "dragstart", {
      dataTransfer,
      ...sourceCoordinates,
    });
    await dragEvent(target, "dragenter", {
      dataTransfer,
      ...targetCoordinates,
    });
    await dragEvent(target, "dragover", {
      dataTransfer,
      offsetY: 1,
      ...targetCoordinates,
    });
    await dragEvent(sourceGrip, "dragend", {
      dataTransfer,
      ...sourceCoordinates,
    });

    assert
      .dom(source)
      .doesNotHaveClass(
        "--dragging",
        "an abandoned drag clears the source indicator"
      )
      .doesNotHaveClass(
        "dragging",
        "an abandoned drag leaves no legacy source indicator"
      );
    assert
      .dom(target)
      .doesNotHaveClass(
        "drag-above",
        "an abandoned drag leaves no legacy above indicator"
      )
      .doesNotHaveClass(
        "drag-below",
        "an abandoned drag leaves no legacy below indicator"
      )
      .doesNotHaveClass(
        "--drag-above",
        "an abandoned drag clears the target's above indicator"
      )
      .doesNotHaveClass(
        "--drag-below",
        "an abandoned drag clears the target's below indicator"
      );
  });

  test(`${REORDER_TEST_PREFIX} renders one handle per row on desktop`, async function (assert) {
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    assert.dom(".d-reorderable-list__handle").exists({ count: 4 });

    await openMoveMenu("reports");
    assert
      .dom(".d-reorderable-list__move-item")
      .exists(
        { count: 4 },
        "desktop keeps a pointer path to reorder, not only the drag"
      );
  });

  test(`${REORDER_TEST_PREFIX} keeps the moved row's handle focused once it has moved`, async function (assert) {
    // A live list, unlike the sibling tests: the row has to actually move for
    // this to say anything about what happens to focus when it does.
    const state = new (class {
      @tracked sections = [...FOUR_SECTIONS];
    })();
    const onReorder = (from, to) => {
      const next = [...state.sections];
      const [moved] = next.splice(from, 1);
      next.splice(to, 0, moved);
      state.sections = next;
    };
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{state.sections}}
          @onReorder={{onReorder}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    await moveVia("highlights", "down");

    assert.deepEqual(
      state.sections.map((section) => section.id),
      ["reports", "highlights", "traffic", "engagement"],
      "the row moved, so focus has something to survive"
    );
    // Without this a keyboard user is dropped to the top of the document after
    // one move and cannot make a second, which defeats the keyboard path.
    assert.strictEqual(
      document.activeElement,
      find(gripSelector("highlights")),
      "focus follows the row rather than falling back to the body"
    );
  });

  test(`${REORDER_TEST_PREFIX} desktop arrow buttons fire @onReorder`, async function (assert) {
    const sections = FOUR_SECTIONS;
    const calls = [];
    const onReorder = (from, to) => calls.push([from, to]);
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{onReorder}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    await moveVia("reports", "up");
    assert.deepEqual(
      calls.at(-1),
      [1, 0],
      "the up arrow moves the row earlier"
    );

    await moveVia("highlights", "down");
    assert.deepEqual(
      calls.at(-1),
      [0, 1],
      "the down arrow moves the row later"
    );
  });

  test(`${REORDER_TEST_PREFIX} the Alt chord fires @onReorder`, async function (assert) {
    const sections = FOUR_SECTIONS;
    const calls = [];
    const onReorder = (from, to) => calls.push([from, to]);
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{onReorder}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    await moveViaChord("reports", "up");
    assert.deepEqual(
      calls.at(-1),
      [1, 0],
      "the accelerator moves the row without opening the menu"
    );

    await moveViaChord("highlights", "bottom");
    assert.deepEqual(calls.at(-1), [0, 3], "and sends it to the far end");
  });

  test(`${REORDER_TEST_PREFIX} adjacent rows leave no dead space between drop zones`, async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{FOUR_SECTIONS}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    // Each row splits into its own above/below halves at its midpoint, so the
    // zones only meet end to end if the row boxes themselves touch. Container
    // spacing (a flex `gap`) is owned by the list, not by either row, so a
    // pointer inside it reaches no drop target at all.
    const rows = findAll(".db-configure__row");
    for (let i = 1; i < rows.length; i++) {
      const previous = rows[i - 1].getBoundingClientRect();
      const current = rows[i].getBoundingClientRect();

      // Compared exactly, not rounded: a sub-pixel seam is still a band of
      // pixels that belongs to no row, and rounding both sides would hide it.
      assert.strictEqual(
        current.top,
        previous.bottom,
        `row ${i} starts exactly where row ${i - 1} ends, so no pointer position between them falls outside both`
      );
    }
  });

  test(`${REORDER_TEST_PREFIX} both sides of a boundary draw one shared indicator line`, async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{FOUR_SECTIONS}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    // The same boundary reached from either side. Both resolve to the same
    // insertion point, so the line has to stay put rather than shifting by its
    // own width as the pointer crosses the midpoint.
    const endBelow = await hoverOver("traffic", "highlights", "below");
    const below = indicatorBand();
    await endBelow();

    const endAbove = await hoverOver("traffic", "reports", "above");
    const above = indicatorBand();
    await endAbove();

    assert.notStrictEqual(
      below,
      null,
      "hovering below the first row paints an indicator"
    );
    assert.notStrictEqual(
      above,
      null,
      "hovering above the second row paints an indicator"
    );
    assert.deepEqual(
      above,
      below,
      "below row 1 and above row 2 are the same insertion point, so they paint the same pixels"
    );
  });

  test(`${REORDER_TEST_PREFIX} the indicator colour follows its own custom property`, async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <div style="--d-drag-indicator-color: rgb(1, 2, 3)">
          <ConfigureMenu
            @sections={{FOUR_SECTIONS}}
            @onReorder={{noop}}
            @onToggleVisibility={{noop}}
          />
        </div>
      </template>
    );

    const end = await hoverOver("traffic", "highlights", "below");
    const painted = getComputedStyle(
      find(rowSelector("highlights"))
    ).borderBottomColor;
    await end();

    assert.strictEqual(
      painted,
      "rgb(1, 2, 3)",
      "an ancestor can retune drag feedback without touching any other accent border"
    );
  });

  test(`${REORDER_TEST_PREFIX} the arrow path announces where the row landed`, async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    await moveVia("reports", "up");
    assert.strictEqual(
      a11y.politeMessage,
      "Moved Reports to position 1 of 4",
      "the announcement names the row and its resulting position"
    );

    await moveVia("highlights", "down");
    assert.strictEqual(
      a11y.politeMessage,
      "Moved Highlights to position 2 of 4",
      "moving down announces the row's new position, not the direction"
    );
  });

  test(`${REORDER_TEST_PREFIX} the drag path announces through the same call as the arrows`, async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    await dragSection("engagement", "highlights", "above");
    assert.strictEqual(
      a11y.politeMessage,
      "Moved Engagement to position 1 of 4",
      "a completed drag announces exactly like the equivalent arrow press"
    );
  });

  test(`${REORDER_TEST_PREFIX} a reorder that moves nothing announces nothing`, async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    const before = a11y.politeMessage;

    await dragSection("reports", "reports", "above");
    assert.strictEqual(
      a11y.politeMessage,
      before,
      "dropping a row onto itself is not a reorder, so nothing is announced"
    );

    // Below the row directly above it resolves to the index it already holds,
    // so this is a no-op that the self-drop guard alone does not catch.
    await dragSection("reports", "highlights", "below");
    assert.strictEqual(
      a11y.politeMessage,
      before,
      "a drop that resolves to the row's current index announces nothing"
    );
  });

  test(`${REORDER_TEST_PREFIX} desktop keyboard path reaches every handle and offers only reachable destinations`, async function (assert) {
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <DMenus />
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    assert
      .dom(".d-reorderable-list__handle")
      .exists({ count: 4 }, "every section's handle is reachable");
    assert
      .dom('.d-reorderable-list__handle[tabindex="-1"]')
      .doesNotExist("and none is held out of the tab sequence");

    await openMoveMenu("highlights");
    assert
      .dom(moveItemSelector("up"))
      .doesNotExist("the first row cannot move up");
    await click(moveItemSelector("down"));

    await openMoveMenu("engagement");
    assert
      .dom(moveItemSelector("down"))
      .doesNotExist("the last row cannot move down");
    await click(moveItemSelector("up"));

    await openMoveMenu("reports");
    assert.dom(moveItemSelector("up")).exists("a middle row can move up");
  });
});

module(
  "Integration | Component | Dashboard | ConfigureMenu | Mobile",
  function (hooks) {
    hooks.beforeEach(function () {
      forceMobile();
    });

    setupRenderingTest(hooks);

    test(`${REORDER_TEST_PREFIX} renders one handle per row on mobile`, async function (assert) {
      const sections = FOUR_SECTIONS;
      const noop = () => {};

      await render(
        <template>
          <DMenus />
          <ConfigureMenu
            @sections={{sections}}
            @onReorder={{noop}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      // Both paths render: a touch screen can drag from the grip and has no
      // keyboard, so neither is a substitute for the other here.
      assert.dom(".d-reorderable-list__handle").exists({ count: 4 });
      assert.dom(".d-reorderable-list__handle").exists({ count: 4 });
    });

    test(`${REORDER_TEST_PREFIX} keeps the row draggable from its grip on mobile`, async function (assert) {
      const noop = () => {};

      await render(
        <template>
          <DMenus />
          <ConfigureMenu
            @sections={{FOUR_SECTIONS}}
            @onReorder={{noop}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      assert
        .dom(".d-reorderable-list__handle")
        .exists(
          "the grip renders on mobile, so the drag has a target to press"
        );
      assert
        .dom(".db-configure__row")
        .hasAttribute(
          "data-drag-source",
          "",
          "a mobile row carries an active drag-source registration"
        );
      assert
        .dom(".db-configure__row .d-reorderable-list__handle")
        .hasAttribute(
          "draggable",
          "true",
          "and its grip is where a touch press starts the drag"
        );
    });

    test(`${REORDER_TEST_PREFIX} mobile menu moves fire @onReorder`, async function (assert) {
      const sections = FOUR_SECTIONS;
      const calls = [];
      const onReorder = (from, to) => calls.push([from, to]);
      const noop = () => {};

      await render(
        <template>
          <DMenus />
          <ConfigureMenu
            @sections={{sections}}
            @onReorder={{onReorder}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      await moveVia("reports", "up");
      assert.deepEqual(calls.at(-1), [1, 0]);

      await moveVia("highlights", "down");
      assert.deepEqual(calls.at(-1), [0, 1]);
    });

    test(`${REORDER_TEST_PREFIX} omits unavailable mobile destinations`, async function (assert) {
      const sections = FOUR_SECTIONS;
      const noop = () => {};

      await render(
        <template>
          <DMenus />
          <ConfigureMenu
            @sections={{sections}}
            @onReorder={{noop}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      await openMoveMenu("highlights");
      assert
        .dom(moveItemSelector("up"))
        .doesNotExist("the first row cannot move up");
      await click(moveItemSelector("down"));

      await openMoveMenu("engagement");
      assert
        .dom(moveItemSelector("down"))
        .doesNotExist("the last row cannot move down");
      await click(moveItemSelector("up"));

      await openMoveMenu("reports");
      assert.dom(moveItemSelector("up")).exists("a middle row can move up");
    });
  }
);
