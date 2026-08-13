import { getOwner } from "@ember/owner";
import { click, find, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  assertDragRegistered,
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";

const REORDER_TEST = "Sidebar link reordering";

function communitySection() {
  return {
    id: 42,
    title: "Community",
    public: false,
    section_type: "community",
    links: [
      {
        id: 1,
        icon: "link",
        name: "Primary 1",
        value: "/primary-1",
        segment: "primary",
      },
      {
        id: 2,
        icon: "link",
        name: "Primary 2",
        value: "/primary-2",
        segment: "primary",
      },
      {
        id: 3,
        icon: "link",
        name: "Secondary 1",
        value: "/secondary-1",
        segment: "secondary",
      },
      {
        id: 4,
        icon: "link",
        name: "Secondary 2",
        value: "/secondary-2",
        segment: "secondary",
      },
    ],
  };
}

/**
 * A section whose primary list is long enough that deleting one link still
 * leaves two visible, so an arrow move has a neighbour to swap with and a
 * deleted link can sit between them.
 */
function sectionWithThreePrimaryLinks() {
  const section = communitySection();

  section.links.splice(2, 0, {
    id: 5,
    icon: "link",
    name: "Primary 3",
    value: "/primary-3",
    segment: "primary",
  });

  return section;
}

function linkNames(selector) {
  return findAll(`${selector} input[name="link-name"]`).map(
    (input) => input.value
  );
}

function renderedLinks() {
  return {
    primary: linkNames(
      ".sidebar-section-form__links-wrapper:not(.--secondary)"
    ),
    secondary: linkNames(".sidebar-section-form__links-wrapper.--secondary"),
  };
}

function gripSelector(name) {
  return `.draggable[data-link-name="${name}"]`;
}

function rowSelector(name) {
  const row = find(gripSelector(name)).closest(".sidebar-section-form-link");
  return `[data-row-id="${row.dataset.rowId}"]`;
}

function arrowSelector(name, direction) {
  return `${rowSelector(name)} button[aria-label="Move ${name} ${direction}"]`;
}

async function moveLink(name, direction) {
  await click(arrowSelector(name, direction));
}

async function dragLink(sourceName, targetName, position) {
  const source = rowSelector(sourceName);
  const target = rowSelector(targetName);

  assertDragRegistered(source, target);

  const targetRect = find(target).getBoundingClientRect();
  const targetCoordinates = {
    clientY: position === "above" ? targetRect.top + 1 : targetRect.bottom - 1,
  };

  await simulateDrag(source, target, {
    dataTransfer: new DataTransfer(),
    sourceCoordinates: centerOf(gripSelector(sourceName)),
    targetCoordinates,
  });
}

async function renderForm(context) {
  await render(
    <template>
      <SidebarSectionForm
        @closeModal={{context.closeModal}}
        @inline={{true}}
        @model={{context.model}}
      />
    </template>
  );
}

module(
  "Integration | Component | Modal | SidebarSectionForm",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      const section = communitySection();

      this.modalClosed = false;
      this.closeModal = () => (this.modalClosed = true);
      this.currentUser.set("sidebar_sections", [section]);
      this.model = { section };
    });

    // `settled()` waits out pending timers, and an announcement schedules its own
    // clear, so a message read after an awaited drag would always be gone.
    hooks.beforeEach(disableClearA11yAnnouncementsInTests);

    hooks.afterEach(function () {
      enableClearA11yAnnouncementsInTests();
      sinon.restore();
    });

    test(`${REORDER_TEST}: announces a cross-list move at its destination position`, async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      await renderForm(this);

      await dragLink("Primary 1", "Secondary 2", "above");

      assert.strictEqual(
        a11y.politeMessage,
        "Moved Primary 1 to position 2 of 3",
        "the position is counted within the list the link moved into"
      );
    });

    test(`${REORDER_TEST}: announces a within-list reorder`, async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      await renderForm(this);

      await dragLink("Primary 2", "Primary 1", "above");

      assert.strictEqual(
        a11y.politeMessage,
        "Moved Primary 2 to position 1 of 2",
        "a same-list move announces against that list's own length"
      );
    });

    test(`${REORDER_TEST}: announces nothing when a drop moves no link`, async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      await renderForm(this);

      const before = a11y.politeMessage;

      await dragLink("Primary 1", "Primary 1", "above");

      assert.strictEqual(
        a11y.politeMessage,
        before,
        "dropping a link onto itself is not a reorder, so nothing is announced"
      );
    });

    test(`${REORDER_TEST}: moves a primary link to the chosen position in the secondary list`, async function (assert) {
      await renderForm(this);

      await dragLink("Primary 1", "Secondary 2", "above");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 2"],
          secondary: ["Secondary 1", "Primary 1", "Secondary 2"],
        },
        "the dragged link is removed from Primary and inserted above its Secondary target"
      );
    });

    test(`${REORDER_TEST}: saves a cross-list move at the chosen secondary position`, async function (assert) {
      let savedLinks;

      pretender.put("/sidebar_sections/42", (request) => {
        savedLinks = JSON.parse(request.requestBody).links.map(
          ({ name, segment }) => ({ name, segment })
        );

        return response({ sidebar_section: communitySection() });
      });

      await renderForm(this);

      await dragLink("Primary 1", "Secondary 2", "above");
      await click("#save-section");

      assert.deepEqual(
        savedLinks,
        [
          { name: "Primary 2", segment: "primary" },
          { name: "Secondary 1", segment: "secondary" },
          { name: "Primary 1", segment: "secondary" },
          { name: "Secondary 2", segment: "secondary" },
        ],
        "the request preserves the dropped position within the destination list"
      );
      assert.true(this.modalClosed, "the successful save closes the modal");
    });

    test(`${REORDER_TEST}: does not duplicate a cross-list link when the drop is repeated`, async function (assert) {
      await renderForm(this);

      await dragLink("Primary 1", "Secondary 2", "above");
      await dragLink("Primary 1", "Secondary 2", "above");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 2"],
          secondary: ["Secondary 1", "Primary 1", "Secondary 2"],
        },
        "the moved link is rendered only once in its destination list"
      );
    });

    test(`${REORDER_TEST}: reorders links within the primary list`, async function (assert) {
      await renderForm(this);

      await dragLink("Primary 2", "Primary 1", "above");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 2", "Primary 1"],
          secondary: ["Secondary 1", "Secondary 2"],
        },
        "the dragged link is inserted above its target without changing lists"
      );
    });

    test(`${REORDER_TEST}: moves a primary link below a secondary target`, async function (assert) {
      await renderForm(this);

      await dragLink("Primary 1", "Secondary 2", "below");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 2"],
          secondary: ["Secondary 1", "Secondary 2", "Primary 1"],
        },
        "the dragged link is removed from Primary and inserted below its Secondary target"
      );
    });

    test(`${REORDER_TEST}: moves a secondary link to the chosen position in the primary list`, async function (assert) {
      await renderForm(this);

      await dragLink("Secondary 2", "Primary 2", "above");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 1", "Secondary 2", "Primary 2"],
          secondary: ["Secondary 1"],
        },
        "the dragged link is removed from Secondary and inserted above its Primary target"
      );
    });

    test(`${REORDER_TEST}: wires every desktop row as a handled source and target`, async function (assert) {
      await renderForm(this);

      assert
        .dom(".sidebar-section-form-link[data-drag-source][data-drop-target]")
        .exists(
          { count: 4 },
          "every link row is both a drag source and a drop target"
        );

      const source = rowSelector("Primary 1");
      const target = rowSelector("Primary 2");
      const dataTransfer = new DataTransfer();

      // The row is not draggable, which is both why a press on its body cannot
      // begin a drag and why the name and URL inputs beside the grip stay
      // selectable. Dispatching here anyway proves the row routes nothing.
      assert.dom(source).doesNotHaveAttribute("draggable");
      await dragEvent(source, "dragstart", {
        dataTransfer,
        ...centerOf(source),
      });
      assert
        .dom(source)
        .doesNotHaveClass(
          "--dragging",
          "pressing the row body does not initiate a drag"
        );
      await dragEvent(source, "dragend", {
        dataTransfer,
        ...centerOf(source),
      });

      await dragEvent(gripSelector("Primary 1"), "dragstart", {
        dataTransfer,
        ...centerOf(gripSelector("Primary 1")),
      });
      assert
        .dom(source)
        .hasClass("--dragging", "pressing the grip initiates the row drag");
      await dragEvent(gripSelector("Primary 1"), "dragend", {
        dataTransfer,
        ...centerOf(target),
      });
    });

    test(`${REORDER_TEST}: leaves no indicator after an abandoned drag`, async function (assert) {
      await renderForm(this);

      const source = rowSelector("Primary 1");
      const target = rowSelector("Primary 2");
      const dataTransfer = new DataTransfer();
      const sourceGrip = gripSelector("Primary 1");
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
      assert
        .dom(source)
        .hasClass("--dragging", "the source uses the shared dragging class");

      await dragEvent(target, "dragenter", {
        dataTransfer,
        ...targetCoordinates,
      });
      await dragEvent(target, "dragover", {
        dataTransfer,
        ...targetCoordinates,
      });
      assert
        .dom(target)
        .hasClass("--drag-above", "the target uses the shared above indicator");

      await dragEvent(sourceGrip, "dragend", {
        dataTransfer,
        ...sourceCoordinates,
      });

      assert
        .dom(source)
        .doesNotHaveClass(
          "--dragging",
          "an abandoned drag clears the source indicator"
        );
      assert
        .dom(target)
        .doesNotHaveClass(
          "--drag-above",
          "an abandoned drag clears the target's above indicator"
        )
        .doesNotHaveClass(
          "--drag-below",
          "an abandoned drag clears the target's below indicator"
        )
        .doesNotHaveClass(
          "drag-above",
          "an abandoned drag leaves no legacy above indicator"
        )
        .doesNotHaveClass(
          "drag-below",
          "an abandoned drag leaves no legacy below indicator"
        );
    });

    test(`${REORDER_TEST}: refuses a self drop`, async function (assert) {
      await renderForm(this);

      const row = rowSelector("Primary 1");
      const sharedDragIsRegistered =
        find(row).hasAttribute("data-drag-source") &&
        find(row).hasAttribute("data-drop-target");
      const dataTransfer = new DataTransfer();
      const sourceGrip = gripSelector("Primary 1");
      const sourceCoordinates = centerOf(sourceGrip);
      const rowRect = find(row).getBoundingClientRect();
      const targetCoordinates = {
        clientX: rowRect.left + rowRect.width / 2,
        clientY: rowRect.top + 1,
      };

      assert.true(
        sharedDragIsRegistered,
        "the self-drop check runs on a shared source and target row"
      );

      if (sharedDragIsRegistered) {
        await dragEvent(sourceGrip, "dragstart", {
          dataTransfer,
          ...sourceCoordinates,
        });
        await dragEvent(row, "dragenter", {
          dataTransfer,
          ...targetCoordinates,
        });
        await dragEvent(row, "dragover", {
          dataTransfer,
          ...targetCoordinates,
        });

        assert
          .dom(row)
          .doesNotHaveClass(
            "--drag-above",
            "a row does not show a drop indicator for itself"
          )
          .doesNotHaveClass(
            "--drag-below",
            "a row does not resolve itself as a drop position"
          );

        await dragEvent(row, "drop", {
          dataTransfer,
          ...targetCoordinates,
        });
        await dragEvent(sourceGrip, "dragend", {
          dataTransfer,
          ...sourceCoordinates,
        });
      }

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 1", "Primary 2"],
          secondary: ["Secondary 1", "Secondary 2"],
        },
        "dropping a link onto itself leaves both lists unchanged"
      );
    });

    test(`${REORDER_TEST}: drags from the grip on mobile too`, async function (assert) {
      // A touch screen has no keyboard, so the arrows are not a substitute here;
      // taking the drag away on mobile left the surface with the arrows alone.
      sinon.stub(this.site, "desktopView").value(false);
      await renderForm(this);

      const row = ".sidebar-section-form-link";
      const grip = `${row} .draggable`;
      const dataTransfer = new DataTransfer();

      assert
        .dom(grip)
        .exists(
          "the grip renders on mobile, so the drag has a target to press"
        );
      assert
        .dom(row)
        .hasAttribute(
          "data-drag-source",
          "",
          "a mobile row carries an active drag-source registration"
        );

      await dragEvent(grip, "dragstart", {
        dataTransfer,
        ...centerOf(grip),
      });
      assert
        .dom(row)
        .hasClass("--dragging", "a drag pressed on the grip starts on mobile");
      await dragEvent(grip, "dragend", { dataTransfer, ...centerOf(grip) });
    });

    test(`${REORDER_TEST}: moves a link down its own list with the arrow`, async function (assert) {
      await renderForm(this);

      await moveLink("Primary 1", "down");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 2", "Primary 1"],
          secondary: ["Secondary 1", "Secondary 2"],
        },
        "the link swaps with the row below it and the other list is untouched"
      );
    });

    test(`${REORDER_TEST}: moves a link up its own list with the arrow`, async function (assert) {
      await renderForm(this);

      await moveLink("Secondary 2", "up");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 1", "Primary 2"],
          secondary: ["Secondary 2", "Secondary 1"],
        },
        "a secondary link swaps within Secondary rather than crossing into Primary"
      );
    });

    test(`${REORDER_TEST}: disables the arrows at each list's boundaries`, async function (assert) {
      await renderForm(this);

      assert
        .dom(arrowSelector("Primary 1", "up"))
        .hasAttribute(
          "aria-disabled",
          "true",
          "the first link has nothing above it"
        );
      assert
        .dom(arrowSelector("Primary 2", "down"))
        .hasAttribute(
          "aria-disabled",
          "true",
          "the last primary link has nothing below it"
        );
      assert
        .dom(arrowSelector("Secondary 1", "up"))
        .hasAttribute(
          "aria-disabled",
          "true",
          "each list boundary is counted within that list"
        );
      assert
        .dom(arrowSelector("Primary 1", "down"))
        .doesNotHaveAttribute(
          "aria-disabled",
          "a link with a row below it can still move down"
        );
    });

    test(`${REORDER_TEST}: steps over a link awaiting deletion`, async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      this.model = { section: sectionWithThreePrimaryLinks() };
      await renderForm(this);

      await click(`${rowSelector("Primary 2")} .delete-link`);
      await moveLink("Primary 1", "down");

      assert.deepEqual(
        renderedLinks().primary,
        ["Primary 3", "Primary 1"],
        "the arrow swaps with the next visible link, not with the deleted one between them"
      );
      assert.strictEqual(
        a11y.politeMessage,
        "Moved Primary 1 to position 2 of 2",
        "the position is counted within the visible list"
      );
    });

    test(`${REORDER_TEST}: a drag over a link awaiting deletion that changes nothing announces nothing`, async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      this.model = { section: sectionWithThreePrimaryLinks() };
      await renderForm(this);

      await click(`${rowSelector("Primary 2")} .delete-link`);

      const before = a11y.politeMessage;

      // Below the link shown above it, which is the position it already holds.
      // In the underlying array it reads as a move, because of the deleted link
      // sitting between the two.
      await dragLink("Primary 3", "Primary 1", "below");

      assert.deepEqual(
        renderedLinks().primary,
        ["Primary 1", "Primary 3"],
        "the visible list is the one it already was"
      );
      assert.strictEqual(
        a11y.politeMessage,
        before,
        "so nothing is announced, rather than a position the link never left"
      );
    });

    test(`${REORDER_TEST}: walks a link down the list with repeated presses`, async function (assert) {
      this.model = { section: sectionWithThreePrimaryLinks() };
      await renderForm(this);

      await moveLink("Primary 1", "down");

      // Through whatever holds focus, which is what a keyboard user presses a
      // second time. Selecting by label instead would find the right button no
      // matter where focus went, and so would pass even if the arrows were
      // unusable: on an unkeyed list the row keeps its DOM node and takes on a
      // different link, so the second press would move the wrong one back.
      await click(document.activeElement);

      assert.deepEqual(
        renderedLinks().primary,
        ["Primary 2", "Primary 3", "Primary 1"],
        "the link keeps moving instead of swapping back and forth"
      );
    });

    test(`${REORDER_TEST}: announces a drag by the position the user can see`, async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      this.model = { section: sectionWithThreePrimaryLinks() };
      await renderForm(this);

      await click(`${rowSelector("Primary 1")} .delete-link`);
      await dragLink("Primary 3", "Primary 2", "above");

      assert.deepEqual(
        renderedLinks().primary,
        ["Primary 3", "Primary 2"],
        "the drag reorders the visible list"
      );
      // The underlying array still holds the deleted link, so counting there
      // would announce a position and a total the user cannot see.
      assert.strictEqual(
        a11y.politeMessage,
        "Moved Primary 3 to position 1 of 2",
        "and the announcement counts only the links still on screen"
      );
    });

    test(`${REORDER_TEST}: announces where an arrow move landed`, async function (assert) {
      const a11y = getOwner(this).lookup("service:a11y");
      await renderForm(this);

      await moveLink("Secondary 2", "up");

      assert.strictEqual(
        a11y.politeMessage,
        "Moved Secondary 2 to position 1 of 2",
        "the announcement counts against the list the link moved within"
      );
    });
  }
);
