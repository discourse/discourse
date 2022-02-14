import {
  acceptance,
  exists,
  loggedInUser,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import I18n from "I18n";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import { cloneJSON } from "discourse-common/lib/object";

async function openBookmarkModal(postNumber = 1) {
  if (exists(`#post_${postNumber} button.show-more-actions`)) {
    await click(`#post_${postNumber} button.show-more-actions`);
  }
  await click(`#post_${postNumber} button.bookmark`);
}

async function openEditBookmarkModal() {
  await click(".topic-post:first-child button.bookmarked");
}

async function testTopicLevelBookmarkButtonIcon(assert, postNumber) {
  const iconWithoutClock = "d-icon-bookmark";
  const iconWithClock = "d-icon-discourse-bookmark-clock";

  await visit("/t/internationalization-localization/280");
  assert.ok(
    query("#topic-footer-button-bookmark svg").classList.contains(
      iconWithoutClock
    ),
    "Shows an icon without a clock when there is no a bookmark"
  );

  await openBookmarkModal(postNumber);
  await click("#save-bookmark");

  assert.ok(
    query("#topic-footer-button-bookmark svg").classList.contains(
      iconWithoutClock
    ),
    "Shows an icon without a clock when there is a bookmark without a reminder"
  );

  await openBookmarkModal(postNumber);
  await click("#tap_tile_tomorrow");

  assert.ok(
    query("#topic-footer-button-bookmark svg").classList.contains(
      iconWithClock
    ),
    "Shows an icon with a clock when there is a bookmark with a reminder"
  );
}

acceptance("Bookmarking", function (needs) {
  needs.user();

  const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
  topicResponse.post_stream.posts[0].cooked += `<span data-date="2036-01-15" data-time="00:35:00" class="discourse-local-date cooked-date past" data-timezone="Europe/London">
  <span>
    <svg class="fa d-icon d-icon-globe-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
      <use href="#globe-americas"></use>
    </svg>
    <span class="relative-time">January 15, 2036 12:35 AM</span>
  </span>
</span>`;

  topicResponse.post_stream.posts[1].cooked += `<span data-date="2021-01-15" data-time="00:35:00" class="discourse-local-date cooked-date past" data-timezone="Europe/London">
  <span>
    <svg class="fa d-icon d-icon-globe-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
      <use href="#globe-americas"></use>
    </svg>
    <span class="relative-time">Today 10:30 AM</span>
  </span>
</span>`;

  needs.pretender((server, helper) => {
    function handleRequest(request) {
      const data = helper.parsePostData(request.requestBody);

      if (data.post_id === "398") {
        if (data.for_topic === "true") {
          return helper.response({ id: 3, success: "OK" });
        } else {
          return helper.response({ id: 1, success: "OK" });
        }
      } else if (data.post_id === "419") {
        return helper.response({ id: 2, success: "OK" });
      } else {
        throw new Error("Pretender: unknown post_id");
      }
    }
    server.post("/bookmarks", handleRequest);
    server.put("/bookmarks/1", handleRequest);
    server.put("/bookmarks/2", handleRequest);
    server.put("/bookmarks/3", handleRequest);
    server.delete("/bookmarks/1", () =>
      helper.response({ success: "OK", topic_bookmarked: false })
    );
    server.get("/t/280.json", () => helper.response(topicResponse));
  });

  test("Bookmarks modal opening", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal();
    assert.ok(
      exists("#bookmark-reminder-modal"),
      "it shows the bookmark modal"
    );
  });

  test("Bookmarks modal selecting reminder type", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await openBookmarkModal();
    await click("#tap_tile_tomorrow");

    await openBookmarkModal();
    await click("#tap_tile_start_of_next_business_week");

    await openBookmarkModal();
    await click("#tap_tile_next_month");

    await openBookmarkModal();
    await click("#tap_tile_custom");
    assert.ok(exists("#tap_tile_custom.active"), "it selects custom");
    assert.ok(exists(".tap-tile-date-input"), "it shows the custom date input");
    assert.ok(exists(".tap-tile-time-input"), "it shows the custom time input");
    await click("#save-bookmark");
  });

  test("Saving a bookmark with a reminder", async function (assert) {
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
  });

  test("Opening the options panel and remembering the option", async function (assert) {
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
    assert.strictEqual(
      selectKit(".bookmark-option-selector").header().value(),
      "1"
    );
  });

  test("Saving a bookmark with no reminder or name", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal();
    await click("#save-bookmark");

    assert.ok(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "it shows the bookmarked icon on the post"
    );
    assert.notOk(
      exists(
        ".topic-post:first-child button.bookmark.bookmarked > .d-icon-discourse-bookmark-clock"
      ),
      "it shows the regular bookmark active icon"
    );
  });

  test("Deleting a bookmark with a reminder", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal();
    await click("#tap_tile_tomorrow");

    await openEditBookmarkModal();

    assert.ok(
      exists("#bookmark-reminder-modal"),
      "it shows the bookmark modal"
    );

    await click("#delete-bookmark");

    assert.ok(exists(".bootbox.modal"), "it asks for delete confirmation");
    assert.ok(
      queryAll(".bootbox.modal")
        .text()
        .includes(I18n.t("bookmarks.confirm_delete")),
      "it shows delete confirmation message"
    );

    await click(".bootbox.modal .btn-primary");

    assert.notOk(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "it no longer shows the bookmarked icon on the post after bookmark is deleted"
    );
  });

  test("Cancelling saving a bookmark", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal();
    await click(".d-modal-cancel");
    assert.notOk(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "it does not show the bookmarked icon on the post because it is not saved"
    );
  });

  test("Editing a bookmark", async function (assert) {
    await visit("/t/internationalization-localization/280");
    let now = moment.tz(loggedInUser().resolvedTimezone(loggedInUser()));
    let tomorrow = now.add(1, "day").format("YYYY-MM-DD");
    await openBookmarkModal();
    await fillIn("input#bookmark-name", "Test name");
    await click("#tap_tile_tomorrow");

    await openEditBookmarkModal();
    assert.strictEqual(
      queryAll("#bookmark-name").val(),
      "Test name",
      "it should prefill the bookmark name"
    );
    assert.strictEqual(
      queryAll("#custom-date > input").val(),
      tomorrow,
      "it should prefill the bookmark date"
    );
    assert.strictEqual(
      queryAll("#custom-time").val(),
      "08:00",
      "it should prefill the bookmark time"
    );
  });

  test("Using a post date for the reminder date", async function (assert) {
    await visit("/t/internationalization-localization/280");
    let postDate = moment.tz(
      "2036-01-15",
      loggedInUser().resolvedTimezone(loggedInUser())
    );
    let postDateFormatted = postDate.format("YYYY-MM-DD");
    await openBookmarkModal();
    await fillIn("input#bookmark-name", "Test name");
    await click("#tap_tile_post_local_date");

    await openEditBookmarkModal();
    assert.strictEqual(
      queryAll("#bookmark-name").val(),
      "Test name",
      "it should prefill the bookmark name"
    );
    assert.strictEqual(
      queryAll("#custom-date > input").val(),
      postDateFormatted,
      "it should prefill the bookmark date"
    );
    assert.strictEqual(
      queryAll("#custom-time").val(),
      "10:35",
      "it should prefill the bookmark time"
    );
  });

  test("Cannot use the post date for a reminder when the post date is in the past", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal(2);
    assert.notOk(
      exists("#tap_tile_post_local_date"),
      "it does not show the local date tile"
    );
  });

  test("The topic level bookmark button deletes all bookmarks if several posts on the topic are bookmarked", async function (assert) {
    const yesButton = "a.btn-primary";
    const noButton = "a.btn-default";

    await visit("/t/internationalization-localization/280");
    await openBookmarkModal(1);
    await click("#save-bookmark");
    await openBookmarkModal(2);
    await click("#save-bookmark");

    assert.ok(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "the first bookmark is added"
    );
    assert.ok(
      exists(".topic-post:nth-child(3) button.bookmark.bookmarked"),
      "the second bookmark is added"
    );

    // open the modal and cancel deleting
    await click("#topic-footer-button-bookmark");
    await click(noButton);

    assert.ok(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "the first bookmark isn't deleted"
    );
    assert.ok(
      exists(".topic-post:nth-child(3) button.bookmark.bookmarked"),
      "the second bookmark isn't deleted"
    );

    // open the modal and accept deleting
    await click("#topic-footer-button-bookmark");
    await click(yesButton);

    assert.ok(
      !exists(".topic-post:first-child button.bookmark.bookmarked"),
      "the first bookmark is deleted"
    );
    assert.ok(
      !exists(".topic-post:nth-child(3) button.bookmark.bookmarked"),
      "the second bookmark is deleted"
    );
  });

  test("The topic level bookmark button opens the edit modal if only the first post on the topic is bookmarked", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal(1);
    await click("#save-bookmark");

    assert.strictEqual(
      query("#topic-footer-button-bookmark").innerText,
      I18n.t("bookmarked.edit_bookmark"),
      "A topic level bookmark button has a label 'Edit Bookmark'"
    );

    await click("#topic-footer-button-bookmark");

    assert.ok(
      exists("div.modal.bookmark-with-reminder"),
      "The edit modal is opened"
    );
  });

  test("Creating and editing a topic level bookmark", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-button-bookmark");

    assert.strictEqual(
      query("#discourse-modal-title").innerText,
      I18n.t("post.bookmarks.create_for_topic"),
      "The create modal says creating a topic bookmark"
    );

    await click("#save-bookmark");

    assert.notOk(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "the first post is not marked as being bookmarked"
    );

    assert.strictEqual(
      query("#topic-footer-button-bookmark").innerText,
      I18n.t("bookmarked.edit_bookmark"),
      "A topic level bookmark button has a label 'Edit Bookmark'"
    );

    await click("#topic-footer-button-bookmark");

    assert.strictEqual(
      query("#discourse-modal-title").innerText,
      I18n.t("post.bookmarks.edit_for_topic"),
      "The edit modal says editing a topic bookmark"
    );

    await fillIn("input#bookmark-name", "Test name");
    await click("#tap_tile_tomorrow");

    await click("#topic-footer-button-bookmark");

    assert.strictEqual(
      query("input#bookmark-name").value,
      "Test name",
      "The topic level bookmark editing preserves the values entered"
    );

    await click(".d-modal-cancel");

    await openBookmarkModal(1);
    await click("#save-bookmark");

    assert.ok(
      exists(".topic-post:first-child button.bookmark.bookmarked"),
      "the first post is bookmarked independently of the topic level bookmark"
    );

    // deleting all bookmarks in the topic
    assert.strictEqual(
      query("#topic-footer-button-bookmark").innerText,
      I18n.t("bookmarked.clear_bookmarks"),
      "the footer button says Clear Bookmarks because there is more than one"
    );
    await click("#topic-footer-button-bookmark");
    await click("a.btn-primary");

    assert.ok(
      !exists(".topic-post:first-child button.bookmark.bookmarked"),
      "the first post bookmark is deleted"
    );
    assert.strictEqual(
      query("#topic-footer-button-bookmark").innerText,
      I18n.t("bookmarked.title"),
      "the topic level bookmark is deleted"
    );
  });

  test("Deleting a topic_level bookmark with a reminder", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-button-bookmark");
    await click("#save-bookmark");

    assert.strictEqual(
      query("#topic-footer-button-bookmark").innerText,
      I18n.t("bookmarked.edit_bookmark"),
      "A topic level bookmark button has a label 'Edit Bookmark'"
    );

    await click("#topic-footer-button-bookmark");
    await fillIn("input#bookmark-name", "Test name");
    await click("#tap_tile_tomorrow");

    await click("#topic-footer-button-bookmark");
    await click("#delete-bookmark");

    assert.ok(exists(".bootbox.modal"), "it asks for delete confirmation");
    assert.ok(
      queryAll(".bootbox.modal")
        .text()
        .includes(I18n.t("bookmarks.confirm_delete")),
      "it shows delete confirmation message"
    );

    await click(".bootbox.modal .btn-primary");

    assert.strictEqual(
      query("#topic-footer-button-bookmark").innerText,
      I18n.t("bookmarked.title"),
      "A topic level bookmark button no longer says 'Edit Bookmark' after deletion"
    );
  });

  test("The topic level bookmark button opens the edit modal if only one post in the post stream is bookmarked", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openBookmarkModal(2);
    await click("#save-bookmark");

    assert.strictEqual(
      query("#topic-footer-button-bookmark").innerText,
      I18n.t("bookmarked.edit_bookmark"),
      "A topic level bookmark button has a label 'Edit Bookmark'"
    );

    await click("#topic-footer-button-bookmark");

    assert.ok(
      exists("div.modal.bookmark-with-reminder"),
      "The edit modal is opened"
    );
  });

  test("The topic level bookmark button shows an icon with a clock if there is a bookmark with a reminder on the first post", async function (assert) {
    const postNumber = 1;
    await testTopicLevelBookmarkButtonIcon(assert, postNumber);
  });

  test("The topic level bookmark button shows an icon with a clock if there is a bookmark with a reminder on the second post", async function (assert) {
    const postNumber = 2;
    await testTopicLevelBookmarkButtonIcon(assert, postNumber);
  });
});
