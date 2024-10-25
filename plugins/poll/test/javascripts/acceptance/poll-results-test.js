import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  count,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Poll results", function (needs) {
  needs.user();
  needs.settings({ poll_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/posts/by_number/134/1", () => {
      return helper.response({
        id: 156,
        name: null,
        username: "bianca",
        avatar_template: "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
        created_at: "2021-06-08T21:56:55.166Z",
        cooked:
          '\u003cdiv class="poll" data-poll-status="open" data-poll-public="true" data-poll-results="always" data-poll-charttype="bar" data-poll-type="regular" data-poll-name="poll"\u003e\n\u003cdiv\u003e\n\u003cdiv class="poll-container"\u003e\n\u003cul\u003e\n\u003cli data-poll-option-id="db753fe0bc4e72869ac1ad8765341764"\u003eOption \u003cspan class="hashtag"\u003e#1\u003c/span\u003e\n\u003c/li\u003e\n\u003cli data-poll-option-id="d8c22ff912e03740d9bc19e133e581e0"\u003eOption \u003cspan class="hashtag"\u003e#2\u003c/span\u003e\n\u003c/li\u003e\n\u003c/ul\u003e\n\u003c/div\u003e\n\u003cdiv class="poll-info"\u003e\n\u003cp\u003e\n\u003cspan class="info-number"\u003e0\u003c/span\u003e\n\u003cspan class="info-label"\u003evoters\u003c/span\u003e\n\u003c/p\u003e\n\u003c/div\u003e\n\u003c/div\u003e\n\u003c/div\u003e',
        post_number: 1,
        post_type: 1,
        updated_at: "2021-06-08T21:59:16.444Z",
        reply_count: 0,
        reply_to_post_number: null,
        quote_count: 0,
        incoming_link_count: 0,
        reads: 2,
        readers_count: 1,
        score: 0,
        yours: true,
        topic_id: 134,
        topic_slug: "load-more-poll-voters",
        display_username: null,
        primary_group_name: null,
        flair_url: null,
        flair_bg_color: null,
        flair_color: null,
        version: 1,
        can_edit: true,
        can_delete: false,
        can_recover: false,
        can_wiki: true,
        title_is_group: false,
        bookmarked: false,
        bookmarks: [],
        raw: "[poll type=regular results=always public=true chartType=bar]\n* Option #1\n* Option #2\n[/poll]",
        actions_summary: [
          { id: 3, can_act: true },
          { id: 4, can_act: true },
          { id: 8, can_act: true },
          { id: 7, can_act: true },
        ],
        moderator: false,
        admin: true,
        staff: true,
        user_id: 1,
        hidden: false,
        trust_level: 0,
        deleted_at: null,
        user_deleted: false,
        edit_reason: null,
        can_view_edit_history: true,
        wiki: false,
        reviewable_id: null,
        reviewable_score_count: 0,
        reviewable_score_pending_count: 0,
        calendar_details: [],
        can_accept_answer: false,
        can_unaccept_answer: false,
        accepted_answer: false,
        polls: [
          {
            name: "poll",
            type: "regular",
            status: "open",
            public: true,
            results: "always",
            options: [
              {
                id: "db753fe0bc4e72869ac1ad8765341764",
                html: 'Option \u003cspan class="hashtag"\u003e#1\u003c/span\u003e',
                votes: 1,
              },
              {
                id: "d8c22ff912e03740d9bc19e133e581e0",
                html: 'Option \u003cspan class="hashtag"\u003e#2\u003c/span\u003e',
                votes: 0,
              },
            ],
            voters: 1,
            preloaded_voters: {
              db753fe0bc4e72869ac1ad8765341764: [
                {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              ],
            },
            chart_type: "bar",
            title: null,
          },
        ],
        polls_votes: { poll: ["db753fe0bc4e72869ac1ad8765341764"] },
      });
    });

    server.get("/t/134.json", () => {
      return helper.response({
        post_stream: {
          posts: [
            {
              id: 156,
              name: null,
              username: "bianca",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
              created_at: "2021-06-08T21:56:55.166Z",
              cooked:
                '\u003cdiv class="poll" data-poll-status="open" data-poll-public="true" data-poll-results="always" data-poll-charttype="bar" data-poll-type="regular" data-poll-name="poll"\u003e\n\u003cdiv\u003e\n\u003cdiv class="poll-container"\u003e\n\u003cul\u003e\n\u003cli data-poll-option-id="db753fe0bc4e72869ac1ad8765341764"\u003eOption \u003cspan class="hashtag"\u003e#1\u003c/span\u003e\n\u003c/li\u003e\n\u003cli data-poll-option-id="d8c22ff912e03740d9bc19e133e581e0"\u003eOption \u003cspan class="hashtag"\u003e#2\u003c/span\u003e\n\u003c/li\u003e\n\u003c/ul\u003e\n\u003c/div\u003e\n\u003cdiv class="poll-info"\u003e\n\u003cp\u003e\n\u003cspan class="info-number"\u003e0\u003c/span\u003e\n\u003cspan class="info-label"\u003evoters\u003c/span\u003e\n\u003c/p\u003e\n\u003c/div\u003e\n\u003c/div\u003e\n\u003c/div\u003e',
              post_number: 1,
              post_type: 1,
              updated_at: "2021-06-08T21:59:16.444Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              incoming_link_count: 0,
              reads: 2,
              readers_count: 1,
              score: 0,
              yours: true,
              topic_id: 134,
              topic_slug: "load-more-poll-voters",
              display_username: null,
              primary_group_name: null,
              flair_url: null,
              flair_bg_color: null,
              flair_color: null,
              version: 1,
              can_edit: true,
              can_delete: false,
              can_recover: false,
              can_wiki: true,
              read: true,
              title_is_group: false,
              bookmarked: false,
              bookmarks: [],
              actions_summary: [
                { id: 3, can_act: true },
                { id: 4, can_act: true },
                { id: 8, can_act: true },
                { id: 7, can_act: true },
              ],
              moderator: false,
              admin: true,
              staff: true,
              user_id: 1,
              hidden: false,
              trust_level: 0,
              deleted_at: null,
              user_deleted: false,
              edit_reason: null,
              can_view_edit_history: true,
              wiki: false,
              reviewable_id: 0,
              reviewable_score_count: 0,
              reviewable_score_pending_count: 0,
              calendar_details: [],
              can_accept_answer: false,
              can_unaccept_answer: false,
              accepted_answer: false,
              polls: [
                {
                  name: "poll",
                  type: "regular",
                  status: "open",
                  public: true,
                  results: "always",
                  options: [
                    {
                      id: "db753fe0bc4e72869ac1ad8765341764",
                      html: 'Option \u003cspan class="hashtag"\u003e#1\u003c/span\u003e',
                      votes: 1,
                    },
                    {
                      id: "d8c22ff912e03740d9bc19e133e581e0",
                      html: 'Option \u003cspan class="hashtag"\u003e#2\u003c/span\u003e',
                      votes: 0,
                    },
                  ],
                  voters: 1,
                  preloaded_voters: {
                    db753fe0bc4e72869ac1ad8765341764: [
                      {
                        id: 1,
                        username: "bianca",
                        name: null,
                        avatar_template:
                          "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                      },
                    ],
                  },
                  chart_type: "bar",
                  title: null,
                },
              ],
              polls_votes: { poll: ["db753fe0bc4e72869ac1ad8765341764"] },
            },
          ],
          stream: [156],
        },
        timeline_lookup: [[1, 0]],
        suggested_topics: [
          {
            id: 7,
            title: "Welcome to Discourse",
            fancy_title: "Welcome to Discourse",
            slug: "welcome-to-discourse",
            posts_count: 9,
            reply_count: 0,
            highest_post_number: 9,
            image_url:
              "//localhost:3000/uploads/default/original/1X/ba1a510603f5112dcaf06cf42c2eb671bff83681.png",
            created_at: "2021-06-02T16:21:38.347Z",
            last_posted_at: "2021-06-08T20:36:29.235Z",
            bumped: true,
            bumped_at: "2021-06-08T20:36:29.235Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 9,
            unread_posts: 0,
            pinned: false,
            unpinned: true,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 2,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: [],
            like_count: 0,
            views: 2,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: null,
                description: "Original Poster",
                user: {
                  id: -1,
                  username: "system",
                  name: "system",
                  avatar_template: "/images/discourse-logo-sketch-small.png",
                },
              },
              {
                extras: "latest",
                description: "Most Recent Poster",
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
            ],
          },
          {
            id: 129,
            title: "This is another test topic",
            fancy_title: "This is another test topic",
            slug: "this-is-another-test-topic",
            posts_count: 1,
            reply_count: 0,
            highest_post_number: 1,
            image_url: null,
            created_at: "2021-06-03T15:48:27.262Z",
            last_posted_at: "2021-06-03T15:48:27.537Z",
            bumped: true,
            bumped_at: "2021-06-08T12:52:36.650Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 1,
            unread_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 2,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: [],
            like_count: 0,
            views: 7,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 12,
                  username: "bar",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/b77776/{size}.png",
                },
              },
            ],
          },
          {
            id: 131,
            title:
              "Welcome to Discourse — thanks for starting a new conversation!",
            fancy_title:
              "Welcome to Discourse — thanks for starting a new conversation!",
            slug: "welcome-to-discourse-thanks-for-starting-a-new-conversation",
            posts_count: 1,
            reply_count: 0,
            highest_post_number: 1,
            image_url: null,
            created_at: "2021-06-04T08:51:19.807Z",
            last_posted_at: "2021-06-04T08:51:19.928Z",
            bumped: true,
            bumped_at: "2021-06-04T14:37:46.939Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 1,
            unread_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 3,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: ["abc", "e", "b"],
            like_count: 0,
            views: 3,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
            ],
          },
          {
            id: 133,
            title: "This is a new topic",
            fancy_title: "This is a new topic",
            slug: "this-is-a-new-topic",
            posts_count: 12,
            reply_count: 0,
            highest_post_number: 12,
            image_url: null,
            created_at: "2021-06-08T14:44:03.664Z",
            last_posted_at: "2021-06-08T19:57:35.853Z",
            bumped: true,
            bumped_at: "2021-06-08T19:57:35.853Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 12,
            unread_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 3,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: [],
            like_count: 0,
            views: 1,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
            ],
          },
        ],
        tags: [],
        id: 134,
        title: "Load more poll voters",
        fancy_title: "Load more poll voters",
        posts_count: 1,
        created_at: "2021-06-08T21:56:55.073Z",
        views: 4,
        reply_count: 0,
        like_count: 0,
        last_posted_at: "2021-06-08T21:56:55.166Z",
        visible: true,
        closed: false,
        archived: false,
        has_summary: false,
        archetype: "regular",
        slug: "load-more-poll-voters",
        category_id: 1,
        word_count: 14,
        deleted_at: null,
        user_id: 1,
        featured_link: null,
        pinned_globally: false,
        pinned_at: null,
        pinned_until: null,
        image_url: null,
        slow_mode_seconds: 0,
        draft: null,
        draft_key: "topic_134",
        draft_sequence: 7,
        posted: true,
        unpinned: null,
        pinned: false,
        current_post_number: 1,
        highest_post_number: 1,
        last_read_post_number: 1,
        last_read_post_id: 156,
        deleted_by: null,
        has_deleted: false,
        actions_summary: [
          { id: 4, count: 0, hidden: false, can_act: true },
          { id: 8, count: 0, hidden: false, can_act: true },
          { id: 7, count: 0, hidden: false, can_act: true },
        ],
        chunk_size: 20,
        bookmarked: false,
        bookmarks: [],
        topic_timer: null,
        message_bus_last_id: 5,
        participant_count: 1,
        queued_posts_count: 0,
        show_read_indicator: false,
        thumbnails: null,
        slow_mode_enabled_until: null,
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
          can_remove_self_id: 1,
          participants: [
            {
              id: 1,
              username: "bianca",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
              post_count: 1,
              primary_group_name: null,
              flair_url: null,
              flair_color: null,
              flair_bg_color: null,
              admin: true,
              trust_level: 0,
            },
          ],
          created_by: {
            id: 1,
            username: "bianca",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
          },
          last_poster: {
            id: 1,
            username: "bianca",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
          },
        },
        pending_posts: [],
      });
    });

    server.get("/t/135.json", () => {
      return helper.response({
        post_stream: {
          posts: [
            {
              id: 158,
              name: null,
              username: "bianca",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
              created_at: "2021-06-08T21:56:55.166Z",
              cooked:
                '\u003cdiv class="poll" data-poll-status="open" data-poll-public="true" data-poll-results="always" data-poll-charttype="bar" data-poll-type="ranked_choice" data-poll-name="poll"\u003e\n\u003cdiv\u003e\n\u003cdiv class="poll-container"\u003e\n\u003cul\u003e\n\u003cli data-poll-option-id="db753fe0bc4e72869ac1ad8765341764"\u003eOption \u003cspan class="hashtag"\u003e#1\u003c/span\u003e\n\u003c/li\u003e\n\u003cli data-poll-option-id="d8c22ff912e03740d9bc19e133e581e0"\u003eOption \u003cspan class="hashtag"\u003e#2\u003c/span\u003e\n\u003c/li\u003e\n\u003c/ul\u003e\n\u003c/div\u003e\n\u003cdiv class="poll-info"\u003e\n\u003cp\u003e\n\u003cspan class="info-number"\u003e0\u003c/span\u003e\n\u003cspan class="info-label"\u003evoters\u003c/span\u003e\n\u003c/p\u003e\n\u003c/div\u003e\n\u003c/div\u003e\n\u003c/div\u003e',
              post_number: 1,
              post_type: 1,
              updated_at: "2021-06-08T21:59:16.444Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              incoming_link_count: 0,
              reads: 2,
              readers_count: 1,
              score: 0,
              yours: true,
              topic_id: 135,
              topic_slug: "load-more-poll-voters-ranked-choice",
              display_username: null,
              primary_group_name: null,
              flair_url: null,
              flair_bg_color: null,
              flair_color: null,
              version: 1,
              can_edit: true,
              can_delete: false,
              can_recover: false,
              can_wiki: true,
              read: true,
              title_is_group: false,
              bookmarked: false,
              bookmarks: [],
              actions_summary: [
                { id: 3, can_act: true },
                { id: 4, can_act: true },
                { id: 8, can_act: true },
                { id: 7, can_act: true },
              ],
              moderator: false,
              admin: true,
              staff: true,
              user_id: 1,
              hidden: false,
              trust_level: 0,
              deleted_at: null,
              user_deleted: false,
              edit_reason: null,
              can_view_edit_history: true,
              wiki: false,
              reviewable_id: 0,
              reviewable_score_count: 0,
              reviewable_score_pending_count: 0,
              calendar_details: [],
              can_accept_answer: false,
              can_unaccept_answer: false,
              accepted_answer: false,
              polls: [
                {
                  name: "poll",
                  type: "ranked_choice",
                  status: "open",
                  public: true,
                  results: "always",
                  options: [
                    {
                      id: "def034c6770c6fd3754c054ef9ec4721",
                      html: "This",
                      votes: 2,
                    },
                    {
                      id: "d8c22ff912e03740d9bc19e133e581e0",
                      html: "That",
                      votes: 0,
                    },
                  ],
                  voters: 2,
                  preloaded_voters: {
                    def034c6770c6fd3754c054ef9ec4721: [
                      {
                        rank: 1,
                        user: {
                          id: 1,
                          username: "bianca",
                          name: null,
                          avatar_template:
                            "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                        },
                      },
                    ],
                  },
                  chart_type: "bar",
                  title: null,
                  ranked_choice_outcome: {
                    tied: false,
                    tied_candidates: null,
                    winner: true,
                    winning_candidate: {
                      digest: "def034c6770c6fd3754c054ef9ec4721",
                      html: "This",
                    },
                    round_activity: [
                      {
                        round: 1,
                        majority: {
                          digest: "def034c6770c6fd3754c054ef9ec4721",
                          html: "This",
                        },
                      },
                    ],
                  },
                },
              ],
              polls_votes: {
                poll: [
                  {
                    digest: "def034c6770c6fd3754c054ef9ec4721",
                    votes: 2,
                  },
                  {
                    digest: "d8c22ff912e03740d9bc19e133e581e0",
                    votes: 0,
                  },
                ],
              },
            },
          ],
          stream: [158],
        },
        timeline_lookup: [[1, 0]],
        suggested_topics: [
          {
            id: 7,
            title: "Welcome to Discourse",
            fancy_title: "Welcome to Discourse",
            slug: "welcome-to-discourse",
            posts_count: 9,
            reply_count: 0,
            highest_post_number: 9,
            image_url:
              "//localhost:3000/uploads/default/original/1X/ba1a510603f5112dcaf06cf42c2eb671bff83681.png",
            created_at: "2021-06-02T16:21:38.347Z",
            last_posted_at: "2021-06-08T20:36:29.235Z",
            bumped: true,
            bumped_at: "2021-06-08T20:36:29.235Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 9,
            unread_posts: 0,
            pinned: false,
            unpinned: true,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 2,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: [],
            like_count: 0,
            views: 2,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: null,
                description: "Original Poster",
                user: {
                  id: -1,
                  username: "system",
                  name: "system",
                  avatar_template: "/images/discourse-logo-sketch-small.png",
                },
              },
              {
                extras: "latest",
                description: "Most Recent Poster",
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
            ],
          },
          {
            id: 129,
            title: "This is another test topic",
            fancy_title: "This is another test topic",
            slug: "this-is-another-test-topic",
            posts_count: 1,
            reply_count: 0,
            highest_post_number: 1,
            image_url: null,
            created_at: "2021-06-03T15:48:27.262Z",
            last_posted_at: "2021-06-03T15:48:27.537Z",
            bumped: true,
            bumped_at: "2021-06-08T12:52:36.650Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 1,
            unread_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 2,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: [],
            like_count: 0,
            views: 7,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 12,
                  username: "bar",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/b77776/{size}.png",
                },
              },
            ],
          },
          {
            id: 131,
            title:
              "Welcome to Discourse — thanks for starting a new conversation!",
            fancy_title:
              "Welcome to Discourse — thanks for starting a new conversation!",
            slug: "welcome-to-discourse-thanks-for-starting-a-new-conversation",
            posts_count: 1,
            reply_count: 0,
            highest_post_number: 1,
            image_url: null,
            created_at: "2021-06-04T08:51:19.807Z",
            last_posted_at: "2021-06-04T08:51:19.928Z",
            bumped: true,
            bumped_at: "2021-06-04T14:37:46.939Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 1,
            unread_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 3,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: ["abc", "e", "b"],
            like_count: 0,
            views: 3,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
            ],
          },
          {
            id: 133,
            title: "This is a new topic",
            fancy_title: "This is a new topic",
            slug: "this-is-a-new-topic",
            posts_count: 12,
            reply_count: 0,
            highest_post_number: 12,
            image_url: null,
            created_at: "2021-06-08T14:44:03.664Z",
            last_posted_at: "2021-06-08T19:57:35.853Z",
            bumped: true,
            bumped_at: "2021-06-08T19:57:35.853Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 12,
            unread_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 3,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: [],
            like_count: 0,
            views: 1,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
            ],
          },
        ],
        tags: [],
        id: 135,
        title: "Load more poll voters",
        fancy_title: "Load more poll voters",
        posts_count: 1,
        created_at: "2021-06-08T21:56:55.073Z",
        views: 4,
        reply_count: 0,
        like_count: 0,
        last_posted_at: "2021-06-08T21:56:55.166Z",
        visible: true,
        closed: false,
        archived: false,
        has_summary: false,
        archetype: "regular",
        slug: "load-more-poll-voters",
        category_id: 1,
        word_count: 14,
        deleted_at: null,
        user_id: 1,
        featured_link: null,
        pinned_globally: false,
        pinned_at: null,
        pinned_until: null,
        image_url: null,
        slow_mode_seconds: 0,
        draft: null,
        draft_key: "topic_135",
        draft_sequence: 7,
        posted: true,
        unpinned: null,
        pinned: false,
        current_post_number: 1,
        highest_post_number: 1,
        last_read_post_number: 1,
        last_read_post_id: 158,
        deleted_by: null,
        has_deleted: false,
        actions_summary: [
          { id: 4, count: 0, hidden: false, can_act: true },
          { id: 8, count: 0, hidden: false, can_act: true },
          { id: 7, count: 0, hidden: false, can_act: true },
        ],
        chunk_size: 20,
        bookmarked: false,
        bookmarks: [],
        topic_timer: null,
        message_bus_last_id: 5,
        participant_count: 1,
        queued_posts_count: 0,
        show_read_indicator: false,
        thumbnails: null,
        slow_mode_enabled_until: null,
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
          can_remove_self_id: 1,
          participants: [
            {
              id: 1,
              username: "bianca",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
              post_count: 1,
              primary_group_name: null,
              flair_url: null,
              flair_color: null,
              flair_bg_color: null,
              admin: true,
              trust_level: 0,
            },
          ],
          created_by: {
            id: 1,
            username: "bianca",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
          },
          last_poster: {
            id: 1,
            username: "bianca",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
          },
        },
        pending_posts: [],
      });
    });

    server.get("/polls/voters.json", (request) => {
      if (
        request.queryParams.option_id === "db753fe0bc4e72869ac1ad8765341764"
      ) {
        return helper.response({
          voters: {
            db753fe0bc4e72869ac1ad8765341764: [
              {
                id: 1,
                username: "bianca",
                name: null,
                avatar_template:
                  "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                title: null,
              },
              {
                id: 7,
                username: "foo",
                name: null,
                avatar_template:
                  "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
                title: null,
              },
            ],
          },
        });
      } else if (
        request.queryParams.option_id === "def034c6770c6fd3754c054ef9ec4721"
      ) {
        return helper.response({
          voters: {
            def034c6770c6fd3754c054ef9ec4721: [
              {
                rank: 1,
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
              {
                rank: 1,
                user: {
                  id: 7,
                  username: "foo",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
                  title: null,
                },
              },
            ],
          },
        });
      } else {
        return helper.response({
          voters: {
            [request.queryParams.option_id]: [],
          },
        });
      }
    });

    server.delete("/polls/vote", () =>
      helper.response({
        success: "OK",
        poll: {
          options: [
            {
              id: "db753fe0bc4e72869ac1ad8765341764",
              html: 'Option <span class="hashtag">#1</span>',
              votes: 0,
            },
            {
              id: "d8c22ff912e03740d9bc19e133e581e0",
              html: 'Option <span class="hashtag">#2</span>',
              votes: 0,
            },
          ],
          voters: 0,
        },
      })
    );
  });

  test("can load more voters", async function (assert) {
    await visit("/t/load-more-poll-voters/134");
    assert.strictEqual(
      count(".poll-container .results li:nth-child(1) .poll-voters li"),
      1,
      "Initially, one voter shown on first option"
    );
    assert.strictEqual(
      count(".poll-container .results li:nth-child(2) .poll-voters li"),
      0,
      "Initially, no voter shown on second option"
    );

    await publishToMessageBus("/polls/134", {
      post_id: "156",
      polls: [
        {
          name: "poll",
          type: "regular",
          status: "open",
          public: true,
          results: "always",
          options: [
            {
              id: "db753fe0bc4e72869ac1ad8765341764",
              html: 'Option <span class="hashtag">#1</span>',
              votes: 2,
            },
            {
              id: "d8c22ff912e03740d9bc19e133e581e0",
              html: 'Option <span class="hashtag">#2</span>',
              votes: 0,
            },
          ],
          voters: 2,
          preloaded_voters: {
            db753fe0bc4e72869ac1ad8765341764: [
              {
                id: 1,
                username: "bianca",
                name: null,
                avatar_template:
                  "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
              },
            ],
          },
          chart_type: "bar",
          title: null,
        },
      ],
    });

    assert.strictEqual(
      count(".poll-container .results li:nth-child(1) .poll-voters li"),
      1,
      "after incoming message, one voter shown on first option"
    );

    assert.strictEqual(
      count(".poll-container .results li:nth-child(2) .poll-voters li"),
      0,
      "after incoming message, no voter shown on second option"
    );

    await click(".poll-voters-toggle-expand");

    assert.strictEqual(
      count(".poll-container .results li:nth-child(1) .poll-voters li"),
      2,
      "after clicking fetch voters button, two voters shown on first option"
    );
    assert.strictEqual(
      count(".poll-container .results li:nth-child(2) .poll-voters li"),
      0,
      "after clicking fetch voters button, no voters shown on second option"
    );
  });

  test("can load more voters - ranked choice", async function (assert) {
    await visit("/t/load-more-poll-voters-ranked-choice/135");

    assert.strictEqual(
      query(
        ".poll-container .discourse-poll-ranked_choice-results .tab-container .tab.nav-item.active button"
      ).innerText,
      I18n.t("poll.results.tabs.outcome"),
      "Outcome tab is active"
    );

    await click(
      ".poll-container .discourse-poll-ranked_choice-results .tab-container .tab.nav-item:not(.active) button"
    );

    assert.strictEqual(
      query(
        ".poll-container .discourse-poll-ranked_choice-results .tab-container .tab.nav-item.active button"
      ).innerText,
      I18n.t("poll.results.tabs.votes"),
      "Votes tab is active"
    );

    assert.strictEqual(
      count(
        ".poll-container .discourse-poll-ranked_choice-results .poll-voters li"
      ),
      1,
      "Initially, one voter shown on first option"
    );

    await click(".poll-voters-toggle-expand");

    assert.strictEqual(
      count(
        ".poll-container .discourse-poll-ranked_choice-results .results li:nth-child(1) .poll-voters li"
      ),
      2,
      "after clicking fetch voters button, two voters shown on first option"
    );

    await publishToMessageBus("/polls/135", {
      post_id: "158",
      polls: [
        {
          name: "poll",
          type: "ranked_choice",
          status: "open",
          public: true,
          results: "always",
          options: [
            {
              id: "def034c6770c6fd3754c054ef9ec4721",
              html: "This",
              votes: 3,
            },
            {
              id: "d8c22ff912e03740d9bc19e133e581e0",
              html: "That",
              votes: 0,
            },
          ],
          voters: 3,
          preloaded_voters: {
            def034c6770c6fd3754c054ef9ec4721: [
              {
                rank: 1,
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
              {
                rank: 1,
                user: {
                  id: 7,
                  username: "foo",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
                  title: null,
                },
              },
              {
                rank: 1,
                user: {
                  id: 11,
                  username: "bar",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/f/f33bef/{size}.png",
                  title: null,
                },
              },
            ],
          },
          chart_type: "bar",
          title: null,
        },
      ],
    });

    assert.strictEqual(
      count(
        ".poll-container .discourse-poll-ranked_choice-results .results li:nth-child(1) .poll-voters li"
      ),
      2,
      "after incoming message containing 3 voters, only 2 voters shown on first option as bus updates are not supported once voters are expanded"
    );
  });

  test("can unvote", async function (assert) {
    await visit("/t/load-more-poll-voters/134");

    await click(".toggle-results");

    assert.strictEqual(count(".poll-container .d-icon-circle"), 1);
    assert.strictEqual(count(".poll-container .d-icon-far-circle"), 1);

    await click(".remove-vote");

    assert.strictEqual(count(".poll-container .d-icon-circle"), 0);
    assert.strictEqual(count(".poll-container .d-icon-far-circle"), 2);
  });
});

