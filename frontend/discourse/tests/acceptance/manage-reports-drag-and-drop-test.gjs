import { getOwner } from "@ember/owner";
import { fillIn, find, findAll, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import ManageReports from "discourse/admin/components/modal/manage-reports";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import {
  moveVia,
  openMoveMenu,
} from "discourse/tests/helpers/ui-kit/reorderable-list-helper";

const REORDER_TEST_PREFIX = "Manage reports reordering";

const REPORTS = [
  {
    source: "core_report",
    identifier: "signups",
    key: "core_report:signups",
    title: "Matching signups",
    description: "New account signups",
  },
  {
    source: "core_report",
    identifier: "topics",
    key: "core_report:topics",
    title: "Matching topics",
    description: "New topics",
  },
  {
    source: "core_report",
    identifier: "posts",
    key: "core_report:posts",
    title: "Other posts",
    description: "New posts",
  },
];

function rowSelector(key) {
  return `.manage-reports__row[data-reorderable-key="${key}"]`;
}

// A drag starts on the grip rather than anywhere on the row, so a press meant to
// scroll still scrolls. The row owns the source data, while the shared helper
// dispatches the browser events on the grip carrying the draggable registration.
function gripSelector(key) {
  return `${rowSelector(key)} .d-reorderable-list__handle`;
}

function enabledKeys() {
  return findAll(".manage-reports__row.--enabled").map(
    (row) => row.dataset.reorderableKey
  );
}

async function openModal(context) {
  await visit("/");
  getOwner(context).lookup("service:modal").show(ManageReports);
  await settled();
}

async function dragReport(sourceKey, targetKey, position) {
  const source = rowSelector(sourceKey);
  const target = rowSelector(targetKey);

  const targetRect = find(target).getBoundingClientRect();
  await simulateDrag(source, target, {
    dataTransfer: new DataTransfer(),
    sourceCoordinates: centerOf(gripSelector(sourceKey)),
    targetCoordinates: {
      clientY:
        position === "above" ? targetRect.top + 1 : targetRect.bottom - 1,
    },
  });
}

acceptance("Manage reports drag and drop", function (needs) {
  needs.user({ admin: true });
  needs.pretender((server, helper) => {
    server.get("/admin/dashboard/reports/available.json", () =>
      helper.response({
        enabled: REPORTS.slice(0, 2),
        available: REPORTS,
        providers: [],
        cursor: null,
        has_more: false,
      })
    );
  });

  // `settled()` waits out pending timers, and an announcement schedules its own
  // clear, so a message read after an awaited interaction would always be gone.
  needs.hooks.beforeEach(disableClearA11yAnnouncementsInTests);
  needs.hooks.afterEach(enableClearA11yAnnouncementsInTests);

  test(`${REORDER_TEST_PREFIX} adjacent rows leave no dead space between drop zones`, async function (assert) {
    await openModal(this);

    // Container spacing (a flex `gap`) belongs to the list, not to either row,
    // so a pointer inside it reaches no drop target and the above/below zones
    // stop meeting.
    const rows = findAll(".manage-reports__row");
    for (let i = 1; i < rows.length; i++) {
      const previous = rows[i - 1].getBoundingClientRect();
      const current = rows[i].getBoundingClientRect();

      assert.strictEqual(
        Math.round(current.top),
        Math.round(previous.bottom),
        `row ${i} starts exactly where row ${i - 1} ends, so no pointer position between them falls outside both`
      );
    }
  });

  test(`${REORDER_TEST_PREFIX} renders the grip alongside the arrows on desktop`, async function (assert) {
    await openModal(this);

    assert.dom(".d-reorderable-list__handle").exists({ count: 2 });
    await openMoveMenu("core_report:topics");
    assert
      .dom(".d-reorderable-list__move-item")
      .exists(
        { count: 4 },
        "desktop keeps a pointer path to reorder, not only the drag"
      );
  });

  test(`${REORDER_TEST_PREFIX} desktop arrow buttons reorder the enabled list`, async function (assert) {
    await openModal(this);

    await moveVia("core_report:topics", "up");

    assert.deepEqual(
      enabledKeys(),
      ["core_report:topics", "core_report:signups"],
      "the up arrow moves the report earlier on desktop, with no pointer involved"
    );
  });

  test(`${REORDER_TEST_PREFIX} the arrow path announces through the same call as the drag`, async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    await openModal(this);

    await moveVia("core_report:topics", "up");

    assert.strictEqual(
      a11y.politeMessage,
      "Moved Matching topics to position 1 of 3",
      "an arrow press announces exactly like the equivalent drag, counting the disabled row the reader can also see"
    );
  });

  test(`${REORDER_TEST_PREFIX} announces where a dragged report landed`, async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    await openModal(this);

    await dragReport("core_report:topics", "core_report:signups", "above");

    assert.strictEqual(
      a11y.politeMessage,
      "Moved Matching topics to position 1 of 3",
      "a completed drag announces the report and its resulting position"
    );
  });

  test(`${REORDER_TEST_PREFIX} announces nothing when a drop changes no order`, async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    await openModal(this);

    const before = a11y.politeMessage;

    await dragReport("core_report:signups", "core_report:signups", "above");
    assert.strictEqual(
      a11y.politeMessage,
      before,
      "dropping a report onto itself is not a reorder, so nothing is announced"
    );

    // Below the report directly above it resolves to the index it already holds.
    await dragReport("core_report:topics", "core_report:signups", "below");
    assert.strictEqual(
      a11y.politeMessage,
      before,
      "a drop that resolves to the report's current index announces nothing"
    );
  });

  test(`${REORDER_TEST_PREFIX} reorders by stable key with a search filter applied`, async function (assert) {
    await openModal(this);
    await fillIn(".manage-reports__search-wrapper .filter-input", "Matching");

    await dragReport("core_report:topics", "core_report:signups", "above");

    assert.deepEqual(
      enabledKeys(),
      ["core_report:topics", "core_report:signups"],
      "a filtered reorder resolves fresh visible-row copies through their stable keys"
    );
  });

  test(`${REORDER_TEST_PREFIX} conditionally registers rows and puts the grab cursor on the grip`, async function (assert) {
    await openModal(this);

    const disabledRow = rowSelector("core_report:posts");
    assert
      .dom(disabledRow)
      .doesNotHaveAttribute(
        "data-drag-source",
        "a disabled row has no active drag-source registration"
      )
      .doesNotHaveAttribute(
        "draggable",
        "a disabled row is not stamped as draggable"
      );
    // The grip is what a drag begins on, so it is what advertises the grab. The
    // row must not: its text is selectable, and a `grab` cursor over text would
    // promise a gesture pressing there does not perform.
    assert.strictEqual(
      getComputedStyle(find(rowSelector("core_report:signups"))).cursor,
      "auto",
      "an enabled row does not claim the grab cursor across its whole width"
    );
    // Paired with the row above, because `auto` is what an unstyled element
    // reports anyway: on its own that assertion passes even if no rule is
    // reached at all.
    assert.strictEqual(
      getComputedStyle(find(gripSelector("core_report:signups"))).cursor,
      "grab",
      "the grip does, so the rule is reached"
    );

    assert
      .dom(".manage-reports__row.--enabled[data-drop-target]")
      .exists({ count: 2 }, "every enabled reorderable row is a drop target");
    assert
      .dom(".manage-reports__row.--enabled[data-drag-source]")
      .exists(
        { count: 2 },
        "every enabled row carries the drag registration, so a drag shows the row"
      );
    assert
      .dom(
        '.manage-reports__row.--enabled .d-reorderable-list__handle[draggable="true"]'
      )
      .exists({ count: 2 }, "and its grip is where the drag begins");
  });

  test(`${REORDER_TEST_PREFIX} uses the shared drag state classes`, async function (assert) {
    await openModal(this);

    const source = rowSelector("core_report:signups");
    const target = rowSelector("core_report:topics");
    const dataTransfer = new DataTransfer();
    const sourceGrip = gripSelector("core_report:signups");
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
    await openModal(this);

    const source = rowSelector("core_report:signups");
    const target = rowSelector("core_report:topics");
    const dataTransfer = new DataTransfer();
    const sourceGrip = gripSelector("core_report:signups");
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
});

