import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import NotificationFixture from "../fixtures/notifications-fixtures";

function assignCurrentUserToTopic(needs) {
  needs.pretender((server, helper) => {
    server.get("/t/44.json", () => {
      let topic = cloneJSON(topicFixtures["/t/28830/1.json"]);
      topic["assigned_to_user"] = {
        username: "eviltrout",
        name: "Robin Ward",
        avatar_template:
          "/letter_avatar/eviltrout/{size}/3_f9720745f5ce6dfc2b5641fca999d934.png",
      };
      topic["assignment_note"] = "Shark Doododooo";
      topic["assignment_status"] = "New";
      topic["indirectly_assigned_to"] = {
        2: {
          assigned_to: {
            name: "Developers",
          },
          post_number: 2,
          assignment_note: '<script>alert("xss")</script>',
        },
      };
      return helper.response(topic);
    });

    server.get("/t/45.json", () => {
      let topic = cloneJSON(topicFixtures["/t/28830/1.json"]);
      topic["assigned_to_group"] = {
        name: "Developers",
      };
      return helper.response(topic);
    });

    server.get("/notifications", () => {
      return helper.response(
        NotificationFixture["/assign/notifications/eviltrout"]
      );
    });
  });
}

function assignNewUserToTopic(needs) {
  needs.pretender((server, helper) => {
    server.get("/t/44.json", () => {
      let topic = cloneJSON(topicFixtures["/t/28830/1.json"]);
      topic["assigned_to_user"] = {
        username: "isaacjanzen",
        name: "Isaac Janzen",
        avatar_template:
          "/letter_avatar/isaacjanzen/{size}/3_f9720745f5ce6dfc2b5641fca999d934.png",
      };
      topic["indirectly_assigned_to"] = {
        2: {
          assigned_to: {
            name: "Developers",
          },
          post_number: 2,
        },
      };
      return helper.response(topic);
    });

    server.get("/t/45.json", () => {
      let topic = cloneJSON(topicFixtures["/t/28830/1.json"]);
      topic["assigned_to_group"] = {
        name: "Developers",
      };
      return helper.response(topic);
    });
  });
}

acceptance(`Discourse Assign | Assigned topic`, function (needs) {
  needs.user();
  needs.settings({
    assign_enabled: true,
    tagging_enabled: true,
    assigns_user_url_path: "/",
    assigns_public: true,
    enable_assign_status: true,
  });

  assignCurrentUserToTopic(needs);

  test("Shows user assignment info", async function (assert) {
    updateCurrentUser({ can_assign: true });
    await visit("/t/assignment-topic/44");

    assert
      .dom("#topic-title .assigned-to")
      .hasText("eviltrout", "shows assignment in the header");

    assert
      .dom("#post_1 .assigned-to")
      .includesText(
        "Assigned topic to eviltrout",
        "shows assignment in the first post"
      );
    assert
      .dom("#post_1 .assigned-to")
      .includesText("#2 to Developers", "Also shows indirect assignments");
    assert.dom("#post_1 .assigned-to svg.d-icon-user-plus").exists();
    assert.dom("#post_1 .assigned-to a[href='/']").exists();
    assert
      .dom(".discourse-tags .assigned-to[href='/'] span")
      .hasAttribute("title", "Shark Doododooo", "shows topic assign notes");
    assert
      .dom(".discourse-tags .assigned-to[href='/']")
      .exists("header tag links to the user's assigned page");
    assert
      .dom(".discourse-tags .assigned-to[href='/p/2'] span")
      .hasAttribute(
        "title",
        '<script>alert("xss")</script>',
        "shows indirect assign notes"
      );
    assert
      .dom("#topic-footer-dropdown-reassign")
      .exists("shows reassign dropdown at the bottom of the topic");
  });

  test("Shows group assignment info", async function (assert) {
    updateCurrentUser({ can_assign: true });
    await visit("/t/assignment-topic/45");

    assert
      .dom("#topic-title .assigned-to")
      .hasText("Developers", "shows assignment in the header");
    assert
      .dom("#post_1 .assigned-to--group")
      .hasText(
        "Assigned topic to Developers",
        "shows assignment in the first post"
      );
    assert.dom("#post_1 .assigned-to svg.d-icon-group-plus").exists();
    assert
      .dom("#post_1 .assigned-to a[href='/g/Developers/assigned/everyone']")
      .exists();
    assert
      .dom(
        ".discourse-tags .assigned-to[href='/g/Developers/assigned/everyone']"
      )
      .exists("header tag links to the group's assigned page");
    assert
      .dom("#topic-footer-dropdown-reassign")
      .exists("shows reassign dropdown at the bottom of the topic");
  });

  test("User without assign ability cannot see footer button", async function (assert) {
    updateCurrentUser({
      can_assign: false,
      admin: false,
      moderator: false,
    });
    await visit("/t/assignment-topic/45");

    assert
      .dom("#topic-footer-dropdown-reassign")
      .doesNotExist(
        "does not show reassign dropdown at the bottom of the topic"
      );
  });

  test("Shows assignment notification", async function (assert) {
    updateCurrentUser({ can_assign: true });

    await visit("/u/eviltrout/notifications");

    assert
      .dom("section.user-content .user-notifications-list li.notification")
      .hasClass("assigned", "with correct assigned class");

    assert
      .dom("section.user-content .user-notifications-list li.notification a")
      .hasAttribute(
        "title",
        i18n("notifications.titles.assigned"),
        "with correct title"
      );
    assert
      .dom(
        "section.user-content .user-notifications-list li.notification svg use"
      )
      .hasAttribute("href", "#user-plus", "with correct icon");
  });
});

