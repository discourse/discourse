import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Discourse Reactions - Notifications", function (needs) {
  needs.user();

  needs.settings({
    discourse_reactions_enabled: true,
    discourse_reactions_enabled_reactions: "otter|open_mouth",
    discourse_reactions_reaction_for_like: "heart",
    discourse_reactions_like_icon: "heart",
  });

  needs.pretender((server, helper) => {
    server.get("/notifications", () => {
      return helper.response({
        notifications: [
          {
            id: 1334,
            user_id: 88,
            notification_type: 25,
            read: true,
            high_priority: false,
            created_at: "2022-08-18T13:00:11.166Z",
            post_number: 12,
            topic_id: 8432,
            fancy_title: "Topic with one reaction from a user",
            slug: "topic-with-one-reaction-from-a-user",
            data: {
              topic_title: "Topic with one reaction from a user",
              original_post_id: 3349,
              original_post_type: 1,
              original_username: "krus",
              revision_number: null,
              display_username: "krus",
              reaction_icon: "heart",
              previous_notification_id: 933,
              count: 1,
            },
          },
          {
            id: 842,
            user_id: 88,
            notification_type: 25,
            read: true,
            high_priority: false,
            created_at: "2021-08-19T23:00:11.166Z",
            post_number: 3,
            topic_id: 138,
            fancy_title: "Topic with 2 likes (total) from 2 users",
            slug: "topic-with-2-likes-total-from-2-users",
            data: {
              topic_title: "Topic with 2 likes (total) from 2 users",
              original_post_id: 443,
              original_post_type: 1,
              original_username: "jammed-radio",
              revision_number: null,
              display_username: "jammed-radio",
              previous_notification_id: 933,
              username2: "broken-radio",
              reaction_icon: "heart",
              count: 2,
            },
          },
          {
            id: 3843,
            user_id: 88,
            notification_type: 25,
            read: true,
            high_priority: false,
            created_at: "2021-08-19T23:00:11.166Z",
            post_number: 31,
            topic_id: 832,
            fancy_title: "Topic with likes from multiple users",
            slug: "topic-with-likes-from-multiple-users",
            data: {
              topic_title: "Topic with likes from multiple users",
              original_post_id: 903,
              original_post_type: 1,
              original_username: "jam-and-cheese",
              revision_number: null,
              display_username: "jam-and-cheese",
              previous_notification_id: 933,
              username2: "cheesy-monkey",
              reaction_icon: "heart",
              count: 3,
            },
          },
          {
            id: 2189,
            user_id: 88,
            notification_type: 25,
            read: true,
            high_priority: false,
            created_at: "2020-11-13T03:10:41.166Z",
            post_number: 31,
            topic_id: 913,
            fancy_title: "Topic with likes and reactions",
            slug: "topic-with-likes-and-reactions",
            data: {
              topic_title: "Topic with likes and reactions",
              original_post_id: 384,
              original_post_type: 1,
              original_username: "nuclear-reactor",
              revision_number: null,
              display_username: "nuclear-reactor",
              previous_notification_id: 933,
              username2: "solar-engine",
              count: 4,
            },
          },
          {
            id: 7731,
            user_id: 88,
            notification_type: 25,
            read: true,
            high_priority: false,
            created_at: "2022-07-18T10:00:11.186Z",
            post_number: null,
            topic_id: null,
            fancy_title: null,
            slug: null,
            data: {
              topic_title: "Double reactions on multiple posts from one user",
              original_post_id: 843,
              original_post_type: 1,
              original_username: "johnny",
              revision_number: null,
              display_username: "johnny",
              username: "johnny",
              consolidated: true,
              count: 2,
            },
          },
        ],
      });
    });
  });

  test("reaction notifications", async (assert) => {
    await visit("/");
    await click(".d-header-icons .current-user button");

    const notifications = queryAll(
      "#quick-access-all-notifications ul li.notification.reaction a"
    );

    assert.strictEqual(notifications.length, 5);

    assert.strictEqual(
      notifications[0].textContent.replaceAll(/\s+/g, " ").trim(),
      "krus Topic with one reaction from a user",
      "notification for one like from one user has the right content"
    );
    assert.ok(
      notifications[0].href.endsWith(
        "/t/topic-with-one-reaction-from-a-user/8432/12"
      ),
      "notification for one like from one user links to the topic"
    );
    assert.ok(
      notifications[0].querySelector(".d-icon-heart"),
      "notification for one like from one user has heart icon"
    );

    assert.strictEqual(
      notifications[1].textContent.replaceAll(/\s+/g, " ").trim(),
      `${i18n("notifications.reaction_2_users", {
        username: "jammed-radio",
        username2: "broken-radio",
      })} Topic with 2 likes (total) from 2 users`,
      "notification for 2 likes from 2 users has the right content"
    );
    assert.ok(
      notifications[1].href.endsWith(
        "/t/topic-with-2-likes-total-from-2-users/138/3"
      ),
      "notification for 2 likes from 2 users links to the topic"
    );
    assert.ok(
      notifications[1].querySelector(".d-icon-heart"),
      "notification for 2 likes from 2 users has the heart icon"
    );

    assert.strictEqual(
      notifications[2].textContent.replaceAll(/\s+/g, " ").trim(),
      `${i18n("notifications.reaction_multiple_users", {
        username: "jam-and-cheese",
        count: 2,
      })} Topic with likes from multiple users`,
      "notification for likes from 3 or more users has the right content"
    );
    assert.ok(
      notifications[2].href.endsWith(
        "/t/topic-with-likes-from-multiple-users/832/31"
      ),
      "notification for likes from 3 or more users links to the topic"
    );
    assert.ok(
      notifications[2].querySelector(".d-icon-heart"),
      "notification for 2 likes from 3 or more users has the heart icon"
    );

    assert.strictEqual(
      notifications[3].textContent.replaceAll(/\s+/g, " ").trim(),
      `${i18n("notifications.reaction_multiple_users", {
        username: "nuclear-reactor",
        count: 3,
      })} Topic with likes and reactions`,
      "notification for reactions from 3 or more users has the right content"
    );
    assert.ok(
      notifications[3].href.endsWith(
        "/t/topic-with-likes-and-reactions/913/31"
      ),
      "notification for reactions from 3 or more users links to the topic"
    );
    assert.ok(
      notifications[3].querySelector(".d-icon-discourse-emojis"),
      "notification for 2 reactions from 3 or more users has the emojis icon"
    );

    assert.strictEqual(
      notifications[4].textContent.replaceAll(/\s+/g, " ").trim(),
      `johnny ${i18n("notifications.reaction_1_user_multiple_posts", {
        count: 2,
      })}`,
      "notification for reactions from 1 users on multiple posts has the right content"
    );
    assert.ok(
      notifications[4].href.endsWith(
        "/u/eviltrout/notifications/reactions-received?acting_username=johnny&include_likes=true"
      ),
      "notification for reactions from 1 users on multiple posts links the reactions-received page of the user"
    );
    assert.ok(
      notifications[4].querySelector(".d-icon-discourse-emojis"),
      "notification for reactions from 1 users on multiple posts has the emojis icon"
    );
  });
});