acceptance(
  "Manage reports arrow reorder with a hidden row between matches",
  function (needs) {
    needs.user({ admin: true });
    needs.pretender((server, helper) =>
      server.get("/admin/dashboard/reports/available.json", () =>
        helper.response({
          // Order matters: the row the filter hides sits BETWEEN the two it
          // shows, which is the arrangement that separates moving by displayed
          // position from moving by stored position.
          enabled: [REPORTS[0], REPORTS[2], REPORTS[1]],
          available: REPORTS,
          providers: [],
          cursor: null,
          has_more: false,
        })
      )
    );

    needs.hooks.beforeEach(disableClearA11yAnnouncementsInTests);
    needs.hooks.afterEach(enableClearA11yAnnouncementsInTests);

    test(`${REORDER_TEST_PREFIX} moves a row past its visible neighbour with an arrow`, async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      await openModal(this);
      await fillIn(".manage-reports__search-wrapper .filter-input", "Matching");

      assert.deepEqual(
        enabledKeys(),
        ["core_report:signups", "core_report:topics"],
        "the filter shows the two matching rows, with one hidden between them"
      );

      await moveVia("core_report:signups", "down");

      assert.deepEqual(
        enabledKeys(),
        ["core_report:topics", "core_report:signups"],
        "the row moves past its visible neighbour, so the list the user sees actually changes"
      );
      assert.strictEqual(
        a11y.politeMessage,
        "Moved Matching signups to position 2 of 2",
        "and the announced position counts the rows on screen, not the stored order"
      );
    });

    test(`${REORDER_TEST_PREFIX} drag announces the same displayed position as an arrow`, async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      await openModal(this);
      await fillIn(".manage-reports__search-wrapper .filter-input", "Matching");

      await dragReport("core_report:signups", "core_report:topics", "below");

      assert.deepEqual(
        enabledKeys(),
        ["core_report:topics", "core_report:signups"],
        "the drag reaches the same order the arrow did"
      );
      // The stored order is three long and the row lands third in it, so an
      // announcement counted there would say "3 of 3" for a list showing two.
      assert.strictEqual(
        a11y.politeMessage,
        "Moved Matching signups to position 2 of 2",
        "so it announces the same position, counted on screen rather than in the stored order"
      );
    });

    test(`${REORDER_TEST_PREFIX} filtered drag leaves the hidden row in its slot`, async function (assert) {
      await openModal(this);
      await fillIn(".manage-reports__search-wrapper .filter-input", "Matching");

      await dragReport("core_report:signups", "core_report:topics", "below");

      await fillIn(".manage-reports__search-wrapper .filter-input", "");

      assert.deepEqual(
        enabledKeys(),
        ["core_report:topics", "core_report:posts", "core_report:signups"],
        "the two rows on screen swap the slots they held, and the row between them keeps its own"
      );
    });

    test(`${REORDER_TEST_PREFIX} arrow leaves the hidden row in the same slot as drag`, async function (assert) {
      await openModal(this);
      await fillIn(".manage-reports__search-wrapper .filter-input", "Matching");

      await moveVia("core_report:signups", "down");

      await fillIn(".manage-reports__search-wrapper .filter-input", "");

      assert.deepEqual(
        enabledKeys(),
        ["core_report:topics", "core_report:posts", "core_report:signups"],
        "so the two ways of reordering persist the same order rather than disagreeing about the hidden row"
      );
    });

    test(`${REORDER_TEST_PREFIX} no-op filtered drag changes nothing`, async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      await openModal(this);
      await fillIn(".manage-reports__search-wrapper .filter-input", "Matching");

      const before = a11y.politeMessage;

      // Below the row shown above it, which is the position it already holds.
      // In the stored order it is a move, because of the row hidden between.
      await dragReport("core_report:topics", "core_report:signups", "below");

      assert.strictEqual(
        a11y.politeMessage,
        before,
        "a drop onto the position the row already occupies announces nothing"
      );

      await fillIn(".manage-reports__search-wrapper .filter-input", "");

      assert.deepEqual(
        enabledKeys(),
        ["core_report:signups", "core_report:posts", "core_report:topics"],
        "and stores nothing, rather than quietly moving the row the user cannot see"
      );
    });
  }
);
