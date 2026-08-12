import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  find,
  findAll,
  settled,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import ManageReports from "discourse/admin/components/modal/manage-reports";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  assertDragRegistered,
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";

const ORACLE = "Manage reports DnD oracle";

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
  return `.manage-reports__row[data-identifier="${key}"]`;
}

// A drag starts on the grip rather than anywhere on the row, so a press meant to
// scroll still scrolls. The events still go to the row, which is the registered
// source; only the coordinates have to land on the grip.
function gripSelector(key) {
  return `${rowSelector(key)} .manage-reports__grip`;
}

function enabledKeys() {
  return findAll(".manage-reports__row.--enabled").map(
    (row) => row.dataset.identifier
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

  assertDragRegistered(source, target);

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

  test(`${ORACLE} adjacent rows leave no dead space between drop zones`, async function (assert) {
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

  test("desktop renders the grip alongside the arrows", async function (assert) {
    await openModal(this);

    assert.dom(".manage-reports__grip").exists({ count: 3 });
    assert
      .dom(".d-reorder-buttons__button")
      .exists(
        { count: 6 },
        "desktop keeps a keyboard path to reorder, not only the pointer drag"
      );
  });

  test("desktop arrow buttons reorder the enabled list", async function (assert) {
    await openModal(this);

    await click(
      `${rowSelector("core_report:topics")} .d-reorder-buttons__button:first-child`
    );

    assert.deepEqual(
      enabledKeys(),
      ["core_report:topics", "core_report:signups"],
      "the up arrow moves the report earlier on desktop, with no pointer involved"
    );
  });

  test(`${ORACLE} the arrow path announces through the same call as the drag`, async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    await openModal(this);

    await click(
      `${rowSelector("core_report:topics")} .d-reorder-buttons__button:first-child`
    );

    assert.strictEqual(
      a11y.politeMessage,
      "Moved Matching topics to position 1 of 2",
      "an arrow press announces exactly like the equivalent drag"
    );
  });

  test(`${ORACLE} announces where a dragged report landed`, async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    await openModal(this);

    await dragReport("core_report:topics", "core_report:signups", "above");

    assert.strictEqual(
      a11y.politeMessage,
      "Moved Matching topics to position 1 of 2",
      "a completed drag announces the report and its resulting position"
    );
  });

  test(`${ORACLE} announces nothing when a drop changes no order`, async function (assert) {
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

  test(`${ORACLE} reorders by stable key with a search filter applied`, async function (assert) {
    await openModal(this);
    await fillIn(".manage-reports__search-wrapper .filter-input", "Matching");

    await dragReport("core_report:topics", "core_report:signups", "above");

    assert.deepEqual(
      enabledKeys(),
      ["core_report:topics", "core_report:signups"],
      "a filtered reorder resolves fresh visible-row copies through their stable keys"
    );
  });

  test(`${ORACLE} conditionally registers rows and leaves disabled rows without a grab cursor`, async function (assert) {
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
    // Paired with the enabled row below, because `auto` is what an unstyled
    // element reports anyway: on its own this passes even if the rule never
    // matches anything.
    assert.strictEqual(
      getComputedStyle(find(disabledRow)).cursor,
      "auto",
      "a disabled row does not receive the grab cursor"
    );
    assert.strictEqual(
      getComputedStyle(find(rowSelector("core_report:signups"))).cursor,
      "grab",
      "an enabled row does receive it, so the rule is reached"
    );

    assert
      .dom(".manage-reports__row.--enabled[data-drag-source][data-drop-target]")
      .exists(
        { count: 2 },
        "every enabled reorderable row is both a shared source and target"
      );
  });

  test(`${ORACLE} uses the shared drag state classes`, async function (assert) {
    await openModal(this);

    const source = rowSelector("core_report:signups");
    const target = rowSelector("core_report:topics");
    const dataTransfer = new DataTransfer();
    const sourceCoordinates = centerOf(gripSelector("core_report:signups"));
    const targetRect = find(target).getBoundingClientRect();
    const targetCoordinates = {
      clientX: targetRect.left + targetRect.width / 2,
      clientY: targetRect.top + 1,
    };

    await dragEvent(source, "dragstart", {
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

    await dragEvent(source, "dragend", {
      dataTransfer,
      ...sourceCoordinates,
    });
  });

  test(`${ORACLE} leaves no indicator after an abandoned drag`, async function (assert) {
    await openModal(this);

    const source = rowSelector("core_report:signups");
    const target = rowSelector("core_report:topics");
    const dataTransfer = new DataTransfer();
    const sourceCoordinates = centerOf(gripSelector("core_report:signups"));
    const targetRect = find(target).getBoundingClientRect();
    const targetCoordinates = {
      clientX: targetRect.left + targetRect.width / 2,
      clientY: targetRect.top + 1,
    };

    await dragEvent(source, "dragstart", {
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
    await dragEvent(source, "dragend", {
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

    test("an arrow moves a row past the row shown next to it, not the one hidden between", async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      await openModal(this);
      await fillIn(".manage-reports__search-wrapper .filter-input", "Matching");

      assert.deepEqual(
        enabledKeys(),
        ["core_report:signups", "core_report:topics"],
        "the filter shows the two matching rows, with one hidden between them"
      );

      await click(
        `${rowSelector("core_report:signups")} .d-reorder-buttons__button:last-child`
      );

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

    test("a drag announces the same displayed position the arrow does", async function (assert) {
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

    test("a filtered drag leaves the hidden row in the slot it held", async function (assert) {
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

    test("an arrow leaves the hidden row in the same slot a drag does", async function (assert) {
      await openModal(this);
      await fillIn(".manage-reports__search-wrapper .filter-input", "Matching");

      await click(
        `${rowSelector("core_report:signups")} .d-reorder-buttons__button:last-child`
      );

      await fillIn(".manage-reports__search-wrapper .filter-input", "");

      assert.deepEqual(
        enabledKeys(),
        ["core_report:topics", "core_report:posts", "core_report:signups"],
        "so the two ways of reordering persist the same order rather than disagreeing about the hidden row"
      );
    });

    test("a drag that changes nothing on screen changes nothing at all", async function (assert) {
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
