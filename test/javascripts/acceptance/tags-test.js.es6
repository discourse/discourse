import { acceptance } from "helpers/qunit-helpers";
acceptance("Tags", { loggedIn: true });

QUnit.test("list the tags", assert => {
  visit("/tags");

  andThen(() => {
    assert.ok($("body.tags-page").length, "has the body class");
    assert.ok(exists(".tag-eviltrout"), "shows the evil trout tag");
  });
});

acceptance("Tags listed by group", {
  loggedIn: true,
  settings: {
    tags_listed_by_group: true
  }
});

QUnit.test("list the tags in groups", assert => {
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
                { id: "escort", text: "escort", count: 1, pm_count: 0 },
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

  visit("/tags");
  andThen(() => {
    assert.equal(
      $(".tag-list").length,
      4,
      "shows separate lists for the 3 groups and the ungrouped tags"
    );
    assert.ok(
      _.isEqual(
        _.map($(".tag-list h3"), i => {
          return $(i).text();
        }),
        ["Ford Cars", "Honda Cars", "Makes", "Other Tags"]
      ),
      "shown in given order and with tags that are not in a group"
    );
    assert.ok(
      _.isEqual(
        _.map($(".tag-list:first .discourse-tag"), i => {
          return $(i).text();
        }),
        ["focus", "escort"]
      ),
      "shows the tags in default sort (by count)"
    );
  });
});
