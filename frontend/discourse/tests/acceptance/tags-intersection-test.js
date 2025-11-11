import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Tags intersection", function (needs) {
  needs.user();
  needs.site({ can_tag_topics: true });
  needs.settings({ tagging_enabled: true });

  test("Populate tags when creating new topic", async function (assert) {
    pretender.get("/tags/intersection/first/second.json", () => {
      return response({
        users: [],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft_key: "new_topic",
          topics: [{ id: 16, posters: [] }],
          tags: [
            { id: 1, name: "second", topic_count: 1 },
            { id: 2, name: "first", topic_count: 1 },
          ],
        },
      });
    });

    await visit("/tags/intersection/first/second");
    await click("#create-topic");

    assert.dom(".mini-tag-chooser").exists("the tag selector appears");
    assert
      .dom(".composer-fields .mini-tag-chooser")
      .hasText("first, second", "populates the tags when clicking 'New topic'");
  });

  test("correctly passes the category filter", async function (assert) {
    pretender.get("/tags/intersection/sour/tangy.json", (request) => {
      assert.deepEqual(request.queryParams, { category: "fruits" });
      assert.step("request");

      return response({
        users: [],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft_key: "new_topic",
          topics: [{ id: 16, posters: [] }],
          tags: [
            { id: 1, name: "second", topic_count: 1 },
            { id: 2, name: "first", topic_count: 1 },
          ],
        },
      });
    });

    await visit("/tags/intersection/sour/tangy?category=fruits");
    assert.verifySteps(["request"]);
  });
});
