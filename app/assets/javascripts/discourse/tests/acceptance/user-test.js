import EmberObject from "@ember/object";
import {
  click,
  currentRouteName,
  currentURL,
  settled,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import {
  acceptance,
  publishToMessageBus,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "discourse-i18n";

/**
 * Workaround for https://github.com/tildeio/router.js/pull/335
 */
async function visitWithRedirects(url) {
  try {
    await visit(url);
  } catch (error) {
    const { message } = error;
    if (message !== "TransitionAborted") {
      throw error;
    }
    await settled();
  }
}

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
    assert.ok(
      document.body.classList.contains("user-invites-page"),
      "has the body class"
    );
  });

  test("Notifications", async function (assert) {
    await visit("/u/eviltrout/notifications");

    assert.ok(
      document.body.classList.contains("user-notifications-page"),
      "has the body class"
    );

    const $links = queryAll(".notification a");

    assert.ok(
      $links[2].href.includes("/u/eviltrout/notifications/likes-received")
    );

    updateCurrentUser({ moderator: true, admin: false });

    await visit("/u/charlie/summary");

    assert
      .dom(".user-nav > .user-nav__notifications")
      .doesNotExist("does not have the notifications tab");

    updateCurrentUser({ moderator: false, admin: true });

    await visit("/u/charlie/summary");

    assert
      .dom(".user-nav > .user-nav__notifications")
      .exists("has the notifications tab");
  });

  test("Root URL - Viewing Self", async function (assert) {
    await visit("/u/eviltrout");
    assert.ok(
      document.body.classList.contains("user-activity-page"),
      "has the body class"
    );
    assert.strictEqual(
      currentRouteName(),
      "userActivity.index",
      "it defaults to activity"
    );
    assert.dom(".container.viewing-self").exists("has the viewing-self class");
  });

  test("Viewing Drafts", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.dom(".user-stream").exists("has drafts stream");
    assert
      .dom(".user-stream .user-stream-item-draft-actions")
      .exists("has draft action buttons");

    await click(".user-stream button.resume-draft:nth-of-type(1)");
    assert
      .dom(".d-editor-input")
      .exists("composer is visible after resuming a draft");
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
        `eviltrout
                Robin Ward is an admin`,
        "eviltrout profile is shown"
      );

      await visit("/u/e.il.rout");
      assert.strictEqual(
        query(".user-profile-names .username").textContent.trim(),
        `e.il.rout
                Robin Ward is an admin`,
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
    assert.ok(
      document.body.classList.contains("user-messages-page"),
      "has the body class"
    );
    assert.dom("div.alert-info").exists("has the permissions alert");
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

  let putRequestData;

  needs.pretender((server, helper) => {
    server.put("/u/eviltrout.json", (request) => {
      putRequestData = helper.parsePostData(request.requestBody);
      return helper.response({ user: {} });
    });
  });

  needs.hooks.afterEach(() => {
    putRequestData = null;
  });

  test("saving user options", async function (assert) {
    await visit("/u/eviltrout/preferences/emails");
    await click(".pref-mailing-list-mode input[type='checkbox']");
    await click(".save-changes");

    assert.deepEqual(
      putRequestData,
      {
        digest_after_minutes: "10080",
        email_digests: "true",
        email_level: "1",
        email_messages_level: "0",
        mailing_list_mode: "true",
      },
      "sends a PUT request to update the specified user option"
    );

    await selectKit("#user-email-messages-level").expand();
    await selectKit("#user-email-messages-level").selectRowByValue(2); // never option
    await click(".save-changes");

    assert.deepEqual(
      putRequestData,
      {
        digest_after_minutes: "10080",
        email_digests: "true",
        email_level: "1",
        email_messages_level: "2",
        mailing_list_mode: "true",
      },
      "is able to save a different user_option on a subsequent request"
    );
  });
});

acceptance("User - Notification level dropdown visibility", function (needs) {
  needs.user({ username: "eviltrout", id: 1, ignored_ids: [] });

  needs.pretender((server, helper) => {
    server.get("/u/charlie.json", () => {
      const cloned = cloneJSON(userFixtures["/u/charlie.json"]);
      cloned.user.can_ignore_user = false;
      cloned.user.can_mute_user = false;
      return helper.response(200, cloned);
    });
  });

  test("Notification level button is not rendered for user who cannot mute or ignore another user", async function (assert) {
    await visit("/u/charlie");
    assert.dom(".user-notifications-dropdown").doesNotExist();
  });
});

