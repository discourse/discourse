import { acceptance } from "helpers/qunit-helpers";

acceptance("Tags intersection", {
  loggedIn: true,
  site: { can_tag_topics: true },
  settings: { tagging_enabled: true },
  pretend(server, helper) {
    server.get("/tags/first/notifications", () => {
      return helper.response({
        tag_notification: { id: "first", notification_level: 1 }
      });
    });
    server.get("/tags/intersection/first/second.json", () => {
      return helper.response({
        users: [],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft_key: "new_topic",
          topics: [{ id: 16, posters: [] }],
          tags: [
            { id: 1, name: "first", topic_count: 1 },
            { id: 2, name: "second", topic_count: 1 }
          ]
        }
      });
    });
  }
});

QUnit.test("Populate tags when creating new topic", async assert => {
  await visit("/tags/intersection/first/second");
  await click("#create-topic");

  assert.ok(exists(".mini-tag-chooser"), "The tag selector appears");
  assert.equal(
    $(".mini-tag-chooser")
      .text()
      .trim(),
    "first, second",
    "populates the tags when clicking 'New topic'"
  );
});
