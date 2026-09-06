import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const RELEASE_SITE_URL = "https://releases.discourse.org/";

acceptance("Admin - What's New", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/whats-new.json", () => {
      return helper.response(500, {
        errors: ["Internal Server Error"],
      });
    });
  });

  test("it shows a feed error when loading fails", async function (assert) {
    await visit("/admin/whats-new");

    assert.dom(".admin-config-area-empty-list").exists();
    assert
      .dom(`.admin-config-area-empty-list a[href="${RELEASE_SITE_URL}"]`)
      .exists();
  });
});

acceptance("Admin - What's New - anchors and scroll", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/whats-new.json", () => {
      return helper.response({
        new_features: [
          {
            id: 1,
            title: "New color palettes",
            description: "New light and dark color palettes.",
            created_at: "2021-01-18T19:59:29.666Z",
          },
          {
            id: 2,
            title: "Enable new editor",
            description: "The new rich text editor.",
            upcoming_change_setting_name: "enable_new_editor",
            created_at: "2021-02-18T19:59:29.666Z",
          },
        ],
        release_notes_link: RELEASE_SITE_URL,
      });
    });
  });

  test("each item has an id anchor", async function (assert) {
    await visit("/admin/whats-new");

    assert
      .dom("#new-color-palettes")
      .exists("regular items are anchored by their dasherized title");
    assert
      .dom("#upcoming-change-enable_new_editor")
      .exists("upcoming change items are anchored by their setting name");
  });

  test("scrolls to the targeted upcoming change", async function (assert) {
    const scrollIntoView = sinon.stub(HTMLElement.prototype, "scrollIntoView");

    await visit("/admin/whats-new?scrollTo=enable_new_editor");

    assert.true(
      scrollIntoView
        .getCalls()
        .some(
          (call) => call.thisValue.id === "upcoming-change-enable_new_editor"
        ),
      "scrolls the targeted change into view"
    );
  });
});
