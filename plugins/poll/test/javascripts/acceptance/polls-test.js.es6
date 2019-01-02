import { acceptance } from "helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";

acceptance("Rendering polls", {
  loggedIn: true,
  settings: { poll_enabled: true },
  beforeEach: function() {
    clearPopupMenuOptionsCallback();
  }
});

test("Single Poll", async assert => {
  // prettier-ignore
  server.get("/t/13.json", () => { // eslint-disable-line no-undef
    return [
      200,
      { "Content-Type": "application/json" },
      {
        post_stream: {
          posts: [
            {
              id: 19,
              name: null,
              username: "tgx",
              avatar_template: "/images/avatar.png",
              created_at: "2016-12-01T02:39:49.199Z",
              cooked:
                '<div class="poll" data-poll-status="open" data-poll-name="poll">\n<div>\n<div class="poll-container"><ul>\n<li data-poll-option-id="57ddd734344eb7436d64a7d68a0df444">test</li>\n<li data-poll-option-id="b5b78d79ab5b5d75d4d33d8b87f5d2aa">haha</li>\n</ul></div>\n<div class="poll-info"><p><span class="info-number">0</span><span class="info-text">voters</span></p></div>\n</div>\n<div class="poll-buttons"><a title="Display the poll results">Show results</a></div>\n</div>\n\n<div class="poll" data-poll-status="open" data-poll-name="test">\n<div>\n<div class="poll-container"><ul>\n<li data-poll-option-id="c26ad90783b0d80936e5fdb292b7963c">donkey</li>\n<li data-poll-option-id="99f2b9ac452ba73b115fcf3556e6d2d4">kong</li>\n</ul></div>\n<div class="poll-info"><p><span class="info-number">0</span><span class="info-text">voters</span></p></div>\n</div>\n<div class="poll-buttons"><a title="Display the poll results">Show results</a></div>\n</div>',
              post_number: 1,
              post_type: 1,
              updated_at: "2016-12-01T02:47:18.317Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              avg_time: null,
              incoming_link_count: 0,
              reads: 1,
              score: 0,
              yours: true,
              topic_id: 13,
              topic_slug: "this-is-a-test-topic-for-polls",
              display_username: null,
              primary_group_name: null,
              primary_group_flair_url: null,
              primary_group_flair_bg_color: null,
              primary_group_flair_color: null,
              version: 2,
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
                { id: 8, can_act: true }
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
              polls: [
                {
                  options: [
                    {
                      id: "57ddd734344eb7436d64a7d68a0df444",
                      html: "test",
                      votes: 0
                    },
                    {
                      id: "b5b78d79ab5b5d75d4d33d8b87f5d2aa",
                      html: "haha",
                      votes: 0
                    }
                  ],
                  voters: 2,
                  status: "open",
                  name: "poll"
                },
                {
                  options: [
                    {
                      id: "c26ad90783b0d80936e5fdb292b7963c",
                      html: "donkey",
                      votes: 0
                    },
                    {
                      id: "99f2b9ac452ba73b115fcf3556e6d2d4",
                      html: "kong",
                      votes: 0
                    }
                  ],
                  voters: 3,
                  status: "open",
                  name: "test"
                }
              ]
            }
          ],
          stream: [19]
        },
        timeline_lookup: [[1, 0]],
        id: 13,
        title: "This is a test topic for polls",
        fancy_title: "This is a test topic for polls",
        posts_count: 1,
        created_at: "2016-12-01T02:39:48.055Z",
        views: 1,
        reply_count: 0,
        participant_count: 1,
        like_count: 0,
        last_posted_at: "2016-12-01T02:39:49.199Z",
        visible: true,
        closed: false,
        archived: false,
        has_summary: false,
        archetype: "regular",
        slug: "this-is-a-test-topic-for-polls",
        category_id: 1,
        word_count: 10,
        deleted_at: null,
        user_id: 1,
        draft: null,
        draft_key: "topic_13",
        draft_sequence: 4,
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
            avatar_template: "/images/avatar.png"
          },
          last_poster: {
            id: 1,
            username: "tgx",
            avatar_template: "/images/avatar.png"
          },
          participants: [
            {
              id: 1,
              username: "tgx",
              avatar_template: "/images/avatar.png",
              post_count: 1
            }
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
              created_at: "2016-11-24T02:10:54.328Z",
              last_posted_at: "2016-11-24T02:10:54.393Z",
              bumped: true,
              bumped_at: "2016-11-24T02:10:54.393Z",
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
                    avatar_template: "/images/avatar.png"
                  }
                }
              ]
            },
            {
              id: 12,
              title: "Some testing topic testing",
              fancy_title: "Some testing topic testing",
              slug: "some-testing-topic-testing",
              posts_count: 4,
              reply_count: 0,
              highest_post_number: 4,
              image_url: null,
              created_at: "2016-11-24T08:36:08.773Z",
              last_posted_at: "2016-12-01T01:15:52.008Z",
              bumped: true,
              bumped_at: "2016-12-01T01:15:52.008Z",
              unseen: false,
              last_read_post_number: 4,
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
              archetype: "regular",
              like_count: 0,
              views: 2,
              category_id: 1,
              posters: [
                {
                  extras: "latest single",
                  description: "Original Poster, Most Recent Poster",
                  user: {
                    id: 1,
                    username: "tgx",
                    avatar_template: "/images/avatar.png"
                  }
                }
              ]
            },
            {
              id: 11,
              title: "Some testing topic",
              fancy_title: "Some testing topic",
              slug: "some-testing-topic",
              posts_count: 1,
              reply_count: 0,
              highest_post_number: 1,
              image_url: null,
              created_at: "2016-11-24T08:35:26.758Z",
              last_posted_at: "2016-11-24T08:35:26.894Z",
              bumped: true,
              bumped_at: "2016-11-24T08:35:26.894Z",
              unseen: false,
              last_read_post_number: 1,
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
              archetype: "regular",
              like_count: 0,
              views: 0,
              category_id: 1,
              posters: [
                {
                  extras: "latest single",
                  description: "Original Poster, Most Recent Poster",
                  user: {
                    id: 1,
                    username: "tgx",
                    avatar_template: "/images/avatar.png"
                  }
                }
              ]
            }
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
          can_flag_topic: true
        },
        highest_post_number: 1,
        last_read_post_number: 1,
        last_read_post_id: 19,
        deleted_by: null,
        has_deleted: false,
        actions_summary: [
          { id: 4, count: 0, hidden: false, can_act: true },
          { id: 7, count: 0, hidden: false, can_act: true },
          { id: 8, count: 0, hidden: false, can_act: true }
        ],
        chunk_size: 20,
        bookmarked: false
      }
    ];
  });

  await visit("/t/this-is-a-test-topic-for-polls/13");

  const polls = find(".poll");

  assert.equal(polls.length, 2, "it should render the polls correctly");
  assert.equal(
    find(".info-number", polls[0]).text(),
    "2",
    "it should display the right number of votes"
  );
  assert.equal(
    find(".info-number", polls[1]).text(),
    "3",
    "it should display the right number of votes"
  );
});