acceptance(
  "Discourse Reactions - Notifications | Full Name Setting On",
  function (needs) {
    needs.user();

    needs.settings({
      discourse_reactions_enabled: true,
      discourse_reactions_enabled_reactions: "otter|open_mouth",
      discourse_reactions_reaction_for_like: "heart",
      discourse_reactions_like_icon: "heart",
      prioritize_full_name_in_ux: true,
    });

    needs.pretender((server, helper) => {
      server.get("/notifications", () => {
        return helper.response({
          notifications: [
            {
              id: 842,
              user_id: 88,
              notification_type: 25,
              read: true,
              high_priority: false,
              created_at: "2021-08-19T23:00:11.166Z",
              post_number: 3,
              topic_id: 138,
              fancy_title: "Topic with 2 likes (total) from 2 users",
              slug: "topic-with-2-likes-total-from-2-users",
              data: {
                topic_title: "Topic with 2 likes (total) from 2 users",
                original_post_id: 443,
                original_post_type: 1,
                original_username: "jammed-radio",
                revision_number: null,
                display_username: "jammed-radio",
                display_name: "Bruce Wayne I",
                previous_notification_id: 933,
                username2: "broken-radio",
                name2: "Brucer Wayner II",
                reaction_icon: "heart",
                count: 2,
              },
            },
            {
              id: 2189,
              user_id: 88,
              notification_type: 25,
              read: true,
              high_priority: false,
              created_at: "2020-11-13T03:10:41.166Z",
              post_number: 31,
              topic_id: 913,
              fancy_title: "Topic with likes and reactions",
              slug: "topic-with-likes-and-reactions",
              data: {
                topic_title: "Topic with likes and reactions",
                original_post_id: 384,
                original_post_type: 1,
                original_username: "nuclear-reactor",
                revision_number: null,
                display_username: "nuclear-reactor",
                display_name: "Monkey D. Luffy",
                previous_notification_id: 933,
                username2: "solar-engine",
                name2: "Roronoa Zoro",
                count: 4,
              },
            },
          ],
        });
      });
    });

    test("reaction notifications with full name site setting on", async function (assert) {
      await visit("/");
      await click(".d-header-icons .current-user button");

      assert
        .dom("li.notification.reaction:nth-child(1) a")
        .hasText(/Bruce Wayne I, Brucer Wayner II/);

      assert
        .dom("li.notification.reaction:nth-child(2) a")
        .hasText(/Monkey D. Luffy and 3 others/);
    });
  }
);
