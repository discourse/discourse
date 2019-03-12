import { replaceCurrentUser, acceptance } from "helpers/qunit-helpers";
acceptance("Tags", { loggedIn: true });

QUnit.test("list the tags", async assert => {
  await visit("/tags");

  assert.ok($("body.tags-page").length, "has the body class");
  assert.ok(
    $('*[data-tag-name="eviltrout"]').length,
    "shows the eviltrout tag"
  );
});

acceptance("Tags listed by group", {
  loggedIn: true,
  settings: {
    tags_listed_by_group: true
  }
});

QUnit.test("list the tags in groups", async assert => {
  // prettier-ignore
  server.get("/tags", () => { // eslint-disable-line no-undef
    return [
      200,
      { "Content-Type": "application/json" },
      {
        tags: [{ id: "planned", text: "planned", count: 7, pm_count: 0 }],
        extras: {
          tag_groups: [
            {
              id: 2,
              name: "Ford Cars",
              tags: [
                { id: "Escort", text: "Escort", count: 1, pm_count: 0 },
                { id: "focus", text: "focus", count: 3, pm_count: 0 }
              ]
            },
            {
              id: 1,
              name: "Honda Cars",
              tags: [
                { id: "civic", text: "civic", count: 4, pm_count: 0 },
                { id: "accord", text: "accord", count: 2, pm_count: 0 }
              ]
            },
            {
              id: 1,
              name: "Makes",
              tags: [
                { id: "ford", text: "ford", count: 5, pm_count: 0 },
                { id: "honda", text: "honda", count: 6, pm_count: 0 }
              ]
            }
          ]
        }
      }
    ];
  });

  await visit("/tags");
  assert.equal(
    $(".tag-list").length,
    4,
    "shows separate lists for the 3 groups and the ungrouped tags"
  );
  assert.deepEqual(
    $(".tag-list h3")
      .toArray()
      .map(i => {
        return $(i).text();
      }),
    ["Ford Cars", "Honda Cars", "Makes", "Other Tags"],
    "shown in given order and with tags that are not in a group"
  );
  assert.deepEqual(
    $(".tag-list:first .discourse-tag")
      .toArray()
      .map(i => {
        return $(i).text();
      }),
    ["focus", "Escort"],
    "shows the tags in default sort (by count)"
  );
  assert.deepEqual(
    $(".tag-list:first .discourse-tag")
      .toArray()
      .map(i => {
        return $(i).attr("href");
      }),
    ["/tags/focus", "/tags/escort"],
    "always uses lowercase URLs for mixed case tags"
  );
});

test("new topic button is not available for staff-only tags", async assert => {
  /* global server */
  server.get("/tags/regular-tag/notifications", () => [
    200,
    { "Content-Type": "application/json" },
    { tag_notification: { id: "regular-tag", notification_level: 1 } }
  ]);

  server.get("/tags/regular-tag/l/latest.json", () => [
    200,
    { "Content-Type": "application/json" },
    {
      users: [],
      primary_groups: [],
      topic_list: {
        can_create_topic: true,
        draft: null,
        draft_key: "new_topic",
        draft_sequence: 1,
        per_page: 30,
        tags: [
          {
            id: 1,
            name: "regular-tag",
            topic_count: 1
          }
        ],
        topics: []
      }
    }
  ]);

  server.get("/tags/staff-only-tag/notifications", () => [
    200,
    { "Content-Type": "application/json" },
    { tag_notification: { id: "staff-only-tag", notification_level: 1 } }
  ]);

  server.get("/tags/staff-only-tag/l/latest.json", () => [
    200,
    { "Content-Type": "application/json" },
    {
      users: [],
      primary_groups: [],
      topic_list: {
        can_create_topic: true,
        draft: null,
        draft_key: "new_topic",
        draft_sequence: 1,
        per_page: 30,
        tags: [
          {
            id: 1,
            name: "staff-only-tag",
            topic_count: 1,
            staff: true
          }
        ],
        topics: []
      }
    }
  ]);

  replaceCurrentUser({ staff: false });

  await visit("/tags/regular-tag");
  assert.ok(find("#create-topic:disabled").length === 0);

  await visit("/tags/staff-only-tag");
  assert.ok(find("#create-topic:disabled").length === 1);

  replaceCurrentUser({ staff: true });

  await visit("/tags/regular-tag");
  assert.ok(find("#create-topic:disabled").length === 0);

  await visit("/tags/staff-only-tag");
  assert.ok(find("#create-topic:disabled").length === 0);
});