test("Public poll", async assert => {
  // prettier-ignore
  server.get("/t/12.json", () => { // eslint-disable-line no-undef
    return [
      200,
      { "Content-Type": "application/json" },
      {
        post_stream: {
          posts: [
            {
              id: 15,
              name: null,
              username: "tgx",
              avatar_template: "/images/avatar.png",
              created_at: "2017-01-31T08:39:06.237Z",
              cooked:
                '<div class="poll" data-poll-status="open" data-poll-name="poll" data-poll-type="multiple" data-poll-min="1" data-poll-max="3" data-poll-public="true">\n<div>\n<div class="poll-container"><ul>\n<li data-poll-option-id="4d8a15e3cc35750f016ce15a43937620">1</li>\n<li data-poll-option-id="cd314db7dfbac2b10687b6f39abfdf41">2</li>\n<li data-poll-option-id="68b434ff88aeae7054e42cd05a4d9056">3</li>\n</ul></div>\n<div class="poll-info">\n<p><span class="info-number">0</span><span class="info-text">voters</span></p>\n<p>Choose up to <strong>3</strong> options</p>\n<p>Votes are public.</p>\n</div>\n</div>\n<div class="poll-buttons">\n<a title="Cast your votes">Vote now!</a><a title="Display the poll results">Show results</a>\n</div>\n</div>',
              post_number: 1,
              post_type: 1,
              updated_at: "2017-01-31T08:39:06.237Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              avg_time: null,
              incoming_link_count: 0,
              reads: 1,
              score: 0,
              yours: true,
              topic_id: 12,
              topic_slug: "this-is-a-topic-created-for-testing",
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
                { id: 8, can_act: true }
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
              polls: [
                {
                  options: [
                    {
                      id: "4d8a15e3cc35750f016ce15a43937620",
                      html: "1",
                      votes: 29
                    },
                    {
                      id: "cd314db7dfbac2b10687b6f39abfdf41",
                      html: "2",
                      votes: 29
                    },
                    {
                      id: "68b434ff88aeae7054e42cd05a4d9056",
                      html: "3",
                      votes: 42
                    }
                  ],
                  voters: 100,
                  status: "open",
                  name: "poll",
                  type: "multiple",
                  min: "1",
                  max: "3",
                  public: "true"
                }
              ]
            }
          ],
          stream: [15]
        },
        timeline_lookup: [[1, 0]],
        id: 12,
        title: "This is a topic created for testing",
        fancy_title: "This is a topic created for testing",
        posts_count: 1,
        created_at: "2017-01-31T08:39:06.094Z",
        views: 1,
        reply_count: 0,
        participant_count: 1,
        like_count: 0,
        last_posted_at: "2017-01-31T08:39:06.237Z",
        visible: true,
        closed: false,
        archived: false,
        has_summary: false,
        archetype: "regular",
        slug: "this-is-a-topic-created-for-testing",
        category_id: 1,
        word_count: 13,
        deleted_at: null,
        user_id: 1,
        draft: null,
        draft_key: "topic_12",
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
            avatar_template: "/images/avatar.png"
          },
          last_poster: {
            id: 1,
            username: "tgx",
            avatar_template: "/images/avatar.png"
          },
          participants: [
            {
              id: 1,
              username: "tgx",
              avatar_template: "/images/avatar.png",
              post_count: 1,
              primary_group_name: null,
              primary_group_flair_url: null,
              primary_group_flair_color: null,
              primary_group_flair_bg_color: null
            }
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
              created_at: "2017-01-31T07:53:45.363Z",
              last_posted_at: "2017-01-31T07:53:45.439Z",
              bumped: true,
              bumped_at: "2017-01-31T07:53:45.439Z",
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
              featured_link: null,
              posters: [
                {
                  extras: "latest single",
                  description: "Original Poster, Most Recent Poster",
                  user: {
                    id: -1,
                    username: "system",
                    avatar_template: "/images/avatar.png"
                  }
                }
              ]
            },
            {
              id: 11,
              title: "This is a test post to try out posts",
              fancy_title: "This is a test post to try out posts",
              slug: "this-is-a-test-post-to-try-out-posts",
              posts_count: 1,
              reply_count: 0,
              highest_post_number: 1,
              image_url: null,
              created_at: "2017-01-31T07:55:58.407Z",
              last_posted_at: "2017-01-31T07:55:58.634Z",
              bumped: true,
              bumped_at: "2017-01-31T07:55:58.634Z",
              unseen: false,
              last_read_post_number: 1,
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
              archetype: "regular",
              like_count: 0,
              views: 1,
              category_id: 1,
              featured_link: null,
              posters: [
                {
                  extras: "latest single",
                  description: "Original Poster, Most Recent Poster",
                  user: {
                    id: 1,
                    username: "tgx",
                    avatar_template: "/images/avatar.png"
                  }
                }
              ]
            }
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
          can_flag_topic: true
        },
        highest_post_number: 1,
        last_read_post_number: 1,
        last_read_post_id: 15,
        deleted_by: null,
        has_deleted: false,
        actions_summary: [
          { id: 4, count: 0, hidden: false, can_act: true },
          { id: 7, count: 0, hidden: false, can_act: true },
          { id: 8, count: 0, hidden: false, can_act: true }
        ],
        chunk_size: 20,
        bookmarked: false,
        featured_link: null
      }
    ];
  });

  // prettier-ignore
  server.get("/polls/voters.json", request => { // eslint-disable-line no-undef
    let body = {};

    if (
      request.queryParams["post_id"] === "15" &&
      request.queryParams["poll_name"] === "poll" &&
      request.queryParams["page"] === "1" &&
      request.queryParams["option_id"] === "68b434ff88aeae7054e42cd05a4d9056"
    ) {
      body = {
        voters: {
          "68b434ff88aeae7054e42cd05a4d9056": [
            {
              id: 402,
              username: "bruce400",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 409,
              username: "bruce407",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 410,
              username: "bruce408",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 411,
              username: "bruce409",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 421,
              username: "bruce419",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 422,
              username: "bruce420",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 423,
              username: "bruce421",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 426,
              username: "bruce424",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 429,
              username: "bruce427",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 437,
              username: "bruce435",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 440,
              username: "bruce438",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 442,
              username: "bruce440",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 443,
              username: "bruce441",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 445,
              username: "bruce443",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 450,
              username: "bruce448",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 451,
              username: "bruce449",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 453,
              username: "bruce451",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 455,
              username: "bruce453",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 456,
              username: "bruce454",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 461,
              username: "bruce459",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 466,
              username: "bruce464",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 468,
              username: "bruce466",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 477,
              username: "bruce475",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 478,
              username: "bruce476",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 498,
              username: "bruce496",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            }
          ]
        }
      };
    } else if (
      request.queryParams["post_id"] === "15" &&
      request.queryParams["poll_name"] === "poll"
    ) {
      body = {
        voters: {
          "68b434ff88aeae7054e42cd05a4d9056": [
            {
              id: 402,
              username: "bruce400",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 409,
              username: "bruce407",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 410,
              username: "bruce408",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 411,
              username: "bruce409",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 421,
              username: "bruce419",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 422,
              username: "bruce420",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 423,
              username: "bruce421",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 426,
              username: "bruce424",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 429,
              username: "bruce427",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 437,
              username: "bruce435",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 440,
              username: "bruce438",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 442,
              username: "bruce440",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 443,
              username: "bruce441",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 445,
              username: "bruce443",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 450,
              username: "bruce448",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 451,
              username: "bruce449",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 453,
              username: "bruce451",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 455,
              username: "bruce453",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 461,
              username: "bruce459",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 466,
              username: "bruce464",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 468,
              username: "bruce466",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 477,
              username: "bruce475",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 478,
              username: "bruce476",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 498,
              username: "bruce496",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 501,
              username: "bruce499",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            }
          ],
          cd314db7dfbac2b10687b6f39abfdf41: [
            {
              id: 403,
              username: "bruce401",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 404,
              username: "bruce402",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 405,
              username: "bruce403",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 408,
              username: "bruce406",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 413,
              username: "bruce411",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 414,
              username: "bruce412",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 416,
              username: "bruce414",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 418,
              username: "bruce416",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 419,
              username: "bruce417",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 433,
              username: "bruce431",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 434,
              username: "bruce432",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 435,
              username: "bruce433",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 439,
              username: "bruce437",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 441,
              username: "bruce439",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 448,
              username: "bruce446",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 449,
              username: "bruce447",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 452,
              username: "bruce450",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 462,
              username: "bruce460",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 464,
              username: "bruce462",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 465,
              username: "bruce463",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 470,
              username: "bruce468",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 471,
              username: "bruce469",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 474,
              username: "bruce472",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 476,
              username: "bruce474",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 486,
              username: "bruce484",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            }
          ],
          "4d8a15e3cc35750f016ce15a43937620": [
            {
              id: 406,
              username: "bruce404",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 407,
              username: "bruce405",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 412,
              username: "bruce410",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 415,
              username: "bruce413",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 417,
              username: "bruce415",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 420,
              username: "bruce418",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 424,
              username: "bruce422",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 425,
              username: "bruce423",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 427,
              username: "bruce425",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 428,
              username: "bruce426",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 430,
              username: "bruce428",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 431,
              username: "bruce429",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 432,
              username: "bruce430",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 436,
              username: "bruce434",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 438,
              username: "bruce436",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 444,
              username: "bruce442",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 446,
              username: "bruce444",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 447,
              username: "bruce445",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 454,
              username: "bruce452",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 458,
              username: "bruce456",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 459,
              username: "bruce457",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 481,
              username: "bruce479",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 492,
              username: "bruce490",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 494,
              username: "bruce492",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            },
            {
              id: 500,
              username: "bruce498",
              avatar_template: "/images/avatar.png",
              name: "Bruce Wayne",
              title: null
            }
          ]
        }
      };
    }

    return [200, { "Content-Type": "application/json" }, body];
  });

  await visit("/t/this-is-a-topic-created-for-testing/12");

  const polls = find(".poll");
  assert.equal(polls.length, 1, "it should render the poll correctly");

  await click("button.toggle-results");

  assert.equal(
    find(".poll-voters:first li").length,
    25,
    "it should display the right number of voters"
  );

  await click(".poll-voters-toggle-expand:first a");

  assert.equal(
    find(".poll-voters:first li").length,
    26,
    "it should display the right number of voters"
  );
});

