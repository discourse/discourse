import { acceptance, loggedInUser } from "helpers/qunit-helpers";
import pretender from "helpers/create-pretender";

acceptance("Bookmarking", {
  loggedIn: true,

  beforeEach() {}
});

function mockSuccessfulBookmarkPost() {
  pretender.post("/bookmarks", () => [
    200,
    {
      "Content-Type": "application/json"
    },
    {
      id: 999,
      success: "OK"
    }
  ]);
}

async function openBookmarkModal() {
  await click(".topic-post:first-child button.show-more-actions");
  return await click(".topic-post:first-child button.bookmark");
}
async function openEditBookmarkModal() {
  return await click(".topic-post:first-child button.bookmarked");
}

test("Bookmarks modal opening", async assert => {
  await visit("/t/internationalization-localization/280");
  await openBookmarkModal();
  assert.ok(exists("#bookmark-reminder-modal"), "it shows the bookmark modal");
});

test("Bookmarks modal selecting reminder type", async assert => {
  await visit("/t/internationalization-localization/280");
  await openBookmarkModal();
  await click("#tap_tile_tomorrow");
  assert.ok(exists("#tap_tile_tomorrow.active"), "it selects tomorrow");
  await click("#tap_tile_start_of_next_business_week");
  assert.ok(
    exists("#tap_tile_start_of_next_business_week.active"),
    "it selects next monday"
  );
  await click("#tap_tile_next_week");
  assert.ok(exists("#tap_tile_next_week.active"), "it selects next week");
  await click("#tap_tile_next_month");
  assert.ok(exists("#tap_tile_next_month.active"), "it selects next month");
  await click("#tap_tile_custom");
  assert.ok(exists("#tap_tile_custom.active"), "it selects custom");
  assert.ok(exists(".tap-tile-date-input"), "it shows the custom date input");
  assert.ok(exists(".tap-tile-time-input"), "it shows the custom time input");
});

test("Saving a bookmark with a reminder", async assert => {
  mockSuccessfulBookmarkPost();
  await visit("/t/internationalization-localization/280");
  await openBookmarkModal();
  await fillIn("input#bookmark-name", "Check this out later");
  await click("#tap_tile_tomorrow");
  await click("#save-bookmark");
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
});

test("Saving a bookmark with no reminder or name", async assert => {
  mockSuccessfulBookmarkPost();
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
});

test("Deleting a bookmark with a reminder", async assert => {
  pretender.delete("/bookmarks/999", () => [
    200,
    {
      "Content-Type": "application/json"
    },
    {
      success: "OK",
      topic_bookmarked: false
    }
  ]);
  mockSuccessfulBookmarkPost();
  await visit("/t/internationalization-localization/280");
  await openBookmarkModal();
  await click("#tap_tile_tomorrow");
  await click("#save-bookmark");
  await openEditBookmarkModal();
  assert.ok(exists("#bookmark-reminder-modal"), "it shows the bookmark modal");
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

test("Cancelling saving a bookmark", async assert => {
  await visit("/t/internationalization-localization/280");
  await openBookmarkModal();
  await click(".d-modal-cancel");
  assert.not(
    exists(".topic-post:first-child button.bookmark.bookmarked"),
    "it does not show the bookmarked icon on the post because it is not saved"
  );
});

test("Editing a bookmark", async assert => {
  mockSuccessfulBookmarkPost();
  await visit("/t/internationalization-localization/280");
  let now = moment.tz(loggedInUser().resolvedTimezone());
  let tomorrow = now.add(1, "day").format("YYYY-MM-DD");
  await openBookmarkModal();
  await fillIn("input#bookmark-name", "Test name");
  await click("#tap_tile_tomorrow");
  await click("#save-bookmark");
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
});
