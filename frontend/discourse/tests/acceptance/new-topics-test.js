import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("New Topics - New new view enabled", function (needs) {
  needs.user({
    unified_new_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/new.json", () => {
      return helper.response({
        topic_list: { can_create_topic: true, topics: [] },
      });
    });
  });

  test("visiting new page when there are no new topics", async function (assert) {
    await visit("/new");
    assert
      .dom(".topic-list-bottom .empty-state__title")
      .hasText(i18n("topics.none.education.unified_new"));
  });
});
