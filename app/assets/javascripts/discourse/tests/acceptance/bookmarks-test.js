import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import {
  acceptance,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";

async function openBookmarkModal() {
  if (exists(".topic-post:first-child button.show-more-actions")) {
    await click(".topic-post:first-child button.show-more-actions");
  }
  await click(".topic-post:first-child button.bookmark");
}

async function openEditBookmarkModal() {
  await click(".topic-post:first-child button.bookmarked");
}

acceptance("Bookmarking", function (needs) {
  needs.user();
  let steps = [];

  needs.hooks.beforeEach(() => (steps = []));

  needs.pretender((server, helper) => {
    function handleRequest(request) {
      const data = helper.parsePostData(request.requestBody);
      steps.push(data.reminder_type || "none");
      return helper.response({ id: 999, success: "OK" });
    }
    server.post("/bookmarks", handleRequest);
    server.put("/bookmarks/999", handleRequest);
    server.delete("/bookmarks/999", () =>
      helper.response({ success: "OK", topic_bookmarked: false })
    );
  });

  test("Bookmarks modal opening", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal();
    assert.ok(
      exists("#bookmark-reminder-modal"),
      "it shows the bookmark modal"
    );
  });

  test("Bookmarks modal selecting reminder type", async (assert) => {
    await visit("/t/internationalization-localization/280");

    await openBookmarkModal();
    await click("#tap_tile_tomorrow");

    await openBookmarkModal();
    await click("#tap_tile_start_of_next_business_week");

    await openBookmarkModal();
    await click("#tap_tile_next_week");

    await openBookmarkModal();
    await click("#tap_tile_next_month");

    await openBookmarkModal();
    await click("#tap_tile_custom");
    assert.ok(exists("#tap_tile_custom.active"), "it selects custom");
    assert.ok(exists(".tap-tile-date-input"), "it shows the custom date input");
    assert.ok(exists(".tap-tile-time-input"), "it shows the custom time input");
    await click("#save-bookmark");

    assert.deepEqual(steps, [
      "tomorrow",
      "start_of_next_business_week",
      "next_week",
      "next_month",
      "custom",
    ]);
  });

  test("Saving a bookmark with a reminder", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal();
    await fillIn("input#bookmark-name", "Check this out later");
    await click("#tap_tile_tomorrow");

    assert.ok(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "it shows the bookmarked icon on the post"
    );
    assert.ok(
      exists(
        ".topic-post:first-child button.bookmark.bookmarked > .d-icon-discourse-bookmark-clock"
      ),
      "it shows the bookmark clock icon because of the reminder"
    );
    assert.deepEqual(steps, ["tomorrow"]);
  });

  test("Opening the options panel and remembering the option", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal();
    await click(".bookmark-options-button");
    assert.ok(
      exists(".bookmark-options-panel"),
      "it should open the options panel"
    );
    await selectKit(".bookmark-option-selector").expand();
    await selectKit(".bookmark-option-selector").selectRowByValue(1);
    await click("#save-bookmark");
    await openEditBookmarkModal();

    assert.ok(
      exists(".bookmark-options-panel"),
      "it should reopen the options panel"
    );
    assert.equal(selectKit(".bookmark-option-selector").header().value(), 1);
    assert.deepEqual(steps, ["none"]);
  });

  test("Saving a bookmark with no reminder or name", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal();
    await click("#save-bookmark");

    assert.ok(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "it shows the bookmarked icon on the post"
    );
    assert.not(
      exists(
        ".topic-post:first-child button.bookmark.bookmarked > .d-icon-discourse-bookmark-clock"
      ),
      "it shows the regular bookmark active icon"
    );
    assert.deepEqual(steps, ["none"]);
  });

  test("Deleting a bookmark with a reminder", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal();
    await click("#tap_tile_tomorrow");

    assert.deepEqual(steps, ["tomorrow"]);

    await openEditBookmarkModal();

    assert.ok(
      exists("#bookmark-reminder-modal"),
      "it shows the bookmark modal"
    );

    await click("#delete-bookmark");

    assert.ok(exists(".bootbox.modal"), "it asks for delete confirmation");
    assert.ok(
      find(".bootbox.modal")
        .text()
        .includes(I18n.t("bookmarks.confirm_delete")),
      "it shows delete confirmation message"
    );

    await click(".bootbox.modal .btn-primary");

    assert.not(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "it no longer shows the bookmarked icon on the post after bookmark is deleted"
    );
  });

  test("Cancelling saving a bookmark", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal();
    await click(".d-modal-cancel");
    assert.not(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "it does not show the bookmarked icon on the post because it is not saved"
    );
  });

  test("Editing a bookmark", async (assert) => {
    await visit("/t/internationalization-localization/280");
    let now = moment.tz(loggedInUser().resolvedTimezone(loggedInUser()));
    let tomorrow = now.add(1, "day").format("YYYY-MM-DD");
    await openBookmarkModal();
    await fillIn("input#bookmark-name", "Test name");
    await click("#tap_tile_tomorrow");

    await openEditBookmarkModal();
    assert.equal(
      find("#bookmark-name").val(),
      "Test name",
      "it should prefill the bookmark name"
    );
    assert.equal(
      find("#bookmark-custom-date > input").val(),
      tomorrow,
      "it should prefill the bookmark date"
    );
    assert.equal(
      find("#bookmark-custom-time").val(),
      "08:00",
      "it should prefill the bookmark time"
    );
    assert.deepEqual(steps, ["tomorrow"]);
  });
});
