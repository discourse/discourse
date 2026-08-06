import { click, find, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";

const ORACLE = "Sidebar link DnD oracle";

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

function linkNames(selector) {
  return findAll(`${selector} input[name="link-name"]`).map(
    (input) => input.value
  );
}

function renderedLinks() {
  return {
    primary: linkNames(".sidebar-section-form__links-wrapper"),
    secondary: linkNames(
      ".sidebar-section-form > h3 ~ .sidebar-section-form-link-wrapper"
    ),
  };
}

function gripSelector(name) {
  return `.draggable[data-link-name="${name}"]`;
}

function rowSelector(name) {
  const row = find(gripSelector(name)).closest(".sidebar-section-form-link");
  return `[data-row-id="${row.dataset.rowId}"]`;
}

async function dragLink(sourceName, targetName, position) {
  const source = rowSelector(sourceName);
  const target = rowSelector(targetName);

  if (
    !find(source).hasAttribute("data-drag-source") ||
    !find(target).hasAttribute("data-drop-target")
  ) {
    return;
  }

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

    hooks.afterEach(function () {
      sinon.restore();
    });

    test(`${ORACLE} moves a primary link to the chosen position in the secondary list`, async function (assert) {
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

    test(`${ORACLE} saves a cross-list move at the chosen secondary position`, async function (assert) {
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

    test(`${ORACLE} does not duplicate a cross-list link when the drop is repeated`, async function (assert) {
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

    test(`${ORACLE} reorders links within the primary list`, async function (assert) {
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

    test(`${ORACLE} moves a primary link below a secondary target`, async function (assert) {
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

    test(`${ORACLE} moves a secondary link to the chosen position in the primary list`, async function (assert) {
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

    test(`${ORACLE} wires every desktop row as a handled source and target`, async function (assert) {
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

      await dragEvent(source, "dragstart", {
        dataTransfer,
        ...centerOf(gripSelector("Primary 1")),
      });
      assert
        .dom(source)
        .hasClass("--dragging", "pressing the grip initiates the row drag");
      await dragEvent(source, "dragend", {
        dataTransfer,
        ...centerOf(target),
      });
    });

    test(`${ORACLE} leaves no indicator after an abandoned drag`, async function (assert) {
      await renderForm(this);

      const source = rowSelector("Primary 1");
      const target = rowSelector("Primary 2");
      const dataTransfer = new DataTransfer();
      const sourceCoordinates = centerOf(gripSelector("Primary 1"));
      const targetRect = find(target).getBoundingClientRect();
      const targetCoordinates = {
        clientX: targetRect.left + targetRect.width / 2,
        clientY: targetRect.top + 1,
      };

      await dragEvent(source, "dragstart", {
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

      await dragEvent(source, "dragend", {
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

    test(`${ORACLE} refuses a self drop`, async function (assert) {
      await renderForm(this);

      const row = rowSelector("Primary 1");
      const sharedDragIsRegistered =
        find(row).hasAttribute("data-drag-source") &&
        find(row).hasAttribute("data-drop-target");
      const dataTransfer = new DataTransfer();
      const sourceCoordinates = centerOf(gripSelector("Primary 1"));
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
        await dragEvent(row, "dragstart", {
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
        await dragEvent(row, "dragend", {
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

    test(`${ORACLE} disables row drag initiation on mobile`, async function (assert) {
      sinon.stub(this.site, "desktopView").value(false);
      await renderForm(this);

      const row = ".sidebar-section-form-link";
      const dataTransfer = new DataTransfer();
      const coordinates = centerOf(row);

      assert
        .dom(row)
        .doesNotHaveAttribute(
          "data-drag-source",
          "mobile rows have no active drag-source registration"
        );

      await dragEvent(row, "dragstart", { dataTransfer, ...coordinates });
      assert
        .dom(row)
        .doesNotHaveClass("--dragging", "a mobile row cannot initiate a drag");
      await dragEvent(row, "dragend", { dataTransfer, ...coordinates });
    });
  }
);
