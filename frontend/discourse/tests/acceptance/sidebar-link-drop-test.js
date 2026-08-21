import { find, findAll, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  dragEvent,
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

  test("dropping a web link on the revealed zone creates a prefilled custom section", async function (assert) {
    await visit("/");

    const dataTransfer = linkDataTransfer();
    const scroller = find(".sidebar-sections").getBoundingClientRect();
    const coordinates = {
      clientX: scroller.left + scroller.width / 2,
      clientY: scroller.top + scroller.height / 2,
    };

    await externalDragOver("#d-sidebar", { dataTransfer, coordinates });

    assert
      .dom(".sidebar-custom-sections + .sidebar-link-drop-target")
      .exists(
        "dwelling over the sections reveals the drop zone where the new section would go, after the last custom section"
      );
    assert
      .dom(".sidebar-link-drop-target.is-arming")
      .doesNotExist("the zone has armed and can take the drop");

    await dragEvent("#d-sidebar", "dragleave", {
      dataTransfer,
      ...coordinates,
    });
    assert
      .dom(".sidebar-link-drop-target")
      .doesNotExist("hides the zone when the drag leaves the sidebar");

    await externalDragOver("#d-sidebar", { dataTransfer, coordinates });
    await simulateExternalDrag(".sidebar-link-drop-target", { dataTransfer });

    assert
      .dom(".sidebar-section-form-modal")
      .exists("opens the custom section form");
    assert
      .dom('input[name="section-name"]')
      .isFocused(
        "focuses the title, the one field the new section still needs"
      );
    assert
      .dom('input[name="link-name"]')
      .hasValue("Useful link", "prefills the dragged link name");
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
      .exists(
        "the new-section zone is revealed too, but the hovered section claims the drop"
      );

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
      .doesNotExist("the zone clears once the drag ends");
  });

  test("a drop on the sidebar background does not create a section", async function (assert) {
    await visit("/");

    const dataTransfer = linkDataTransfer();
    const scroller = find(".sidebar-sections").getBoundingClientRect();
    const coordinates = {
      clientX: scroller.left + scroller.width / 2,
      clientY: scroller.top + scroller.height / 2,
    };

    await externalDragOver("#d-sidebar", { dataTransfer, coordinates });
    assert.dom(".sidebar-link-drop-target").exists("the zone is revealed");

    // A real browser would not even fire this drop: the sidebar refuses with a
    // "none" drop effect, so releasing over it cancels the drag. The synthetic
    // drop proves that one arriving anyway lands on nothing that handles it.
    await dragEvent("#d-sidebar", "drop", { dataTransfer, ...coordinates });

    assert
      .dom(".sidebar-section-form-modal")
      .doesNotExist("no section form opens for a drop outside the zone");
    assert
      .dom(".sidebar-link-drop-target")
      .doesNotExist("the zone clears once the drag ends");
  });

  test("scrolls the sections while a dragged link hovers the bottom edge", async function (assert) {
    await visit("/");

    // The fixture's sections do not overflow the test viewport on their own,
    // so the scroller is constrained to force it. It is a flex child sized by
    // the flex algorithm, so a height alone would be ignored.
    const scroller = find(".sidebar-sections");
    scroller.style.flex = "none";
    scroller.style.minHeight = "0";
    scroller.style.height = "100px";
    scroller.style.overflowY = "auto";

    const dataTransfer = linkDataTransfer();
    const { left, bottom, width } = scroller.getBoundingClientRect();
    const point = { clientX: left + width / 2, clientY: bottom - 2 };
    await dragEvent(scroller, "dragenter", { dataTransfer, ...point });
    // Auto-scroll runs off its own animation-frame loop and eases in over
    // time, so a single event moves nothing measurable.
    for (let frame = 0; frame < 12; frame++) {
      await dragEvent(scroller, "dragover", { dataTransfer, ...point });
    }

    assert.true(
      scroller.scrollTop > 0,
      "a link held against the bottom edge scrolls the sections into reach"
    );
  });

  test("points out a dropped link the section already has", async function (assert) {
    await visit("/");

    const section = '.sidebar-section[data-section-name="reading"]';
    const dataTransfer = new DataTransfer();
    dataTransfer.setData("text/uri-list", "https://example.org/existing");

    await simulateExternalDrag(section, { dataTransfer });

    assert
      .dom(".sidebar-section-form-modal")
      .exists("still opens the form, since a repeat is allowed");
    assert
      .dom(".sidebar-section-form-link-wrapper .duplicate-link")
      .exists({ count: 1 }, "marks the repeat, and only the repeat");
    assert
      .dom("#save-section")
      .isNotDisabled("a repeated link is a warning, not a refusal");
  });
});

/**
 * A public section, which only an admin may edit. Whether a link can be dropped
 * into one has to follow that, or the drag offers a new section to the very
 * people who could have edited this one.
 */
function publicSection() {
  return [
    {
      id: 910,
      title: "Announcements",
      slug: "announcements",
      public: true,
      section_type: null,
      links: [
        {
          id: 911,
          name: "Existing link",
          value: "https://example.org/existing",
          icon: "link",
          external: true,
          segment: "primary",
        },
      ],
    },
  ];
}

const PUBLIC_SECTION = '.sidebar-section[data-section-name="announcements"]';

acceptance("Sidebar web link drop | public section, admin", function (needs) {
  needs.user({ admin: true, sidebar_sections: publicSection() });
  needs.settings({ navigation_menu: "sidebar" });

  test("a public section takes a dropped link for someone who can edit it", async function (assert) {
    await visit("/");

    await externalDragOver(PUBLIC_SECTION, {
      dataTransfer: linkDataTransfer(),
    });

    assert
      .dom(PUBLIC_SECTION)
      .hasClass(
        "is-link-drop-active",
        "an admin can edit a public section, so a link dropped on it goes in"
      );
    assert
      .dom(".sidebar-link-drop-target")
      .exists(
        "the new-section zone is revealed alongside, for a drop outside the section"
      );
  });
});

acceptance(
  "Sidebar web link drop | public section, regular user",
  function (needs) {
    needs.user({ admin: false, sidebar_sections: publicSection() });
    needs.settings({ navigation_menu: "sidebar" });

    test("a public section refuses a dropped link for someone who cannot edit it", async function (assert) {
      await visit("/");

      await externalDragOver(PUBLIC_SECTION, {
        dataTransfer: linkDataTransfer(),
      });

      assert
        .dom(PUBLIC_SECTION)
        .doesNotHaveClass(
          "is-link-drop-active",
          "a section this user cannot edit does not take the drop"
        );
      assert
        .dom(".sidebar-link-drop-target")
        .exists(
          "the dwell still reveals the zone, offering a section of their own"
        );
    });
  }
);
