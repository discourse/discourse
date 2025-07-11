import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Cakeday (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
        cakeday_enabled: true,
        cakeday_emoji: "cake",
        cakeday_birthday_enabled: true,
        cakeday_birthday_emoji: "birthday",
      });

      needs.pretender((server, { response }) => {
        server.get("/t/11.json", () =>
          response({
            post_stream: {
              posts: [
                {
                  id: 14,
                  name: null,
                  username: "tgx",
                  avatar_template:
                    "/letter_avatar_proxy/v2/letter/t/ecae2f/{size}.png",
                  created_at: "2016-11-21T06:55:17.892Z",
                  cooked:
                    "<p>This is a topic written for an acceptance test</p>",
                  post_number: 1,
                  post_type: 1,
                  updated_at: "2016-11-21T06:55:17.892Z",
                  reply_count: 0,
                  reply_to_post_number: null,
                  quote_count: 0,
                  avg_time: null,
                  incoming_link_count: 0,
                  reads: 1,
                  score: 0,
                  yours: true,
                  topic_id: 11,
                  topic_slug: "some-really-interesting-topic",
                  display_username: null,
                  primary_group_name: null,
                  primary_group_flair_url: null,
                  primary_group_flair_bg_color: null,
                  primary_group_flair_color: null,
                  version: 1,
                  can_edit: true,
                  can_delete: false,
                  can_recover: true,
                  can_wiki: true,
                  read: true,
                  user_title: null,
                  actions_summary: [
                    { id: 3, can_act: true },
                    { id: 4, can_act: true },
                    { id: 5, hidden: true, can_act: true },
                    { id: 7, can_act: true },
                    { id: 8, can_act: true },
                  ],
                  moderator: false,
                  admin: true,
                  staff: true,
                  user_id: 1,
                  hidden: false,
                  hidden_reason_id: null,
                  trust_level: 4,
                  deleted_at: null,
                  user_deleted: false,
                  edit_reason: null,
                  can_view_edit_history: true,
                  wiki: false,
                  user_cakedate: moment()
                    .subtract(4, "year")
                    .format("YYYY-MM-DD"),
                  user_birthdate: moment().format("YYYY-MM-DD"),
                },
              ],
              stream: [14],
            },
            timeline_lookup: [[1, 0]],
            id: 11,
            title: "Some really interesting topic",
            fancy_title: "Some really interesting topic",
            posts_count: 1,
            created_at: "2016-11-21T06:55:17.771Z",
            views: 1,
            reply_count: 0,
            participant_count: 1,
            like_count: 0,
            last_posted_at: "2016-11-21T06:55:17.892Z",
            visible: true,
            closed: false,
            archived: false,
            has_summary: false,
            archetype: "regular",
            slug: "some-really-interesting-topic",
            category_id: 1,
            word_count: 9,
            deleted_at: null,
            user_id: 1,
            draft: null,
            draft_key: "topic_11",
            draft_sequence: 1,
            posted: true,
            unpinned: null,
            pinned_globally: false,
            pinned: false,
            pinned_at: null,
            pinned_until: null,
            details: {
              auto_close_at: null,
              auto_close_hours: null,
              auto_close_based_on_last_post: false,
              created_by: {
                id: 1,
                username: "tgx",
                avatar_template:
                  "/letter_avatar_proxy/v2/letter/t/ecae2f/{size}.png",
              },
              last_poster: {
                id: 1,
                username: "tgx",
                avatar_template:
                  "/letter_avatar_proxy/v2/letter/t/ecae2f/{size}.png",
              },
              participants: [
                {
                  id: 1,
                  username: "tgx",
                  avatar_template:
                    "/letter_avatar_proxy/v2/letter/t/ecae2f/{size}.png",
                  post_count: 1,
                },
              ],
              suggested_topics: [
                {
                  id: 8,
                  title: "Welcome to Discourse",
                  fancy_title: "Welcome to Discourse",
                  slug: "welcome-to-discourse",
                  posts_count: 1,
                  reply_count: 0,
                  highest_post_number: 1,
                  image_url: null,
                  created_at: "2016-11-21T06:53:31.836Z",
                  last_posted_at: "2016-11-21T06:53:31.877Z",
                  bumped: true,
                  bumped_at: "2016-11-21T06:53:31.877Z",
                  unseen: false,
                  pinned: true,
                  unpinned: null,
                  excerpt:
                    "The first paragraph of this pinned topic will be visible as a welcome message to all new visitors on your homepage. It&#39;s important! \n\nEdit this into a brief description of your community: \n\n\nWho is it for?\nWhat can they &hellip;",
                  visible: true,
                  closed: false,
                  archived: false,
                  bookmarked: null,
                  liked: null,
                  archetype: "regular",
                  like_count: 0,
                  views: 0,
                  category_id: 1,
                  posters: [
                    {
                      extras: "latest single",
                      description: "Original Poster, Most Recent Poster",
                      user: {
                        id: -1,
                        username: "system",
                        avatar_template:
                          "/letter_avatar_proxy/v2/letter/s/bcef8e/{size}.png",
                      },
                    },
                  ],
                },
              ],
              notification_level: 3,
              notifications_reason_id: 1,
              can_move_posts: true,
              can_edit: true,
              can_delete: true,
              can_recover: true,
              can_remove_allowed_users: true,
              can_invite_to: true,
              can_create_post: true,
              can_reply_as_new_topic: true,
              can_flag_topic: true,
            },
            highest_post_number: 1,
            last_read_post_number: 1,
            last_read_post_id: 14,
            deleted_by: null,
            has_deleted: false,
            actions_summary: [
              { id: 4, count: 0, hidden: false, can_act: true },
              { id: 7, count: 0, hidden: false, can_act: true },
              { id: 8, count: 0, hidden: false, can_act: true },
            ],
            chunk_size: 20,
            bookmarked: false,
          })
        );

        server.get("/u/tgx.json", () =>
          response({
            user: {
              birthdate: moment().format("YYYY-MM-DD"),
              cakedate: moment().subtract(4, "year").format("YYYY-MM-DD"),
            },
          })
        );

        server.get("/u/tgx/card.json", () =>
          response({
            user: {
              birthdate: moment().format("YYYY-MM-DD"),
              cakedate: moment().subtract(4, "year").format("YYYY-MM-DD"),
            },
          })
        );
      });

      test("Anniversary emoji", async function (assert) {
        await visit("/t/some-really-interesting-topic/11");

        const posterIcons = queryAll(".poster-icon");

        assert
          .dom(posterIcons[0])
          .hasAttribute("title", i18n("user.anniversary.title"));
        assert
          .dom(posterIcons[1])
          .hasAttribute("title", i18n("user.date_of_birth.title"));
        assert.dom("img.emoji", posterIcons[0]).exists({ count: 1 });
        assert.dom("img.emoji", posterIcons[1]).exists({ count: 1 });

        await click(".trigger-user-card a[data-user-card]");

        const emojiImages = queryAll(".emoji-images div");

        assert
          .dom(emojiImages[1])
          .hasAttribute("title", i18n("user.anniversary.title"));
        assert
          .dom(emojiImages[0])
          .hasAttribute("title", i18n("user.date_of_birth.title"));
        assert.strictEqual(emojiImages[0].children.length, 1);
        assert.strictEqual(emojiImages[1].children.length, 1);
      });
    }
  );
});
