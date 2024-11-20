import {
  click,
  fillIn,
  triggerKeyEvent,
  visit,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import pretender, { response } from "../helpers/create-pretender";

acceptance("Composer - Messages", function (needs) {
  needs.user();

  let userNotSeenRequestCount = 0;

  needs.hooks.afterEach(() => {
    userNotSeenRequestCount = 0;
  });

  needs.pretender((server, helper) => {
    server.get("/composer_messages/user_not_seen_in_a_while", () => {
      userNotSeenRequestCount += 1;

      return helper.response({
        user_count: 1,
        usernames: ["charlie"],
        time_ago: "1 year ago",
      });
    });
  });

  test("Shows warning in composer if user hasn't been seen in a long time.", async function (assert) {
    await visit("/u/charlie");
    await click("button.compose-pm");

    assert
      .dom(".composer-popup")
      .doesNotExist("composer warning is not shown by default");

    await triggerKeyEvent(".d-editor-input", "keyup", "Space");

    assert.dom(".composer-popup").exists("shows composer warning message");

    assert.dom(".composer-popup").includesHtml(
      i18n("composer.user_not_seen_in_a_while.single", {
        usernames: ['<a class="mention" href="/u/charlie">@charlie</a>'],
        time_ago: "1 year ago",
      }),
      "warning message has correct body"
    );

    assert.strictEqual(
      userNotSeenRequestCount,
      1,
      "ne user not seen request is made to the server"
    );

    await triggerKeyEvent(".d-editor-input", "keyup", "Space");

    assert.strictEqual(
      userNotSeenRequestCount,
      1,
      "does not make additional user not seen request to the server if the recipient names are the same"
    );
  });
});

acceptance("Composer - Messages - Cannot see group", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/composer/mentions", () => {
      return helper.response({
        users: [],
        user_reasons: {},
        groups: {
          staff: { user_count: 30 },
          staff2: { user_count: 30, notified_count: 10 },
        },
        group_reasons: { staff: "not_allowed", staff2: "some_not_allowed" },
        max_users_notified_per_group_mention: 100,
      });
    });
  });

  test("Shows warning in composer if group hasn't been invited", async function (assert) {
    await visit("/t/130");
    await click("button.create");
    assert
      .dom(".composer-popup")
      .doesNotExist("composer warning is not shown by default");

    await fillIn(".d-editor-input", "Mention @staff");
    assert.dom(".composer-popup").exists("shows composer warning message");
    assert.dom(".composer-popup").includesHtml(
      i18n("composer.cannot_see_group_mention.not_allowed", {
        group: "staff",
      }),
      "warning message has correct body"
    );
  });

  test("Shows warning in composer if group hasn't been invited, but some members have access already", async function (assert) {
    await visit("/t/130");
    await click("button.create");
    assert
      .dom(".composer-popup")
      .doesNotExist("composer warning is not shown by default");

    await fillIn(".d-editor-input", "Mention @staff2");
    assert.dom(".composer-popup").exists("shows composer warning message");
    assert.dom(".composer-popup").includesHtml(
      i18n("composer.cannot_see_group_mention.some_not_allowed", {
        group: "staff2",
        count: 10,
      }),
      "warning message has correct body"
    );
  });
});

acceptance("Composer - Messages - Duplicate links", function (needs) {
  needs.user();

  test("Shows the warning", async function (assert) {
    pretender.get("/inline-onebox", () =>
      response({
        "inline-oneboxes": [],
      })
    );

    let receivedMessages = false;
    pretender.get("/composer_messages", () => {
      receivedMessages = true;
      return response({
        composer_messages: [],
        extras: {
          duplicate_lookup: {
            "test.localhost/t/testing-topic/123/4567": {
              domain: "test.localhost",
              username: "uwe_keim",
              posted_at: "2021-01-01T12:00:00.000Z",
              post_number: 1,
            },
          },
        },
      });
    });

    await visit("/t/internationalization-localization/280");
    await click("button.create");

    // Work around the lack of CSS transitions in the test env
    const event = new Event("transitionend");
    event.propertyName = "height";
    query("#reply-control").dispatchEvent(event);

    assert
      .dom(".composer-popup")
      .doesNotExist("composer warning is not shown by default");

    await waitUntil(() => receivedMessages);

    await fillIn(
      ".d-editor-input",
      "Here's a link: https://test.localhost/t/testing-topic/123/4567"
    );

    assert
      .dom(".composer-popup.duplicate-link-message")
      .exists("shows composer warning message");
  });
});