acceptance(`Discourse Assign | Reassign topic`, function (needs) {
  needs.user();
  needs.settings({
    assign_enabled: true,
    tagging_enabled: true,
    assigns_user_url_path: "/",
  });

  assignNewUserToTopic(needs);

  test("Reassign Footer dropdown contains reassign buttons", async function (assert) {
    updateCurrentUser({ can_assign: true });
    const menu = selectKit("#topic-footer-dropdown-reassign");

    await visit("/t/assignment-topic/44");
    await menu.expand();

    assert.true(menu.rowByValue("unassign").exists());
    assert.true(menu.rowByValue("reassign").exists());
    assert.true(menu.rowByValue("reassign-self").exists());
  });
});

acceptance(`Discourse Assign | Reassign topic | mobile`, function (needs) {
  needs.user();
  needs.mobileView();
  needs.settings({
    assign_enabled: true,
    tagging_enabled: true,
    assigns_user_url_path: "/",
  });

  assignNewUserToTopic(needs);

  test("Mobile Footer dropdown contains reassign buttons", async function (assert) {
    updateCurrentUser({ can_assign: true });

    await visit("/t/assignment-topic/44");
    await click(".topic-footer-mobile-dropdown-trigger");

    assert.dom("#topic-footer-button-unassign-mobile").exists();
    assert.dom("#topic-footer-button-reassign-self-mobile").exists();
    assert.dom("#topic-footer-button-reassign-mobile").exists();
  });
});

acceptance(`Discourse Assign | Reassign topic conditionals`, function (needs) {
  needs.user();
  needs.settings({
    assign_enabled: true,
    tagging_enabled: true,
    assigns_user_url_path: "/",
  });

  assignCurrentUserToTopic(needs);

  test("Reassign Footer dropdown won't display reassign-to-self button when already assigned to current user", async function (assert) {
    updateCurrentUser({ can_assign: true });
    const menu = selectKit("#topic-footer-dropdown-reassign");

    await visit("/t/assignment-topic/44");
    await menu.expand();

    assert.false(menu.rowByValue("reassign-self").exists());
  });
});

