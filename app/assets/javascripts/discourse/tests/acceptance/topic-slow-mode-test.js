import {
  acceptance,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";

acceptance("Topic - Slow Mode - enabled", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("t/94.json", () => {
      const slowModeSeconds = 600;
      const slowModeEnabledUntil = "2040-01-01T04:00:00.000Z";

      return helper.response({
        post_stream: {
          posts: [
            {
              id: 226,
              name: null,
              username: "admin1",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/a/bbce88/{size}.png",
              created_at: "2021-05-17T08:55:24.811Z",
              cooked:
                "\u003cp\u003eA topic for testing slow mode.\u003c/p\u003e",
              post_number: 1,
              post_type: 1,
              updated_at: "2021-05-17T08:55:24.811Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              incoming_link_count: 0,
              reads: 1,
              readers_count: 0,
              score: 0,
              yours: true,
              topic_id: 94,
              topic_slug: "slow-mode-testing",
              display_username: null,
              primary_group_name: "team",
              primary_group_flair_url:
                "/uploads/default/original/1X/b33be9538df3547fcf9d1a51a4637d77392ac6f9.png",
              primary_group_flair_bg_color: "",
              primary_group_flair_color: "f5f2f5",
              version: 1,
              can_edit: true,
              can_delete: false,
              can_recover: false,
              can_wiki: true,
              read: true,
              user_title: null,
              bookmarked: false,
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
              user_id: 3,
              hidden: false,
              trust_level: 1,
              deleted_at: null,
              user_deleted: false,
              edit_reason: null,
              can_view_edit_history: true,
              wiki: false,
              reviewable_id: 0,
              reviewable_score_count: 0,
              reviewable_score_pending_count: 0,
              reactions: [],
              current_user_reaction: null,
              reaction_users_count: 0,
              current_user_used_main_reaction: false,
            },
          ],
          stream: [226],
        },
        timeline_lookup: [[1, 0]],
        suggested_topics: [
          {
            id: 20,
            title: "Polls testing. Just one poll in the comment",
            fancy_title: "Polls testing. Just one poll in the comment",
            slug: "polls-testing-just-one-poll-in-the-comment",
            posts_count: 3,
            reply_count: 1,
            highest_post_number: 3,
            image_url: null,
            created_at: "2021-01-21T09:21:35.102Z",
            last_posted_at: "2021-01-22T09:35:33.543Z",
            bumped: true,
            bumped_at: "2021-01-22T09:35:33.543Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 3,
            unread: 0,
            new_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 2,
            bookmarked: false,
            liked: false,
            tags: [],
            like_count: 1,
            views: 6,
            category_id: 1,
            featured_link: null,
            posters: [
              {
                extras: null,
                description: "Original Poster",
                user: {
                  id: 2,
                  username: "andrei1",
                  name: "andrei1",
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/ecd19e/{size}.png",
                },
              },
              {
                extras: "latest",
                description: "Most Recent Poster",
                user: {
                  id: 3,
                  username: "admin1",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/bbce88/{size}.png",
                },
              },
            ],
          },
          {
            id: 22,
            title: "Polls testing. The whole test",
            fancy_title: "Polls testing. The whole test",
            slug: "polls-testing-the-whole-test",
            posts_count: 14,
            reply_count: 10,
            highest_post_number: 14,
            image_url: null,
            created_at: "2021-01-21T09:55:20.135Z",
            last_posted_at: "2021-02-05T15:03:06.440Z",
            bumped: true,
            bumped_at: "2021-02-05T15:03:06.440Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 14,
            unread: 0,
            new_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 2,
            bookmarked: false,
            liked: true,
            tags: [],
            like_count: 14,
            views: 18,
            category_id: 1,
            featured_link: null,
            posters: [
              {
                extras: null,
                description: "Original Poster",
                user: {
                  id: 2,
                  username: "andrei1",
                  name: "andrei1",
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/ecd19e/{size}.png",
                },
              },
              {
                extras: "latest",
                description: "Most Recent Poster",
                user: {
                  id: 3,
                  username: "admin1",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/bbce88/{size}.png",
                },
              },
            ],
          },
          {
            id: 34,
            title: "The sandbox",
            fancy_title: "The sandbox",
            slug: "the-sandbox",
            posts_count: 2,
            reply_count: 0,
            highest_post_number: 2,
            image_url: null,
            created_at: "2021-02-22T09:15:57.042Z",
            last_posted_at: "2021-02-22T09:26:41.116Z",
            bumped: true,
            bumped_at: "2021-02-23T11:14:06.051Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 2,
            unread: 0,
            new_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 3,
            bookmarked: false,
            liked: false,
            tags: [],
            like_count: 0,
            views: 7,
            category_id: 1,
            featured_link: null,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 3,
                  username: "admin1",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/bbce88/{size}.png",
                },
              },
            ],
          },
          {
            id: 47,
            title: "No, it'll never do to ask them what the name of the",
            fancy_title:
              "No, it\u0026rsquo;ll never do to ask them what the name of the",
            slug: "no-itll-never-do-to-ask-them-what-the-name-of-the",
            posts_count: 14,
            reply_count: 1,
            highest_post_number: 15,
            image_url: null,
            created_at: "2021-04-13T11:33:24.475Z",
            last_posted_at: "2021-05-12T10:29:26.440Z",
            bumped: true,
            bumped_at: "2021-04-30T08:27:45.895Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 15,
            unread: 0,
            new_posts: 0,
            pinned: true,
            unpinned: null,
            excerpt:
              "one\ntwo \n\u0026amp; It’s an excerpt… A ‘topic’ excerpt… \u0026#39;\u0026#39;topic’There (were) doors all round the hall, but they were all locked and when Alice had learnt beautiful things this sort in her own mind as well as she passed it was all dark overhead before her was another long passage, or the fall was over. test test test test test Dinah’ll miss me very much to-night, I should think! test either the locks were too large, or the key was too small, but at any rate it would not open any of them. ’ and sometimes, \u0026#39;Do bats eat cats? test test However, on the second time round, she came upon a little door about fifteen inches high she tried to curtsey as she went down to look down and make out what she was dozing off, and had just begun to think about stopping herself before she found herself in a long, low hall, which was lit up by a row of lamps hanging from the roof. ha Would the fall was over. Please, Ma’am, is this New Zealand or Australia? ha ha There were doors all round the hall, but they were al\u0026hellip;",
            visible: true,
            closed: false,
            archived: false,
            notification_level: 2,
            bookmarked: false,
            liked: true,
            tags: [],
            like_count: 12,
            views: 39,
            category_id: 1,
            featured_link: null,
            posters: [
              {
                extras: null,
                description: "Original Poster",
                user: {
                  id: 2,
                  username: "andrei1",
                  name: "andrei1",
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/ecd19e/{size}.png",
                },
              },
              {
                extras: null,
                description: "Frequent Poster",
                user: {
                  id: 24,
                  username: "andrei26",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/839c29/{size}.png",
                },
              },
              {
                extras: null,
                description: "Frequent Poster",
                user: {
                  id: 29,
                  username: "andrei29",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/8797f3/{size}.png",
                },
              },
              {
                extras: null,
                description: "Frequent Poster",
                user: {
                  id: 28,
                  username: "andrei28",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/35a633/{size}.png",
                },
              },
              {
                extras: "latest",
                description: "Most Recent Poster",
                user: {
                  id: 3,
                  username: "admin1",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/bbce88/{size}.png",
                },
              },
            ],
          },
          {
            id: 38,
            title: "Suddenly she came upon a little door about fifteen",
            fancy_title: "Suddenly she came upon a little door about fifteen",
            slug: "suddenly-she-came-upon-a-little-door-about-fifteen",
            posts_count: 1,
            reply_count: 0,
            highest_post_number: 1,
            image_url: null,
            created_at: "2021-04-13T11:21:12.871Z",
            last_posted_at: "2021-04-13T11:21:13.066Z",
            bumped: true,
            bumped_at: "2021-04-13T11:21:13.066Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 1,
            unread: 0,
            new_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 1,
            bookmarked: false,
            liked: true,
            tags: [],
            like_count: 3,
            views: 3,
            category_id: 1,
            featured_link: null,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 2,
                  username: "andrei1",
                  name: "andrei1",
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/a/ecd19e/{size}.png",
                },
              },
            ],
          },
        ],
        tags: [],
        id: 94,
        title: "Slow mode testing",
        fancy_title: "Slow mode testing",
        posts_count: 1,
        created_at: "2021-05-17T08:55:24.570Z",
        views: 1,
        reply_count: 0,
        like_count: 0,
        last_posted_at: "2021-05-17T08:55:24.811Z",
        visible: true,
        closed: false,
        archived: false,
        has_summary: false,
        archetype: "regular",
        slug: "slow-mode-testing",
        category_id: 1,
        word_count: 6,
        deleted_at: null,
        user_id: 3,
        featured_link: null,
        pinned_globally: false,
        pinned_at: null,
        pinned_until: null,
        image_url: null,
        slow_mode_seconds: slowModeSeconds,
        draft: null,
        draft_key: "topic_94",
        draft_sequence: 0,
        posted: true,
        unpinned: null,
        pinned: false,
        current_post_number: 1,
        highest_post_number: 1,
        last_read_post_number: 1,
        last_read_post_id: 226,
        deleted_by: null,
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
        topic_timer: null,
        message_bus_last_id: 1,
        participant_count: 1,
        show_read_indicator: false,
        thumbnails: null,
        user_last_posted_at: "2021-05-17T08:55:24.843Z",
        slow_mode_enabled_until: slowModeEnabledUntil,
        valid_reactions: [
          "heart",
          "laughing",
          "open_mouth",
          "cry",
          "angry",
          "hugs",
          "heart_eyes",
        ],
        details: {
          can_edit: true,
          notification_level: 3,
          notifications_reason_id: 1,
          can_move_posts: true,
          can_delete: true,
          can_remove_allowed_users: true,
          can_invite_to: true,
          can_invite_via_email: true,
          can_create_post: true,
          can_reply_as_new_topic: true,
          can_flag_topic: true,
          can_convert_topic: true,
          can_review_topic: true,
          can_close_topic: true,
          can_archive_topic: true,
          can_split_merge_topic: true,
          can_edit_staff_notes: true,
          can_toggle_topic_visibility: true,
          can_pin_unpin_topic: true,
          can_moderate_category: true,
          can_remove_self_id: 3,
          participants: [
            {
              id: 3,
              username: "admin1",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/a/bbce88/{size}.png",
              post_count: 1,
              primary_group_name: "team",
              primary_group_flair_url:
                "/uploads/default/original/1X/b33be9538df3547fcf9d1a51a4637d77392ac6f9.png",
              primary_group_flair_color: "f5f2f5",
              primary_group_flair_bg_color: "",
              admin: true,
              trust_level: 1,
            },
          ],
          created_by: {
            id: 3,
            username: "admin1",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/a/bbce88/{size}.png",
          },
          last_poster: {
            id: 3,
            username: "admin1",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/a/bbce88/{size}.png",
          },
        },
      });
    });
  });

  test("the slow mode dialog loads settings of currently enabled slow mode ", async function (assert) {
    updateCurrentUser({ moderator: true });
    await visit("/t/slow-mode-testing/94");
    await click(".toggle-admin-menu");
    await click(".topic-admin-slow-mode button");

    await click(".future-date-input-selector-header");

    assert.equal(
      query(".future-date-input-selector-header").getAttribute("aria-expanded"),
      "true",
      "selector is expanded"
    );

    assert.equal(
      query("div.slow-mode-type span.name").innerText,
      I18n.t("topic.slow_mode_update.durations.10_minutes"),
      "slow mode interval is rendered"
    );

    // unfortunately we can't check exact date and time
    // but at least we can make sure that components for choosing date and time are rendered
    // (in case of inactive slow mode it would be only a combo box with text "Select a timeframe",
    // and date picker and time picker wouldn't be rendered)
    assert.equal(
      query("div.enabled-until span.name").innerText,
      I18n.t("topic.auto_update_input.pick_date_and_time"),
      "enabled until combobox is switched to the option Pick Date and Time"
    );

    assert.ok(exists("input.date-picker"), "date picker is rendered");
    assert.ok(exists("input.time-input"), "time picker is rendered");
  });
});
