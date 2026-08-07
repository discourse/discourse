import {
  click,
  find,
  findAll,
  render,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

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

async function dragAbove(sourceName, targetName) {
  const source = find(`.draggable[data-link-name="${sourceName}"]`);
  const target = find(`.draggable[data-link-name="${targetName}"]`).closest(
    ".sidebar-section-form-link"
  );
  const dataTransfer = { effectAllowed: null };

  await triggerEvent(source, "dragstart", { dataTransfer });
  await triggerEvent(target, "dragover", { dataTransfer, offsetY: -1 });
  await triggerEvent(target, "drop", { dataTransfer, offsetY: -1 });
}

async function dragBelow(sourceName, targetName) {
  const source = find(`.draggable[data-link-name="${sourceName}"]`);
  const target = find(`.draggable[data-link-name="${targetName}"]`).closest(
    ".sidebar-section-form-link"
  );
  const dataTransfer = { effectAllowed: null };
  const offsetY = target.getBoundingClientRect().height / 2 + 1;

  await triggerEvent(source, "dragstart", { dataTransfer });
  await triggerEvent(target, "dragover", { dataTransfer, offsetY });
  await triggerEvent(target, "drop", { dataTransfer, offsetY });
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

    test("moves a primary link to the chosen position in the secondary list", async function (assert) {
      await render(
        <template>
          <SidebarSectionForm
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );

      await dragAbove("Primary 1", "Secondary 2");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 2"],
          secondary: ["Secondary 1", "Primary 1", "Secondary 2"],
        },
        "the dragged link is removed from Primary and inserted above its Secondary target"
      );
    });

    test("saves a cross-list move at the chosen secondary position", async function (assert) {
      let savedLinks;

      pretender.put("/sidebar_sections/42", (request) => {
        savedLinks = JSON.parse(request.requestBody).links.map(
          ({ name, segment }) => ({ name, segment })
        );

        return response({ sidebar_section: communitySection() });
      });

      await render(
        <template>
          <SidebarSectionForm
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );

      await dragAbove("Primary 1", "Secondary 2");
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

    test("does not duplicate a cross-list link when the drop is repeated", async function (assert) {
      await render(
        <template>
          <SidebarSectionForm
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );

      await dragAbove("Primary 1", "Secondary 2");
      await dragAbove("Primary 1", "Secondary 2");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 2"],
          secondary: ["Secondary 1", "Primary 1", "Secondary 2"],
        },
        "the moved link is rendered only once in its destination list"
      );
    });

    test("reorders links within the primary list", async function (assert) {
      await render(
        <template>
          <SidebarSectionForm
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );

      await dragAbove("Primary 2", "Primary 1");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 2", "Primary 1"],
          secondary: ["Secondary 1", "Secondary 2"],
        },
        "the dragged link is inserted above its target without changing lists"
      );
    });

    test("moves a primary link below a secondary target", async function (assert) {
      await render(
        <template>
          <SidebarSectionForm
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );

      await dragBelow("Primary 1", "Secondary 2");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 2"],
          secondary: ["Secondary 1", "Secondary 2", "Primary 1"],
        },
        "the dragged link is removed from Primary and inserted below its Secondary target"
      );
    });

    test("moves a secondary link to the chosen position in the primary list", async function (assert) {
      await render(
        <template>
          <SidebarSectionForm
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );

      await dragAbove("Secondary 2", "Primary 2");

      assert.deepEqual(
        renderedLinks(),
        {
          primary: ["Primary 1", "Secondary 2", "Primary 2"],
          secondary: ["Secondary 1"],
        },
        "the dragged link is removed from Secondary and inserted above its Primary target"
      );
    });
  }
);
