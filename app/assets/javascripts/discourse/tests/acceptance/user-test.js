import EmberObject from "@ember/object";
import User from "discourse/models/user";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import sinon from "sinon";
import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("User Routes", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/u/eviltrout%2F..%2F..%2F.json", () =>
      helper.response(400, {})
    );
  });
  test("Invalid usernames", async function (assert) {
    try {
      await visit("/u/eviltrout%2F..%2F..%2F/summary");
    } catch (e) {
      if (e.message !== "TransitionAborted") {
        throw e;
      }
    }

    assert.strictEqual(currentRouteName(), "exception-unknown");
  });

  test("Unicode usernames", async function (assert) {
    await visit("/u/%E3%83%A9%E3%82%A4%E3%82%AA%E3%83%B3/summary");

    assert.strictEqual(currentRouteName(), "user.summary");
  });

  test("Invites", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    assert.ok($("body.user-invites-page").length, "has the body class");
  });

  test("Notifications", async function (assert) {
    await visit("/u/eviltrout/notifications");
    assert.ok($("body.user-notifications-page").length, "has the body class");

    const $links = queryAll(".item.notification a");

    assert.ok(
      $links[2].href.includes(
        "/u/eviltrout/notifications/likes-received?acting_username=aquaman"
      )
    );
  });

  test("Root URL - Viewing Self", async function (assert) {
    await visit("/u/eviltrout");
    assert.ok($("body.user-activity-page").length, "has the body class");
    assert.strictEqual(
      currentRouteName(),
      "userActivity.index",
      "it defaults to activity"
    );
    assert.ok(exists(".container.viewing-self"), "has the viewing-self class");
  });

  test("Viewing Summary", async function (assert) {
    await visit("/u/eviltrout/summary");

    assert.ok(exists(".replies-section li a"), "replies");
    assert.ok(exists(".topics-section li a"), "topics");
    assert.ok(exists(".links-section li a"), "links");
    assert.ok(exists(".replied-section .user-info"), "liked by");
    assert.ok(exists(".liked-by-section .user-info"), "liked by");
    assert.ok(exists(".liked-section .user-info"), "liked");
    assert.ok(exists(".badges-section .badge-card"), "badges");
    assert.ok(
      exists(".top-categories-section .category-link"),
      "top categories"
    );
  });

  test("Viewing Drafts", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.ok(exists(".user-stream"), "has drafts stream");
    assert.ok(
      exists(".user-stream .user-stream-item-draft-actions"),
      "has draft action buttons"
    );

    await click(".user-stream button.resume-draft:nth-of-type(1)");
    assert.ok(
      exists(".d-editor-input"),
      "composer is visible after resuming a draft"
    );
  });
});

acceptance(
  "User Routes - Periods in current user's username",
  function (needs) {
    needs.user({ username: "e.il.rout" });

    test("Periods in current user's username don't act like wildcards", async function (assert) {
      await visit("/u/eviltrout");
      assert.strictEqual(
        query(".user-profile-names .username").textContent.trim(),
        "eviltrout",
        "eviltrout profile is shown"
      );

      await visit("/u/e.il.rout");
      assert.strictEqual(
        query(".user-profile-names .username").textContent.trim(),
        "e.il.rout",
        "e.il.rout profile is shown"
      );
    });
  }
);

acceptance("User Routes - Moderator viewing warnings", function (needs) {
  needs.user({
    username: "notEviltrout",
    moderator: true,
    staff: true,
    admin: false,
  });

  test("Messages - Warnings", async function (assert) {
    await visit("/u/eviltrout/messages/warnings");
    assert.ok($("body.user-messages-page").length, "has the body class");
    assert.ok($("div.alert-info").length, "has the permissions alert");
  });
});

acceptance("User - Saving user options", function (needs) {
  needs.user({
    admin: false,
    moderator: false,
    username: "eviltrout",
    id: 1,
    user_option: EmberObject.create({}),
  });

  needs.settings({
    disable_mailing_list_mode: false,
  });

  needs.pretender((server, helper) => {
    server.put("/u/eviltrout.json", () => {
      return helper.response(200, { user: {} });
    });
  });

  test("saving user options", async function (assert) {
    const spy = sinon.spy(User.current(), "_saveUserData");

    await visit("/u/eviltrout/preferences/emails");
    await click(".pref-mailing-list-mode input[type='checkbox']");
    await click(".save-changes");

    assert.ok(
      spy.calledWithMatch({ mailing_list_mode: true }),
      "sends a PUT request to update the specified user option"
    );

    await selectKit("#user-email-messages-level").expand();
    await selectKit("#user-email-messages-level").selectRowByValue(2); // never option
    await click(".save-changes");

    assert.ok(
      spy.calledWithMatch({ email_messages_level: 2 }),
      "is able to save a different user_option on a subsequent request"
    );
  });
});