test("Public number poll", async assert => {
  // prettier-ignore
  server.get("/t/13.json", () => { // eslint-disable-line no-undef
    return [
      200,
      { "Content-Type": "application/json" },
      {
        post_stream: {
          posts: [
            {
              id: 16,
              name: null,
              username: "tgx",
              avatar_template: "/images/avatar.png",
              created_at: "2017-01-31T09:11:11.281Z",
              cooked:
                '<div class="poll" data-poll-status="open" data-poll-name="poll" data-poll-type="number" data-poll-min="1" data-poll-max="20" data-poll-step="1" data-poll-public="true">\n<div>\n<div class="poll-container"><ul>\n<li data-poll-option-id="4d8a15e3cc35750f016ce15a43937620">1</li>\n<li data-poll-option-id="cd314db7dfbac2b10687b6f39abfdf41">2</li>\n<li data-poll-option-id="68b434ff88aeae7054e42cd05a4d9056">3</li>\n<li data-poll-option-id="aa2393b424f2f395abb63bf785760a3b">4</li>\n<li data-poll-option-id="8b2f2930cac0574c3450f5db9a6fb7f9">5</li>\n<li data-poll-option-id="60cad69e0cfcb3fa77a68d11d3758002">6</li>\n<li data-poll-option-id="9ab1070dec27185440cdabb4948a5e9a">7</li>\n<li data-poll-option-id="99944bf07088f815a966d585daed6a7e">8</li>\n<li data-poll-option-id="345a83050400d78f5fac98d381b45e23">9</li>\n<li data-poll-option-id="46c01f638a50d86e020f47469733b8be">10</li>\n<li data-poll-option-id="07f7f85b2a3809faff68a35e81a664eb">11</li>\n<li data-poll-option-id="b3e8c14e714910cb8dd7089f097be133">12</li>\n<li data-poll-option-id="b4f15431e07443c372d521e4ed131abe">13</li>\n<li data-poll-option-id="a77bc9a30933e5af327211db2da46e17">14</li>\n<li data-poll-option-id="303d7c623da1985e94a9d27d43596934">15</li>\n<li data-poll-option-id="4e885ead68ff4456f102843df9fbbd7f">16</li>\n<li data-poll-option-id="cbf6e2b72e403b12d7ee63a138f32647">17</li>\n<li data-poll-option-id="9364fa2d67fbd62c473165441ad69571">18</li>\n<li data-poll-option-id="eb8661f072794ea57baa7827cd8ffc88">19</li>\n<li data-poll-option-id="b373436e858c0821135f994a5ff3345f">20</li>\n</ul></div>\n<div class="poll-info">\n<p><span class="info-number">0</span><span class="info-text">voters</span></p>\n<p>Votes are public.</p>\n</div>\n</div>\n<div class="poll-buttons"><a title="Display the poll results">Show results</a></div>\n</div>',
              post_number: 1,
              post_type: 1,
              updated_at: "2017-01-31T09:11:11.281Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              avg_time: null,
              incoming_link_count: 0,
              reads: 1,
              score: 0,
              yours: true,
              topic_id: 13,
              topic_slug: "this-is-a-topic-for-testing-number-poll",
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
                { id: 8, can_act: true }
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
              polls: [
                {
                  options: [
                    {
                      id: "4d8a15e3cc35750f016ce15a43937620",
                      html: "1",
                      votes: 2
                    },
                    {
                      id: "cd314db7dfbac2b10687b6f39abfdf41",
                      html: "2",
                      votes: 1
                    },
                    {
                      id: "68b434ff88aeae7054e42cd05a4d9056",
                      html: "3",
                      votes: 1
                    },
                    {
                      id: "aa2393b424f2f395abb63bf785760a3b",
                      html: "4",
                      votes: 0
                    },
                    {
                      id: "8b2f2930cac0574c3450f5db9a6fb7f9",
                      html: "5",
                      votes: 1
                    },
                    {
                      id: "60cad69e0cfcb3fa77a68d11d3758002",
                      html: "6",
                      votes: 0
                    },
                    {
                      id: "9ab1070dec27185440cdabb4948a5e9a",
                      html: "7",
                      votes: 1
                    },
                    {
                      id: "99944bf07088f815a966d585daed6a7e",
                      html: "8",
                      votes: 3
                    },
                    {
                      id: "345a83050400d78f5fac98d381b45e23",
                      html: "9",
                      votes: 3
                    },
                    {
                      id: "46c01f638a50d86e020f47469733b8be",
                      html: "10",
                      votes: 3
                    },
                    {
                      id: "07f7f85b2a3809faff68a35e81a664eb",
                      html: "11",
                      votes: 2
                    },
                    {
                      id: "b3e8c14e714910cb8dd7089f097be133",
                      html: "12",
                      votes: 4
                    },
                    {
                      id: "b4f15431e07443c372d521e4ed131abe",
                      html: "13",
                      votes: 2
                    },
                    {
                      id: "a77bc9a30933e5af327211db2da46e17",
                      html: "14",
                      votes: 2
                    },
                    {
                      id: "303d7c623da1985e94a9d27d43596934",
                      html: "15",
                      votes: 2
                    },
                    {
                      id: "4e885ead68ff4456f102843df9fbbd7f",
                      html: "16",
                      votes: 1
                    },
                    {
                      id: "cbf6e2b72e403b12d7ee63a138f32647",
                      html: "17",
                      votes: 2
                    },
                    {
                      id: "9364fa2d67fbd62c473165441ad69571",
                      html: "18",
                      votes: 2
                    },
                    {
                      id: "eb8661f072794ea57baa7827cd8ffc88",
                      html: "19",
                      votes: 1
                    },
                    {
                      id: "b373436e858c0821135f994a5ff3345f",
                      html: "20",
                      votes: 2
                    }
                  ],
                  voters: 35,
                  status: "open",
                  name: "poll",
                  type: "number",
                  min: "1",
                  max: "20",
                  step: "1",
                  public: "true"
                }
              ]
            }
          ],
          stream: [16]
        },
        timeline_lookup: [[1, 0]],
        id: 13,
        title: "This is a topic for testing number poll",
        fancy_title: "This is a topic for testing number poll",
        posts_count: 1,
        created_at: "2017-01-31T09:11:11.161Z",
        views: 1,
        reply_count: 0,
        participant_count: 1,
        like_count: 0,
        last_posted_at: "2017-01-31T09:11:11.281Z",
        visible: true,
        closed: false,
        archived: false,
        has_summary: false,
        archetype: "regular",
        slug: "this-is-a-topic-for-testing-number-poll",
        category_id: 1,
        word_count: 12,
        deleted_at: null,
        user_id: 1,
        draft: null,
        draft_key: "topic_13",
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
            avatar_template: "/images/avatar.png"
          },
          last_poster: {
            id: 1,
            username: "tgx",
            avatar_template: "/images/avatar.png"
          },
          participants: [
            {
              id: 1,
              username: "tgx",
              avatar_template: "/images/avatar.png",
              post_count: 1,
              primary_group_name: null,
              primary_group_flair_url: null,
              primary_group_flair_color: null,
              primary_group_flair_bg_color: null
            }
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
              created_at: "2017-01-31T07:53:45.363Z",
              last_posted_at: "2017-01-31T07:53:45.439Z",
              bumped: true,
              bumped_at: "2017-01-31T07:53:45.439Z",
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
              featured_link: null,
              posters: [
                {
                  extras: "latest single",
                  description: "Original Poster, Most Recent Poster",
                  user: {
                    id: -1,
                    username: "system",
                    avatar_template: "/images/avatar.png"
                  }
                }
              ]
            },
            {
              id: 11,
              title: "This is a test post to try out posts",
              fancy_title: "This is a test post to try out posts",
              slug: "this-is-a-test-post-to-try-out-posts",
              posts_count: 1,
              reply_count: 0,
              highest_post_number: 1,
              image_url: null,
              created_at: "2017-01-31T07:55:58.407Z",
              last_posted_at: "2017-01-31T07:55:58.634Z",
              bumped: true,
              bumped_at: "2017-01-31T07:55:58.634Z",
              unseen: false,
              last_read_post_number: 1,
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
              archetype: "regular",
              like_count: 0,
              views: 1,
              category_id: 1,
              featured_link: null,
              posters: [
                {
                  extras: "latest single",
                  description: "Original Poster, Most Recent Poster",
                  user: {
                    id: 1,
                    username: "tgx",
                    avatar_template: "/images/avatar.png"
                  }
                }
              ]
            },
            {
              id: 12,
              title: "This is a topic created for testing",
              fancy_title: "This is a topic created for testing",
              slug: "this-is-a-topic-created-for-testing",
              posts_count: 1,
              reply_count: 0,
              highest_post_number: 1,
              image_url: null,
              created_at: "2017-01-31T08:39:06.094Z",
              last_posted_at: "2017-01-31T08:39:06.237Z",
              bumped: true,
              bumped_at: "2017-01-31T09:10:46.528Z",
              unseen: false,
              last_read_post_number: 1,
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
              archetype: "regular",
              like_count: 0,
              views: 1,
              category_id: 1,
              featured_link: null,
              posters: [
                {
                  extras: "latest single",
                  description: "Original Poster, Most Recent Poster",
                  user: {
                    id: 1,
                    username: "tgx",
                    avatar_template: "/images/avatar.png"
                  }
                }
              ]
            }
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
          can_flag_topic: true
        },
        highest_post_number: 1,
        last_read_post_number: 1,
        last_read_post_id: 16,
        deleted_by: null,
        has_deleted: false,
        actions_summary: [
          { id: 4, count: 0, hidden: false, can_act: true },
          { id: 7, count: 0, hidden: false, can_act: true },
          { id: 8, count: 0, hidden: false, can_act: true }
        ],
        chunk_size: 20,
        bookmarked: false,
        featured_link: null
      }
    ];
  });

  // prettier-ignore
  server.get("/polls/voters.json", request => { // eslint-disable-line no-undef
    let body = {};

    if (
      request.queryParams["post_id"] === "16" &&
      request.queryParams["poll_name"] === "poll" &&
      request.queryParams["page"] === "1"
    ) {
      body = {
        voters: [
          {
            id: 418,
            username: "bruce416",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 420,
            username: "bruce418",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 423,
            username: "bruce421",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 426,
            username: "bruce424",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 428,
            username: "bruce426",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 429,
            username: "bruce427",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 432,
            username: "bruce430",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 433,
            username: "bruce431",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 434,
            username: "bruce432",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 436,
            username: "bruce434",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          }
        ]
      };
    } else if (
      request.queryParams["post_id"] === "16" &&
      request.queryParams["poll_name"] === "poll"
    ) {
      body = {
        voters: [
          {
            id: 402,
            username: "bruce400",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 403,
            username: "bruce401",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 404,
            username: "bruce402",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 405,
            username: "bruce403",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 406,
            username: "bruce404",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 407,
            username: "bruce405",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 408,
            username: "bruce406",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 409,
            username: "bruce407",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 410,
            username: "bruce408",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 411,
            username: "bruce409",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 412,
            username: "bruce410",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 413,
            username: "bruce411",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 414,
            username: "bruce412",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 415,
            username: "bruce413",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 416,
            username: "bruce414",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 417,
            username: "bruce415",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 419,
            username: "bruce417",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 421,
            username: "bruce419",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 422,
            username: "bruce420",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 424,
            username: "bruce422",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 425,
            username: "bruce423",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 427,
            username: "bruce425",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 430,
            username: "bruce428",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 431,
            username: "bruce429",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          },
          {
            id: 435,
            username: "bruce433",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
            title: null
          }
        ]
      };
    }

    return [200, { "Content-Type": "application/json" }, body];
  });

  await visit("/t/this-is-a-topic-for-testing-number-poll/13");

  const polls = find(".poll");
  assert.equal(polls.length, 1, "it should render the poll correctly");

  await click("button.toggle-results");

  assert.equal(
    find(".poll-voters:first li").length,
    25,
    "it should display the right number of voters"
  );

  assert.ok(
    find(".poll-voters:first li:first a").attr("href"),
    "user URL exists"
  );

  await click(".poll-voters-toggle-expand:first a");

  assert.equal(
    find(".poll-voters:first li").length,
    35,
    "it should display the right number of voters"
  );
});