acceptance("Composer - Messages - Private Messages", function (needs) {
  needs.user({
    id: 32,
    username: "codinghorror",
  });

  needs.pretender((server, helper) => {
    server.get("/composer_messages/user_not_seen_in_a_while", () => {
      return helper.response({});
    });

    server.get("/u/search/users", () =>
      response({
        users: [
          {
            username: "codinghorror",
          },
          {
            username: "sam",
          },
        ],
      })
    );
  });

  test("Shows warning in the composer if the user is sending a message only to himself", async function (assert) {
    await visit("/new-message");

    const privateMessageUsers = selectKit("#private-message-users");

    assert.strictEqual(
      privateMessageUsers.header().value(),
      null,
      "target recipients are empty"
    );

    // Since we are activating the composer via the route /new-message, it was initialized with
    // default values. Filling the input before assigning the target recipient of the message
    // also ensures that the popup test is executed correctly when targetRecipients is empty.
    await fillIn("#reply-title", "Private message test title");
    await triggerKeyEvent(".d-editor-input", "keyup", "Space");

    assert
      .dom(".composer-popup")
      .doesNotExist(
        "composer warning is not shown if the target recipients are empty"
      );

    // filling the input with the username of the current user
    await privateMessageUsers.expand();
    await privateMessageUsers.fillInFilter("codinghorror");
    await privateMessageUsers.selectRowByValue("codinghorror");
    await privateMessageUsers.collapse();

    await triggerKeyEvent(".d-editor-input", "keyup", "Space");

    assert.dom(".composer-popup").exists("shows composer warning message");
    assert
      .dom(".composer-popup")
      .includesHtml(
        i18n("composer.yourself_confirm.title"),
        "warning message has correct title"
      );
    assert
      .dom(".composer-popup")
      .includesHtml(
        i18n("composer.yourself_confirm.body"),
        "warning message has correct body"
      );
  });

  test("Does not show a warning in the composer if the message is sent to other users", async function (assert) {
    await visit("/new-message");

    const privateMessageUsers = selectKit("#private-message-users");

    assert.strictEqual(
      privateMessageUsers.header().value(),
      null,
      "target recipients are empty"
    );

    // Since we are activating the composer via the route /new-message, it was initialized with
    // default values. Filling the input before assigning the target recipient of the message
    // also ensures that the popup test is executed correctly when targetRecipients is empty.
    await fillIn("#reply-title", "Private message test title");
    await triggerKeyEvent(".d-editor-input", "keyup", "Space");

    assert
      .dom(".composer-popup")
      .doesNotExist(
        "composer warning is not shown if the target recipients are empty"
      );

    // filling the input with the username of another user
    await privateMessageUsers.expand();
    await privateMessageUsers.fillInFilter("sam");
    await privateMessageUsers.selectRowByValue("sam");
    await privateMessageUsers.collapse();

    await triggerKeyEvent(".d-editor-input", "keyup", "Space");
    assert.dom(".composer-popup").doesNotExist("do not show it for other user");

    // filling the input with the username of the current user
    await privateMessageUsers.expand();
    await privateMessageUsers.fillInFilter("codinghorror");
    await privateMessageUsers.selectRowByValue("codinghorror");
    await privateMessageUsers.collapse();

    await triggerKeyEvent(".d-editor-input", "keyup", "Space");
    assert
      .dom(".composer-popup")
      .doesNotExist(
        "do not show it when the current user is just one of the target recipients"
      );
  });
});
