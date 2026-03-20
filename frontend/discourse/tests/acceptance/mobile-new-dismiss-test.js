import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("New dismiss - Mobile", function (needs) {
  needs.mobileView();
  needs.settings({ floating_dismiss_topics_on_mobile: true });
  needs.user({ new_new_view_enabled: true });
  needs.pretender((server, helper) => {
    const topicList = cloneJSON(topicFixtures["/latest.json"]);
    topicList.topic_list.more_topics_url = null;

    server.get("/new.json", () => {
      return helper.response(topicList);
    });
  });

  test("shows the floating dismiss split-button but hides the bottom chevron on mobile", async function (assert) {
    await visit("/new");

    assert.dom("#dismiss-new-top").exists();
    assert.dom("#dismiss-new-menu-top .d-icon-chevron-down").exists();
    assert.dom("#dismiss-new-bottom").exists();
    assert.dom("#dismiss-new-menu-bottom").isNotVisible();
  });
});