acceptance(
  "User - Muting other user with notification level dropdown",
  function (needs) {
    needs.user({ username: "eviltrout", id: 1, ignored_ids: [] });

    needs.pretender((server, helper) => {
      server.get("/u/charlie.json", () => {
        const cloned = cloneJSON(userFixtures["/u/charlie.json"]);
        cloned.user.can_mute_user = true;
        return helper.response(200, cloned);
      });

      server.put("/u/charlie/notification_level.json", (request) => {
        let requestParams = new URLSearchParams(request.requestBody);
        // Ensure the correct `notification_level` param is sent to the server
        if (requestParams.get("notification_level") === "mute") {
          return helper.response(200, {});
        } else {
          return helper.response(422, {});
        }
      });
    });

    test("Notification level is set to normal and can be changed to muted", async function (assert) {
      await visit("/u/charlie");
      assert
        .dom(".user-notifications-dropdown")
        .exists("notification level dropdown is present");

      const dropdown = selectKit(".user-notifications-dropdown");
      await dropdown.expand();
      assert.strictEqual(dropdown.selectedRow().value(), "changeToNormal");

      await dropdown.selectRowByValue("changeToMuted");
      await dropdown.expand();
      assert.strictEqual(dropdown.selectedRow().value(), "changeToMuted");
    });
  }
);

acceptance(
  "User - Ignoring other user with notification level dropdown",
  function (needs) {
    needs.user({ username: "eviltrout", id: 1, ignored_ids: [] });

    needs.pretender((server, helper) => {
      server.get("/u/charlie.json", () => {
        const cloned = cloneJSON(userFixtures["/u/charlie.json"]);
        cloned.user.can_ignore_user = true;
        return helper.response(200, cloned);
      });

      server.put("/u/charlie/notification_level.json", (request) => {
        let requestParams = new URLSearchParams(request.requestBody);
        // Ensure the correct `notification_level` param is sent to the server
        if (requestParams.get("notification_level") === "ignore") {
          return helper.response(200, {});
        } else {
          return helper.response(422, {});
        }
      });
    });
    test("Notification level can be changed to ignored", async function (assert) {
      await visit("/u/charlie");
      assert
        .dom(".user-notifications-dropdown")
        .exists("notification level dropdown is present");

      const notificationLevelDropdown = selectKit(
        ".user-notifications-dropdown"
      );
      await notificationLevelDropdown.expand();
      assert.strictEqual(
        notificationLevelDropdown.selectedRow().value(),
        "changeToNormal"
      );

      await notificationLevelDropdown.selectRowByValue("changeToIgnored");
      assert.dom(".ignore-duration-with-username-modal").exists();

      const durationDropdown = selectKit(
        ".ignore-duration-with-username-modal .future-date-input-selector"
      );
      await durationDropdown.expand();
      await durationDropdown.selectRowByIndex(0);
      await click(".d-modal__footer .btn-primary");
      await notificationLevelDropdown.expand();
      assert.strictEqual(
        notificationLevelDropdown.selectedRow().value(),
        "changeToIgnored"
      );
    });
  }
);

acceptance("User - Invalid view_user_route setting", function (needs) {
  needs.settings({
    view_user_route: "X",
  });

  test("It defaults to summary", async function (assert) {
    await visit("/u/eviltrout");

    assert.strictEqual(currentRouteName(), "user.summary");
  });
});

acceptance("User - view_user_route setting set to activity", function (needs) {
  needs.settings({
    view_user_route: "activity",
  });

  test("It defaults to summary", async function (assert) {
    await visit("/u/eviltrout");

    assert.strictEqual(currentRouteName(), "userActivity.index");
  });
});

acceptance("User - Valid view_user_route setting default", function () {
  test("It defaults to summary", async function (assert) {
    await visit("/u/eviltrout");

    assert.strictEqual(currentRouteName(), "user.summary");
  });
});

acceptance("User - Logout", function (needs) {
  needs.user({ username: "eviltrout" });

  test("Dialog works", async function (assert) {
    await visit("/u/eviltrout");
    await publishToMessageBus("/logout/19");

    assert.dom(".dialog-body").exists();
    assert
      .dom(".dialog-footer .btn-default")
      .doesNotExist("no cancel button present");
    assert
      .dom(".dialog-footer .btn-primary")
      .hasText(I18n.t("home"), "primary dialog button is present");

    await click(".dialog-overlay");
  });
});

acceptance("User - /my/ shortcuts for logged-in users", function (needs) {
  needs.user({ username: "eviltrout" });

  test("Redirects correctly", async function (assert) {
    await visitWithRedirects("/my/activity");
    assert.strictEqual(currentURL(), "/u/eviltrout/activity");

    await visitWithRedirects("/my/preferences/account");
    assert.strictEqual(currentURL(), "/u/eviltrout/preferences/account");
  });
});

acceptance("User - /my/ shortcuts for anon users", function () {
  test("Redirects correctly", async function (assert) {
    await visitWithRedirects("/my/activity");
    assert.strictEqual(currentURL(), "/login-preferences");

    await visitWithRedirects("/my/preferences/account");
    assert.strictEqual(currentURL(), "/login-preferences");
  });
});