acceptance("Poll results - no voters", function (needs) {
  needs.user();
  needs.settings({ poll_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/posts/by_number/134/1", () => {
      return helper.response({
        id: 156,
        name: null,
        username: "bianca",
        avatar_template: "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
        created_at: "2021-06-08T21:56:55.166Z",
        cooked:
          '\u003cdiv class="poll" data-poll-status="open" data-poll-public="true" data-poll-results="always" data-poll-charttype="bar" data-poll-type="regular" data-poll-name="poll"\u003e\n\u003cdiv\u003e\n\u003cdiv class="poll-container"\u003e\n\u003cul\u003e\n\u003cli data-poll-option-id="db753fe0bc4e72869ac1ad8765341764"\u003eOption \u003cspan class="hashtag"\u003e#1\u003c/span\u003e\n\u003c/li\u003e\n\u003cli data-poll-option-id="d8c22ff912e03740d9bc19e133e581e0"\u003eOption \u003cspan class="hashtag"\u003e#2\u003c/span\u003e\n\u003c/li\u003e\n\u003c/ul\u003e\n\u003c/div\u003e\n\u003cdiv class="poll-info"\u003e\n\u003cp\u003e\n\u003cspan class="info-number"\u003e0\u003c/span\u003e\n\u003cspan class="info-label"\u003evoters\u003c/span\u003e\n\u003c/p\u003e\n\u003c/div\u003e\n\u003c/div\u003e\n\u003c/div\u003e',
        post_number: 1,
        post_type: 1,
        updated_at: "2021-06-08T21:59:16.444Z",
        reply_count: 0,
        reply_to_post_number: null,
        quote_count: 0,
        incoming_link_count: 0,
        reads: 2,
        readers_count: 1,
        score: 0,
        yours: true,
        topic_id: 134,
        topic_slug: "load-more-poll-voters",
        display_username: null,
        primary_group_name: null,
        flair_url: null,
        flair_bg_color: null,
        flair_color: null,
        version: 1,
        can_edit: true,
        can_delete: false,
        can_recover: false,
        can_wiki: true,
        title_is_group: false,
        bookmarked: false,
        bookmarks: [],
        raw: "[poll type=regular results=always public=true chartType=bar]\n* Option #1\n* Option #2\n[/poll]",
        actions_summary: [
          { id: 3, can_act: true },
          { id: 4, can_act: true },
          { id: 8, can_act: true },
          { id: 7, can_act: true },
        ],
        moderator: false,
        admin: true,
        staff: true,
        user_id: 1,
        hidden: false,
        trust_level: 0,
        deleted_at: null,
        user_deleted: false,
        edit_reason: null,
        can_view_edit_history: true,
        wiki: false,
        reviewable_id: null,
        reviewable_score_count: 0,
        reviewable_score_pending_count: 0,
        calendar_details: [],
        can_accept_answer: false,
        can_unaccept_answer: false,
        accepted_answer: false,
        polls: [
          {
            name: "poll",
            type: "regular",
            status: "open",
            public: true,
            results: "always",
            options: [
              {
                id: "db753fe0bc4e72869ac1ad8765341764",
                html: 'Option \u003cspan class="hashtag"\u003e#1\u003c/span\u003e',
                votes: 0,
              },
              {
                id: "d8c22ff912e03740d9bc19e133e581e0",
                html: 'Option \u003cspan class="hashtag"\u003e#2\u003c/span\u003e',
                votes: 0,
              },
            ],
            voters: 0,
            preloaded_voters: {},
            chart_type: "bar",
            title: null,
          },
        ],
      });
    });

    server.get("/t/134.json", () => {
      return helper.response({
        post_stream: {
          posts: [
            {
              id: 156,
              name: null,
              username: "bianca",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
              created_at: "2021-06-08T21:56:55.166Z",
              cooked:
                '\u003cdiv class="poll" data-poll-status="open" data-poll-public="true" data-poll-results="always" data-poll-charttype="bar" data-poll-type="regular" data-poll-name="poll"\u003e\n\u003cdiv\u003e\n\u003cdiv class="poll-container"\u003e\n\u003cul\u003e\n\u003cli data-poll-option-id="db753fe0bc4e72869ac1ad8765341764"\u003eOption \u003cspan class="hashtag"\u003e#1\u003c/span\u003e\n\u003c/li\u003e\n\u003cli data-poll-option-id="d8c22ff912e03740d9bc19e133e581e0"\u003eOption \u003cspan class="hashtag"\u003e#2\u003c/span\u003e\n\u003c/li\u003e\n\u003c/ul\u003e\n\u003c/div\u003e\n\u003cdiv class="poll-info"\u003e\n\u003cp\u003e\n\u003cspan class="info-number"\u003e0\u003c/span\u003e\n\u003cspan class="info-label"\u003evoters\u003c/span\u003e\n\u003c/p\u003e\n\u003c/div\u003e\n\u003c/div\u003e\n\u003c/div\u003e',
              post_number: 1,
              post_type: 1,
              updated_at: "2021-06-08T21:59:16.444Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              incoming_link_count: 0,
              reads: 2,
              readers_count: 1,
              score: 0,
              yours: true,
              topic_id: 134,
              topic_slug: "load-more-poll-voters",
              display_username: null,
              primary_group_name: null,
              flair_url: null,
              flair_bg_color: null,
              flair_color: null,
              version: 1,
              can_edit: true,
              can_delete: false,
              can_recover: false,
              can_wiki: true,
              read: true,
              title_is_group: false,
              bookmarked: false,
              bookmarks: [],
              actions_summary: [
                { id: 3, can_act: true },
                { id: 4, can_act: true },
                { id: 8, can_act: true },
                { id: 7, can_act: true },
              ],
              moderator: false,
              admin: true,
              staff: true,
              user_id: 1,
              hidden: false,
              trust_level: 0,
              deleted_at: null,
              user_deleted: false,
              edit_reason: null,
              can_view_edit_history: true,
              wiki: false,
              reviewable_id: 0,
              reviewable_score_count: 0,
              reviewable_score_pending_count: 0,
              calendar_details: [],
              can_accept_answer: false,
              can_unaccept_answer: false,
              accepted_answer: false,
              polls: [
                {
                  name: "poll",
                  type: "regular",
                  status: "open",
                  public: true,
                  results: "always",
                  options: [
                    {
                      id: "db753fe0bc4e72869ac1ad8765341764",
                      html: 'Option \u003cspan class="hashtag"\u003e#1\u003c/span\u003e',
                      votes: 0,
                    },
                    {
                      id: "d8c22ff912e03740d9bc19e133e581e0",
                      html: 'Option \u003cspan class="hashtag"\u003e#2\u003c/span\u003e',
                      votes: 0,
                    },
                  ],
                  voters: 0,
                  preloaded_voters: {},
                  chart_type: "bar",
                  title: null,
                },
              ],
            },
          ],
          stream: [156],
        },
        timeline_lookup: [[1, 0]],
        suggested_topics: [
          {
            id: 7,
            title: "Welcome to Discourse",
            fancy_title: "Welcome to Discourse",
            slug: "welcome-to-discourse",
            posts_count: 9,
            reply_count: 0,
            highest_post_number: 9,
            image_url:
              "//localhost:3000/uploads/default/original/1X/ba1a510603f5112dcaf06cf42c2eb671bff83681.png",
            created_at: "2021-06-02T16:21:38.347Z",
            last_posted_at: "2021-06-08T20:36:29.235Z",
            bumped: true,
            bumped_at: "2021-06-08T20:36:29.235Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 9,
            unread_posts: 0,
            pinned: false,
            unpinned: true,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 2,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: [],
            like_count: 0,
            views: 2,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: null,
                description: "Original Poster",
                user: {
                  id: -1,
                  username: "system",
                  name: "system",
                  avatar_template: "/images/discourse-logo-sketch-small.png",
                },
              },
              {
                extras: "latest",
                description: "Most Recent Poster",
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
            ],
          },
          {
            id: 129,
            title: "This is another test topic",
            fancy_title: "This is another test topic",
            slug: "this-is-another-test-topic",
            posts_count: 1,
            reply_count: 0,
            highest_post_number: 1,
            image_url: null,
            created_at: "2021-06-03T15:48:27.262Z",
            last_posted_at: "2021-06-03T15:48:27.537Z",
            bumped: true,
            bumped_at: "2021-06-08T12:52:36.650Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 1,
            unread_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 2,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: [],
            like_count: 0,
            views: 7,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 12,
                  username: "bar",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/b77776/{size}.png",
                },
              },
            ],
          },
          {
            id: 131,
            title:
              "Welcome to Discourse — thanks for starting a new conversation!",
            fancy_title:
              "Welcome to Discourse — thanks for starting a new conversation!",
            slug: "welcome-to-discourse-thanks-for-starting-a-new-conversation",
            posts_count: 1,
            reply_count: 0,
            highest_post_number: 1,
            image_url: null,
            created_at: "2021-06-04T08:51:19.807Z",
            last_posted_at: "2021-06-04T08:51:19.928Z",
            bumped: true,
            bumped_at: "2021-06-04T14:37:46.939Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 1,
            unread_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 3,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: ["abc", "e", "b"],
            like_count: 0,
            views: 3,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
            ],
          },
          {
            id: 133,
            title: "This is a new topic",
            fancy_title: "This is a new topic",
            slug: "this-is-a-new-topic",
            posts_count: 12,
            reply_count: 0,
            highest_post_number: 12,
            image_url: null,
            created_at: "2021-06-08T14:44:03.664Z",
            last_posted_at: "2021-06-08T19:57:35.853Z",
            bumped: true,
            bumped_at: "2021-06-08T19:57:35.853Z",
            archetype: "regular",
            unseen: false,
            last_read_post_number: 12,
            unread_posts: 0,
            pinned: false,
            unpinned: null,
            visible: true,
            closed: false,
            archived: false,
            notification_level: 3,
            bookmarked: false,
            bookmarks: [],
            liked: false,
            tags: [],
            like_count: 0,
            views: 1,
            category_id: 1,
            featured_link: null,
            has_accepted_answer: false,
            posters: [
              {
                extras: "latest single",
                description: "Original Poster, Most Recent Poster",
                user: {
                  id: 1,
                  username: "bianca",
                  name: null,
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
                },
              },
            ],
          },
        ],
        tags: [],
        id: 134,
        title: "Load more poll voters",
        fancy_title: "Load more poll voters",
        posts_count: 1,
        created_at: "2021-06-08T21:56:55.073Z",
        views: 4,
        reply_count: 0,
        like_count: 0,
        last_posted_at: "2021-06-08T21:56:55.166Z",
        visible: true,
        closed: false,
        archived: false,
        has_summary: false,
        archetype: "regular",
        slug: "load-more-poll-voters",
        category_id: 1,
        word_count: 14,
        deleted_at: null,
        user_id: 1,
        featured_link: null,
        pinned_globally: false,
        pinned_at: null,
        pinned_until: null,
        image_url: null,
        slow_mode_seconds: 0,
        draft: null,
        draft_key: "topic_134",
        draft_sequence: 7,
        posted: true,
        unpinned: null,
        pinned: false,
        current_post_number: 1,
        highest_post_number: 1,
        last_read_post_number: 1,
        last_read_post_id: 156,
        deleted_by: null,
        has_deleted: false,
        actions_summary: [
          { id: 4, count: 0, hidden: false, can_act: true },
          { id: 8, count: 0, hidden: false, can_act: true },
          { id: 7, count: 0, hidden: false, can_act: true },
        ],
        chunk_size: 20,
        bookmarked: false,
        bookmarks: [],
        topic_timer: null,
        message_bus_last_id: 5,
        participant_count: 1,
        queued_posts_count: 0,
        show_read_indicator: false,
        thumbnails: null,
        slow_mode_enabled_until: null,
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
          can_remove_self_id: 1,
          participants: [
            {
              id: 1,
              username: "bianca",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
              post_count: 1,
              primary_group_name: null,
              flair_url: null,
              flair_color: null,
              flair_bg_color: null,
              admin: true,
              trust_level: 0,
            },
          ],
          created_by: {
            id: 1,
            username: "bianca",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
          },
          last_poster: {
            id: 1,
            username: "bianca",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
          },
        },
        pending_posts: [],
      });
    });
  });

  test("does not show results button", async function (assert) {
    await visit("/t/load-more-poll-voters/134");

    assert.dom(".toggle-results").doesNotExist();
  });
});
