import { getOwner } from "@ember/owner";
import { click, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ConfigureMenu from "discourse/admin/components/dashboard/configure-menu";
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

const ORACLE = "Configure menu DnD oracle";

const FOUR_SECTIONS = [
  { id: "highlights", visible: true },
  { id: "reports", visible: true },
  { id: "traffic", visible: false },
  { id: "engagement", visible: true },
];

function rowSelector(id) {
  return `[data-section-id="${id}"]`;
}

async function dragSection(sourceId, targetId, position) {
  const source = rowSelector(sourceId);
  const target = rowSelector(targetId);

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

module("Integration | Component | Dashboard | ConfigureMenu", function (hooks) {
  setupRenderingTest(hooks);

  // `settled()` waits out pending timers, and an announcement schedules its own
  // clear, so a message read after `await click(...)` would always be gone.
  hooks.beforeEach(disableClearA11yAnnouncementsInTests);
  hooks.afterEach(enableClearA11yAnnouncementsInTests);

  test("renders one row per section", async function (assert) {
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    assert.dom(".db-configure__row").exists({ count: 4 });
    assert.dom('[data-section-id="highlights"]').exists();
    assert.dom('[data-section-id="reports"]').exists();
    assert.dom('[data-section-id="traffic"]').exists();
    assert.dom('[data-section-id="engagement"]').exists();
  });

  test("toggle click fires @onToggleVisibility with the section id", async function (assert) {
    const sections = FOUR_SECTIONS;
    const calls = [];
    const onToggle = (id) => calls.push(id);
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{onToggle}}
        />
      </template>
    );

    await click('[data-section-id="highlights"] .d-toggle-switch__checkbox');
    assert.deepEqual(calls, ["highlights"]);
  });

  test(`${ORACLE} reorders in both directions`, async function (assert) {
    const sections = FOUR_SECTIONS;
    const calls = [];
    const onReorder = (from, to) => calls.push([from, to]);
    const noop = () => {};

    await render(
      <template>
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

  test(`${ORACLE} wires every row as a shared source and target`, async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{FOUR_SECTIONS}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    assert
      .dom(".db-configure__row[data-drag-source][data-drop-target]")
      .exists(
        { count: FOUR_SECTIONS.length },
        "every configure row is both a shared drag source and drop target"
      );
  });

  test(`${ORACLE} uses the shared drag state classes`, async function (assert) {
    const noop = () => {};

    await render(
      <template>
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
    const noop = () => {};

    await render(
      <template>
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

  test("desktop renders the drag handle alongside the arrows", async function (assert) {
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    assert.dom(".db-configure__drag-handle").exists({ count: 4 });
    assert
      .dom(".db-configure__arrow")
      .exists(
        { count: 8 },
        "desktop keeps a keyboard path to reorder, not only the pointer drag"
      );
  });

  test("desktop arrow buttons fire @onReorder", async function (assert) {
    const sections = FOUR_SECTIONS;
    const calls = [];
    const onReorder = (from, to) => calls.push([from, to]);
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{onReorder}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    await click('[data-section-id="reports"] .db-configure__arrow:first-child');
    assert.deepEqual(
      calls.at(-1),
      [1, 0],
      "the up arrow moves the row earlier"
    );

    await click(
      '[data-section-id="highlights"] .db-configure__arrow:last-child'
    );
    assert.deepEqual(
      calls.at(-1),
      [0, 1],
      "the down arrow moves the row later"
    );
  });

  test("the arrow path announces where the row landed", async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    await click('[data-section-id="reports"] .db-configure__arrow:first-child');
    assert.strictEqual(
      a11y.politeMessage,
      "Moved Reports to position 1 of 4",
      "the announcement names the row and its resulting position"
    );

    await click(
      '[data-section-id="highlights"] .db-configure__arrow:last-child'
    );
    assert.strictEqual(
      a11y.politeMessage,
      "Moved Highlights to position 2 of 4",
      "moving down announces the row's new position, not the direction"
    );
  });

  test(`${ORACLE} the drag path announces through the same call as the arrows`, async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
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

  test(`${ORACLE} a reorder that moves nothing announces nothing`, async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
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

  test("desktop arrows are reachable by keyboard and bound at the ends", async function (assert) {
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    assert
      .dom(".db-configure__drag-handle")
      .hasAttribute(
        "tabindex",
        "-1",
        "the handle stays out of the tab order — the arrows carry the keyboard path"
      );
    assert
      .dom('[data-section-id="reports"] .db-configure__arrow:first-child')
      .doesNotHaveAttribute(
        "tabindex",
        "the arrows keep their native button tab stop"
      );
    assert
      .dom('[data-section-id="highlights"] .db-configure__arrow:first-child')
      .isDisabled("first row's up arrow is disabled");
    assert
      .dom('[data-section-id="engagement"] .db-configure__arrow:last-child')
      .isDisabled("last row's down arrow is disabled");
  });
});

module(
  "Integration | Component | Dashboard | ConfigureMenu | Mobile",
  function (hooks) {
    hooks.beforeEach(function () {
      forceMobile();
    });

    setupRenderingTest(hooks);

    test("hides the drag handle and renders arrow buttons", async function (assert) {
      const sections = FOUR_SECTIONS;
      const noop = () => {};

      await render(
        <template>
          <ConfigureMenu
            @sections={{sections}}
            @onReorder={{noop}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      assert.dom(".db-configure__drag-handle").doesNotExist();
      assert.dom(".db-configure__arrow").exists({ count: 8 });
    });

    test(`${ORACLE} disables shared row drag on mobile`, async function (assert) {
      const noop = () => {};

      await render(
        <template>
          <ConfigureMenu
            @sections={{FOUR_SECTIONS}}
            @onReorder={{noop}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      assert
        .dom(".db-configure__row")
        .doesNotHaveAttribute(
          "data-drag-source",
          "mobile rows have no active drag-source registration"
        )
        .doesNotHaveAttribute(
          "draggable",
          "mobile rows have no hardcoded draggable attribute"
        );
    });

    test("arrow buttons fire @onReorder", async function (assert) {
      const sections = FOUR_SECTIONS;
      const calls = [];
      const onReorder = (from, to) => calls.push([from, to]);
      const noop = () => {};

      await render(
        <template>
          <ConfigureMenu
            @sections={{sections}}
            @onReorder={{onReorder}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      await click(
        '[data-section-id="reports"] .db-configure__arrow:first-child'
      );
      assert.deepEqual(calls.at(-1), [1, 0]);

      await click(
        '[data-section-id="highlights"] .db-configure__arrow:last-child'
      );
      assert.deepEqual(calls.at(-1), [0, 1]);
    });

    test("first row's up button and last row's down button are disabled", async function (assert) {
      const sections = FOUR_SECTIONS;
      const noop = () => {};

      await render(
        <template>
          <ConfigureMenu
            @sections={{sections}}
            @onReorder={{noop}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      assert
        .dom('[data-section-id="highlights"] .db-configure__arrow:first-child')
        .isDisabled("first row's up arrow is disabled");
      assert
        .dom('[data-section-id="engagement"] .db-configure__arrow:last-child')
        .isDisabled("last row's down arrow is disabled");
      assert
        .dom('[data-section-id="reports"] .db-configure__arrow:first-child')
        .isNotDisabled("middle row's up arrow is enabled");
    });
  }
);