acceptance(`Discourse Assign | Assignee name XSS escaping`, function (needs) {
  const XSS_PAYLOAD = '<img src="xss-test">';

  needs.user();
  needs.settings({
    assign_enabled: true,
    tagging_enabled: true,
    assigns_user_url_path: "/",
    assigns_public: true,
    prioritize_full_name_in_ux: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/44.json", () => {
      let topic = cloneJSON(topicFixtures["/t/28830/1.json"]);
      topic["assigned_to_user"] = {
        username: "eviltrout",
        name: XSS_PAYLOAD,
        avatar_template:
          "/letter_avatar/eviltrout/{size}/3_f9720745f5ce6dfc2b5641fca999d934.png",
      };
      topic["indirectly_assigned_to"] = {};

      // Add a small action post with XSS payload in action_code_who
      const smallActionPost = {
        id: 999,
        username: "system",
        avatar_template: "/images/avatar.png",
        created_at: "2026-03-10T00:00:00.000Z",
        cooked: "",
        post_number: 3,
        post_type: 3,
        updated_at: "2026-03-10T00:00:00.000Z",
        yours: false,
        topic_id: topic.id,
        topic_slug: topic.slug,
        action_code: "assigned",
        action_code_who: XSS_PAYLOAD,
      };
      topic.post_stream.posts.push(smallActionPost);
      topic.post_stream.stream.push(999);

      return helper.response(topic);
    });

    server.get("/t/45.json", () => {
      let topic = cloneJSON(topicFixtures["/t/28830/1.json"]);
      topic["assigned_to_group"] = {
        name: XSS_PAYLOAD,
      };
      return helper.response(topic);
    });
  });

  test("escapes HTML in user assignee name on first post", async function (assert) {
    updateCurrentUser({ can_assign: true });
    await visit("/t/assignment-topic/44");

    assert
      .dom("#post_1 .assigned-to--user img[src='xss-test']")
      .doesNotExist("does not render injected img from user name");

    assert
      .dom("#post_1 .assigned-to--user")
      .includesText(XSS_PAYLOAD, "renders payload as escaped text");
  });

  test("escapes HTML in user assignee name in topic tag", async function (assert) {
    updateCurrentUser({ can_assign: true });
    await visit("/t/assignment-topic/44");

    assert
      .dom(".discourse-tags .assigned-to img[src='xss-test']")
      .doesNotExist("does not render injected img in topic tag");

    assert
      .dom(".discourse-tags .assigned-to span")
      .includesText(XSS_PAYLOAD, "renders payload as escaped text in tag");
  });

  test("escapes HTML in group assignee name on first post", async function (assert) {
    updateCurrentUser({ can_assign: true });
    await visit("/t/assignment-topic/45");

    assert
      .dom("#post_1 .assigned-to--group img[src='xss-test']")
      .doesNotExist("does not render injected img from group name");

    assert
      .dom("#post_1 .assigned-to--group")
      .includesText(XSS_PAYLOAD, "renders payload as escaped text");
  });

  test("escapes HTML in group assignee name in topic tag", async function (assert) {
    updateCurrentUser({ can_assign: true });
    await visit("/t/assignment-topic/45");

    assert
      .dom(".discourse-tags .assigned-to img[src='xss-test']")
      .doesNotExist("does not render injected img in topic tag");

    assert
      .dom(".discourse-tags .assigned-to span")
      .includesText(XSS_PAYLOAD, "renders payload as escaped text in tag");
  });

  test("escapes HTML in small action description", async function (assert) {
    updateCurrentUser({ can_assign: true });
    await visit("/t/assignment-topic/44");

    assert
      .dom(".small-action .small-action-desc img[src='xss-test']")
      .doesNotExist("does not render injected img in small action");
  });

  test("escapes HTML in topic-level unassign menu", async function (assert) {
    updateCurrentUser({ can_assign: true });
    const menu = selectKit("#topic-footer-dropdown-reassign");

    await visit("/t/assignment-topic/44");
    await menu.expand();

    assert
      .dom("#topic-footer-dropdown-reassign img[src='xss-test']")
      .doesNotExist("does not render injected img in unassign menu");
  });
});
