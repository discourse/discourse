import {
  click,
  fillIn,
  find,
  findAll,
  settled,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  centerOf,
  dragEvent,
  dragOver,
  externalDragOver,
  simulateDrag,
  simulateExternalDrag,
  startDrag,
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
  needs.pretender((server, helper) => {
    server.get("/sidebar_sections/910.json", () =>
      helper.response({
        sidebar_section: {
          id: 910,
          title: "Announcements",
          public: true,
          section_type: null,
          locale: "en",
          localizations: [],
          links: [
            {
              id: 911,
              name: "Existing link",
              value: "https://example.org/existing",
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

  test("still takes a dragged link after a panel switch and back", async function (assert) {
    await visit("/");

    const sidebarState = this.container.lookup("service:sidebar-state");
    sidebarState.setPanel(ADMIN_PANEL);
    await settled();
    sidebarState.setPanel(MAIN_PANEL);
    await settled();

    const dataTransfer = linkDataTransfer();
    await externalDragOver(PUBLIC_SECTION, { dataTransfer });

    assert
      .dom(PUBLIC_SECTION)
      .hasClass(
        "is-link-drop-active",
        "the section still takes the drop after the sections were remounted"
      );
    assert
      .dom(".sidebar-link-drop-target")
      .exists("the dwell still reveals the zone after the remount");

    await simulateExternalDrag(PUBLIC_SECTION, { dataTransfer });
    assert
      .dom(".sidebar-section-form-modal")
      .exists("and the drop still opens the section form");
  });

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

function moveFixtureSections() {
  return [
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
    {
      id: 910,
      title: "Watching",
      slug: "watching",
      public: false,
      section_type: null,
      links: [
        {
          id: 911,
          name: "Other link",
          value: "https://example.org/other",
          icon: "link",
          external: true,
          segment: "primary",
        },
      ],
    },
  ];
}

acceptance("Sidebar link move", function (needs) {
  needs.user({ sidebar_sections: moveFixtureSections() });
  needs.settings({ navigation_menu: "sidebar" });

  let reorderRequests;
  let moveRequests;

  needs.hooks.beforeEach(function () {
    reorderRequests = [];
    moveRequests = [];
  });

  needs.pretender((server, helper) => {
    server.put("/sidebar_sections/900/reorder", (request) => {
      reorderRequests.push(helper.parsePostData(request.requestBody));
      const [reading] = moveFixtureSections();
      reading.links.reverse();
      return helper.response({ sidebar_section: reading });
    });
    server.put("/sidebar_sections/900/move_link", (request) => {
      moveRequests.push(helper.parsePostData(request.requestBody));
      const [reading, watching] = moveFixtureSections();
      watching.links.push(reading.links.shift());
      return helper.response({ sidebar_sections: [reading, watching] });
    });
  });

  const READING = '.sidebar-section[data-section-name="reading"]';
  const WATCHING = '.sidebar-section[data-section-name="watching"]';
  const FIRST_ROW = `${READING} li[data-sidebar-custom-link]:nth-of-type(1)`;

  test("dragging a link below its sibling reorders the section", async function (assert) {
    await visit("/");

    const rows = findAll(`${READING} [data-sidebar-custom-link]`);
    const target = rows[1].getBoundingClientRect();

    await simulateDrag(FIRST_ROW, READING, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: { clientY: target.bottom - 2 },
    });

    assert.strictEqual(reorderRequests.length, 1, "commits one reorder");
    assert.deepEqual(
      reorderRequests[0]["links_order[]"],
      ["902", "901"],
      "sends the new id order"
    );
    assert
      .dom(".sidebar-section-form-modal")
      .doesNotExist("a move opens no form");
    assert
      .dom(
        `${READING} li[data-sidebar-custom-link]:nth-of-type(1) [data-link-name]`
      )
      .hasAttribute(
        "data-link-name",
        "Second link",
        "the section re-renders in the committed order"
      );
  });

  test("dragging a link into another section moves it", async function (assert) {
    await visit("/");

    await simulateDrag(FIRST_ROW, WATCHING, {
      dataTransfer: new DataTransfer(),
    });

    assert.strictEqual(moveRequests.length, 1, "commits one move");
    assert.strictEqual(moveRequests[0].link_id, "901", "names the link");
    assert.strictEqual(
      moveRequests[0].target_section_id,
      "910",
      "names the destination"
    );
    assert.true("position" in moveRequests[0], "carries the drop position");
    assert
      .dom(`${WATCHING} [data-link-name="Existing link"]`)
      .exists("the link now renders in the target section");
    assert
      .dom(`${READING} [data-link-name="Existing link"]`)
      .doesNotExist("and left its old section");
  });

  test("dropping a link back onto its own position changes nothing", async function (assert) {
    await visit("/");

    const rows = findAll(`${READING} [data-sidebar-custom-link]`);
    const own = rows[0].getBoundingClientRect();

    await simulateDrag(FIRST_ROW, READING, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: { clientY: own.top + 2 },
    });

    assert.strictEqual(reorderRequests.length, 0, "no reorder request");
    assert.strictEqual(moveRequests.length, 0, "no move request");
    assert
      .dom(".sidebar-section-form-modal")
      .doesNotExist("and no form either");
  });
});

function publicMoveFixtureSections() {
  return [
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
      ],
    },
    {
      id: 920,
      title: "Announcements",
      slug: "announcements",
      public: true,
      section_type: null,
      links: [
        {
          id: 921,
          name: "First public",
          value: "https://example.org/first-public",
          icon: "link",
          external: true,
          segment: "primary",
        },
        {
          id: 922,
          name: "Second public",
          value: "https://example.org/second-public",
          icon: "link",
          external: true,
          segment: "primary",
        },
      ],
    },
  ];
}

acceptance("Sidebar link move | public section", function (needs) {
  needs.user({ admin: true, sidebar_sections: publicMoveFixtureSections() });
  needs.settings({ navigation_menu: "sidebar" });

  let requests;

  needs.hooks.beforeEach(function () {
    requests = [];
  });

  needs.pretender((server, helper) => {
    server.put("/sidebar_sections/920/reorder", (request) => {
      requests.push(helper.parsePostData(request.requestBody));
      const [, announcements] = publicMoveFixtureSections();
      announcements.links.reverse();
      return helper.response({ sidebar_section: announcements });
    });
    server.put("/sidebar_sections/920/move_link", (request) => {
      requests.push(helper.parsePostData(request.requestBody));
      const [reading, announcements] = publicMoveFixtureSections();
      reading.links.push(announcements.links.shift());
      return helper.response({ sidebar_sections: [announcements, reading] });
    });
  });

  const PUBLIC = '.sidebar-section[data-section-name="announcements"]';
  const PRIVATE = '.sidebar-section[data-section-name="reading"]';
  const PUBLIC_FIRST_ROW = `${PUBLIC} li[data-sidebar-custom-link]:nth-of-type(1)`;

  test("reordering a public section asks first, and cancel commits nothing", async function (assert) {
    await visit("/");

    const rows = findAll(`${PUBLIC} [data-sidebar-custom-link]`);
    const target = rows[1].getBoundingClientRect();

    await simulateDrag(PUBLIC_FIRST_ROW, PUBLIC, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: { clientY: target.bottom - 2 },
    });

    assert
      .dom(".dialog-container .dialog-content")
      .exists("the change is visible to everyone, so it asks first");
    assert.strictEqual(requests.length, 0, "nothing committed while asking");

    await click(".dialog-footer .btn-default");
    assert.strictEqual(requests.length, 0, "declining commits nothing");
    assert
      .dom(
        `${PUBLIC} li[data-sidebar-custom-link]:nth-of-type(1) [data-link-name]`
      )
      .hasAttribute("data-link-name", "First public", "the order is untouched");
  });

  test("confirming the public reorder commits it", async function (assert) {
    await visit("/");

    const rows = findAll(`${PUBLIC} [data-sidebar-custom-link]`);
    const target = rows[1].getBoundingClientRect();

    await simulateDrag(PUBLIC_FIRST_ROW, PUBLIC, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: { clientY: target.bottom - 2 },
    });
    await click(".dialog-footer .btn-primary");

    assert.strictEqual(requests.length, 1, "the confirmed reorder commits");
    assert.deepEqual(
      requests[0]["links_order[]"],
      ["922", "921"],
      "with the new order"
    );
  });

  test("moving a public link into a private section still asks", async function (assert) {
    await visit("/");

    await simulateDrag(PUBLIC_FIRST_ROW, PRIVATE, {
      dataTransfer: new DataTransfer(),
    });

    assert
      .dom(".dialog-container .dialog-content")
      .exists("taking a link out of a public section is a public change");

    await click(".dialog-footer .btn-primary");
    assert.strictEqual(requests.length, 1, "the confirmed move commits");
    assert.strictEqual(requests[0].link_id, "921", "moving the public link");
    assert.strictEqual(
      requests[0].target_section_id,
      "900",
      "into the private section"
    );
  });
});

acceptance("Sidebar link move | split out to a new section", function (needs) {
  needs.user({ sidebar_sections: moveFixtureSections() });
  needs.settings({ navigation_menu: "sidebar" });

  let createRequests;
  let cleanupRequests;

  needs.hooks.beforeEach(function () {
    createRequests = [];
    cleanupRequests = [];
  });

  needs.pretender((server, helper) => {
    server.post("/sidebar_sections", (request) => {
      createRequests.push(helper.parsePostData(request.requestBody));
      return helper.response({
        sidebar_section: {
          id: 930,
          title: "Split",
          slug: "split",
          public: false,
          section_type: null,
          links: [
            {
              id: 931,
              name: "Existing link",
              value: "https://example.org/existing",
              icon: "link",
              external: true,
              segment: "primary",
            },
          ],
        },
      });
    });
    server.put("/sidebar_sections/900", (request) => {
      cleanupRequests.push(helper.parsePostData(request.requestBody));
      const [reading] = moveFixtureSections();
      reading.links.shift();
      return helper.response({ sidebar_section: reading });
    });
  });

  const READING = '.sidebar-section[data-section-name="reading"]';
  const FIRST_ROW = `${READING} li[data-sidebar-custom-link]:nth-of-type(1)`;

  async function dragRowToRevealedZone() {
    const dataTransfer = new DataTransfer();
    await startDrag(FIRST_ROW, { dataTransfer });

    const scroller = find(".sidebar-sections").getBoundingClientRect();
    await dragOver(".sidebar-sections", {
      dataTransfer,
      coordinates: {
        clientX: scroller.left + scroller.width / 2,
        clientY: scroller.top + scroller.height / 2,
      },
    });
    await settled();

    // Captured before the drop: the zone hides the moment the drag ends.
    const zonePoint = centerOf(".sidebar-link-drop-target");
    await dragOver(".sidebar-link-drop-target", { dataTransfer });
    await dragEvent(".sidebar-link-drop-target", "drop", {
      dataTransfer,
      ...zonePoint,
    });
    await dragEvent(FIRST_ROW, "dragend", { dataTransfer, ...zonePoint });
  }

  test("dropping a row on the zone creates a section and removes the original on save", async function (assert) {
    await visit("/");

    await dragRowToRevealedZone();

    assert
      .dom(".sidebar-section-form-modal")
      .exists("the create form opens for the split-out section");
    assert
      .dom('input[name="link-name"]')
      .hasValue("Existing link", "prefilled with the dragged link");
    assert
      .dom('input[name="link-url"]')
      .hasValue("https://example.org/existing", "and its URL");

    await fillIn('input[name="section-name"]', "Split");
    await click("#save-section");

    assert.strictEqual(createRequests.length, 1, "creates the new section");
    assert.strictEqual(
      createRequests[0].links[0].value,
      "https://example.org/existing",
      "with the moved link"
    );
    assert.strictEqual(
      cleanupRequests.length,
      1,
      "and removes the link from its origin section"
    );
    const links = cleanupRequests[0].links;
    const removed = links.find((link) => `${link.id}` === "901");
    const kept = links.find((link) => `${link.id}` === "902");
    assert.strictEqual(removed._destroy, "1", "the moved link is destroyed");
    assert.strictEqual(kept._destroy, undefined, "its sibling is kept");
  });

  test("cancelling the split-out leaves the origin untouched", async function (assert) {
    await visit("/");

    await dragRowToRevealedZone();
    assert.dom(".sidebar-section-form-modal").exists("the create form opens");

    await click(".d-modal .modal-close");

    assert.strictEqual(createRequests.length, 0, "nothing was created");
    assert.strictEqual(cleanupRequests.length, 0, "nothing was removed");
    assert
      .dom(`${READING} [data-link-name="Existing link"]`)
      .exists("the link stays where it was");
  });
});
