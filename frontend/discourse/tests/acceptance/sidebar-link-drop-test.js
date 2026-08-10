import { find, findAll, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  externalDragOver,
  simulateExternalDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";

function linkDataTransfer() {
  const dataTransfer = new DataTransfer();
  dataTransfer.setData("text/uri-list", "https://example.com/useful");
  dataTransfer.setData(
    "text/html",
    '<a href="https://example.com/useful">Useful link</a>'
  );
  return dataTransfer;
}

acceptance("Sidebar web link drop", function (needs) {
  needs.user({
    sidebar_sections: [
      {
        id: 900,
        title: "Reading",
        slug: "reading",
        public: false,
        section_type: null,
        links: [
          {
            id: 901,
            name: "Existing link",
            value: "https://example.org/existing",
            icon: "link",
            external: true,
            segment: "primary",
          },
          {
            id: 902,
            name: "Second link",
            value: "https://example.org/second",
            icon: "link",
            external: true,
            segment: "primary",
          },
        ],
      },
    ],
  });
  needs.settings({ navigation_menu: "sidebar" });
  needs.pretender((server, helper) => {
    server.get("/sidebar_sections/900.json", () =>
      helper.response({
        sidebar_section: {
          id: 900,
          title: "Reading",
          public: false,
          section_type: null,
          locale: "en",
          localizations: [],
          links: [
            {
              id: 901,
              name: "Existing link",
              value: "https://example.org/existing",
              icon: "link",
              external: true,
              segment: "primary",
              locale: "en",
              localizations: [],
            },
            {
              id: 902,
              name: "Second link",
              value: "https://example.org/second",
              icon: "link",
              external: true,
              segment: "primary",
              locale: "en",
              localizations: [],
            },
          ],
        },
      })
    );
  });

  test("dropping a web link creates a prefilled custom section", async function (assert) {
    await visit("/");

    const dataTransfer = linkDataTransfer();
    await externalDragOver("#d-sidebar", { dataTransfer });

    assert
      .dom(".sidebar-link-drop-target")
      .exists("shows the new-section drop target");

    await triggerEvent("#d-sidebar", "dragleave", { dataTransfer });
    assert
      .dom(".sidebar-link-drop-target")
      .doesNotExist("clears the target after leaving the sidebar");

    await simulateExternalDrag("#d-sidebar", { dataTransfer });

    assert
      .dom(".sidebar-section-form-modal")
      .exists("opens the custom section form");
    assert
      .dom('input[name="link-name"]')
      .hasValue("Useful link", "prefills the dragged link name")
      .isFocused("focuses the proposed link name");
    const nameInput = find('input[name="link-name"]');
    assert.strictEqual(nameInput.selectionStart, 0, "selects from the start");
    assert.strictEqual(
      nameInput.selectionEnd,
      nameInput.value.length,
      "selects the full proposed name"
    );
    assert
      .dom('input[name="link-url"]')
      .hasValue("https://example.com/useful", "prefills the dragged link URL");
  });

  test("dropping a web link inserts it at the indicated position", async function (assert) {
    await visit("/");

    const section = '.sidebar-section[data-section-name="reading"]';
    const existingLinks = findAll(`${section} [data-sidebar-custom-link]`);
    const clientY = existingLinks[1].getBoundingClientRect().top;
    const dataTransfer = linkDataTransfer();
    await externalDragOver(section, { dataTransfer, coordinates: { clientY } });

    assert
      .dom(existingLinks[1])
      .hasClass(
        "is-link-drop-before",
        "shows a line between the existing links"
      );
    assert
      .dom(".sidebar-link-drop-target")
      .doesNotExist("does not also advertise a new section");

    await triggerEvent(section, "drop", { dataTransfer, clientY });

    assert
      .dom(".sidebar-section-form-modal")
      .exists("opens the existing section form");
    const linkNameInputs = findAll(
      '.sidebar-section-form-link-wrapper input[name="link-name"]'
    );
    const linkUrlInputs = findAll(
      '.sidebar-section-form-link-wrapper input[name="link-url"]'
    );
    assert.strictEqual(linkUrlInputs.length, 3, "inserts one link");
    assert.dom(linkNameInputs[1]).isFocused("focuses the inserted link name");
    assert
      .dom(linkUrlInputs[1])
      .hasValue(
        "https://example.com/useful",
        "inserts the link at the indicated gap"
      );
    assert
      .dom(".sidebar-link-drop-target")
      .doesNotExist("does not also create a new section");
  });
});
