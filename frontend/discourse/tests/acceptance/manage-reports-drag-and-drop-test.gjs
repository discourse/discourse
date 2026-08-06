import { getOwner } from "@ember/owner";
import { fillIn, find, findAll, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import ManageReports from "discourse/admin/components/modal/manage-reports";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
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

  if (
    !find(source).hasAttribute("data-drag-source") ||
    !find(target).hasAttribute("data-drop-target")
  ) {
    return;
  }

  const targetRect = find(target).getBoundingClientRect();
  await simulateDrag(source, target, {
    dataTransfer: new DataTransfer(),
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
    assert.strictEqual(
      getComputedStyle(find(disabledRow)).cursor,
      "auto",
      "a disabled row does not receive the grab cursor"
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
    const sourceCoordinates = centerOf(source);
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
    const sourceCoordinates = centerOf(source);
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
