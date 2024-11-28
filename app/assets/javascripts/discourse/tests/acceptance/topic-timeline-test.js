import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Glimmer Topic Timeline", function (needs) {
  needs.user({
    admin: true,
  });
  needs.pretender((server, helper) => {
    server.get("/t/129.json", () => {
      return helper.response({
        post_stream: {
          posts: [
            {
              id: 132,
              name: null,
              username: "foo",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
              created_at: "2020-07-08T15:03:53.166Z",
              cooked: "<p>Deleted post</p>",
              post_number: 1,
              post_type: 1,
              updated_at: "2020-07-08T15:04:33.425Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              incoming_link_count: 0,
              reads: 1,
              readers_count: 0,
              score: 0,
              yours: true,
              topic_id: 129,
              topic_slug: "deleted-topic-with-whisper-post",
              display_username: null,
              primary_group_name: null,
              flair_name: null,
              flair_url: null,
              flair_bg_color: null,
              flair_color: null,
              version: 1,
              can_edit: true,
              can_delete: false,
              can_recover: true,
              can_wiki: true,
              read: true,
              user_title: null,
              bookmarked: false,
              bookmarks: [],
              actions_summary: [
                {
                  id: 3,
                  can_act: true,
                },
                {
                  id: 4,
                  can_act: true,
                },
                {
                  id: 8,
                  can_act: true,
                },
                {
                  id: 7,
                  can_act: true,
                },
              ],
              moderator: false,
              admin: true,
              staff: true,
              user_id: 7,
              hidden: false,
              trust_level: 4,
              deleted_at: "2020-07-08T15:04:37.544Z",
              deleted_by: {
                id: 7,
                username: "foo",
                name: null,
                avatar_template:
                  "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
              },
              user_deleted: false,
              edit_reason: null,
              can_view_edit_history: true,
              wiki: false,
              reviewable_id: 0,
              reviewable_score_count: 0,
              reviewable_score_pending_count: 0,
            },
            {
              id: 133,
              name: null,
              username: "foo",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
              created_at: "2020-07-08T15:04:23.190Z",
              cooked: "<p>Whisper post</p>",
              post_number: 2,
              post_type: 4,
              updated_at: "2020-07-08T15:04:23.190Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              incoming_link_count: 0,
              reads: 1,
              readers_count: 0,
              score: 0,
              yours: true,
              topic_id: 129,
              topic_slug: "deleted-topic-with-whisper-post",
              display_username: null,
              primary_group_name: null,
              flair_name: null,
              flair_url: null,
              flair_bg_color: null,
              flair_color: null,
              version: 1,
              can_edit: true,
              can_delete: true,
              can_recover: false,
              can_wiki: true,
              read: true,
              user_title: null,
              bookmarked: false,
              bookmarks: [],
              actions_summary: [
                {
                  id: 3,
                  can_act: true,
                },
                {
                  id: 4,
                  can_act: true,
                },
                {
                  id: 8,
                  can_act: true,
                },
                {
                  id: 7,
                  can_act: true,
                },
              ],
              moderator: false,
              admin: true,
              staff: true,
              user_id: 7,
              hidden: false,
              trust_level: 4,
              deleted_at: null,
              user_deleted: false,
              edit_reason: null,
              can_view_edit_history: true,
              wiki: false,
              reviewable_id: 0,
              reviewable_score_count: 0,
              reviewable_score_pending_count: 0,
            },
          ],
          stream: [132, 133],
        },
        timeline_lookup: [[1, 0]],
        suggested_topics: [
          {
            id: 7,
            title: "Welcome to Discourse",
            fancy_title: "Welcome to Discourse",
            slug: "welcome-to-discourse",
            posts_count: 1,
            reply_count: 0,
            highest_post_number: 1,
            image_url: null,
            created_at: "2020-07-08T14:56:57.424Z",
            last_posted_at: "2020-07-08T14:56:57.488Z",
            bumped: true,
            bumped_at: "2020-07-08T14:56:57.488Z",
            archetype: "regular",
            unseen: false,
            pinned: true,
            unpinned: null,
            excerpt:
              "The first paragraph of this pinned topic will be visible as a welcome message to all new visitors on your homepage. It’s important! \nEdit this into a brief description of your community: \n\nWho is it for?\nWhat can they fi&hellip;",
            visible: true,
            closed: false,
            archived: false,
            bookmarked: null,
            liked: null,
            tags: [],
            like_count: 0,
            views: 0,
            category_id: 1,
            featured_link: null,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: -1,
                  username: "system",
                  name: "system",
                  avatar_template: "/images/discourse-logo-sketch-small.png",
                },
              },
            ],
          },
        ],
        tags: [],
        id: 129,
        title: "Deleted topic with whisper post",
        fancy_title: "Deleted topic with whisper post",
        posts_count: 0,
        created_at: "2020-07-08T15:03:53.045Z",
        views: 1,
        reply_count: 0,
        like_count: 0,
        last_posted_at: null,
        visible: true,
        closed: false,
        archived: false,
        has_summary: false,
        archetype: "regular",
        slug: "deleted-topic-with-whisper-post",
        category_id: 1,
        word_count: 8,
        deleted_at: "2020-07-08T15:04:37.580Z",
        user_id: 7,
        featured_link: null,
        pinned_globally: false,
        pinned_at: null,
        pinned_until: null,
        image_url: null,
        slow_mode_seconds: 0,
        draft: null,
        draft_key: "topic_129",
        draft_sequence: 5,
        posted: true,
        unpinned: null,
        pinned: false,
        current_post_number: 1,
        highest_post_number: 2,
        last_read_post_number: 0,
        last_read_post_id: null,
        deleted_by: {
          id: 7,
          username: "foo",
          name: null,
          avatar_template: "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
        },
        has_deleted: false,
        actions_summary: [
          {
            id: 4,
            count: 0,
            hidden: false,
            can_act: true,
          },
          {
            id: 8,
            count: 0,
            hidden: false,
            can_act: true,
          },
          {
            id: 7,
            count: 0,
            hidden: false,
            can_act: true,
          },
        ],
        chunk_size: 20,
        bookmarked: false,
        bookmarks: [],
        topic_timer: null,
        message_bus_last_id: 5,
        participant_count: 1,
        show_read_indicator: false,
        thumbnails: null,
        slow_mode_enabled_until: null,
        details: {
          can_edit: true,
          notification_level: 3,
          notifications_reason_id: 1,
          can_move_posts: true,
          can_recover: true,
          can_remove_allowed_users: true,
          can_invite_to: true,
          can_invite_via_email: true,
          can_reply_as_new_topic: true,
          can_flag_topic: true,
          can_review_topic: true,
          can_close_topic: true,
          can_archive_topic: true,
          can_split_merge_topic: true,
          can_edit_staff_notes: true,
          can_toggle_topic_visibility: true,
          can_pin_unpin_topic: true,
          can_moderate_category: true,
          can_remove_self_id: 7,
          participants: [
            {
              id: 7,
              username: "foo",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
              post_count: 1,
              primary_group_name: null,
              flair_name: null,
              flair_url: null,
              flair_color: null,
              flair_bg_color: null,
              admin: true,
              trust_level: 4,
            },
          ],
          created_by: {
            id: 7,
            username: "foo",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
          },
          last_poster: {
            id: 7,
            username: "foo",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
          },
        },
      });
    });
  });

  test("has a topic admin menu", async function (assert) {
    await visit("/t/internationalization-localization");
    assert
      .dom(".timeline-controls .topic-admin-menu-button")
      .exists("admin menu is present");
  });

  test("has a reply-to-post button", async function (assert) {
    await visit("/t/internationalization-localization");
    assert
      .dom(".timeline-footer-controls .reply-to-post")
      .exists("reply to post button is present");
  });

  test("has a topic notification button", async function (assert) {
    await visit("/t/internationalization-localization");
    assert
      .dom(".timeline-footer-controls .topic-notifications-button")
      .exists("topic notifications button is present");
  });

  test("Shows dates of first and last posts", async function (assert) {
    await visit("/t/deleted-topic-with-whisper-post/129");
    assert.dom(".timeline-date-wrapper .now-date").hasText("Jul 2020");
  });

  test("selecting start-date navigates you to the first post", async function (assert) {
    await visit("/t/internationalization-localization/280/2");
    await click(".timeline-date-wrapper .start-date");
    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280/1",
      "navigates to the first post"
    );
  });

  test("selecting now-date navigates you to the last post", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click(".timeline-date-wrapper .now-date");
    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280/11",
      "navigates to the latest post"
    );
  });

  test("clicking the timeline padding updates the position", async function (assert) {
    await visit("/t/internationalization-localization/280/2");
    await click(".timeline-scrollarea .timeline-padding");
    assert.false(
      currentURL().includes("/280/2"),
      "The position of the currently viewed post has been updated from it's initial position"
    );
  });
});
