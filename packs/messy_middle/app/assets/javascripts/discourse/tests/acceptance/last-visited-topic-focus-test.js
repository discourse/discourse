import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";

acceptance("Last Visited Topic Focus", function (needs) {
  needs.pretender((server, helper) => {
    const fixture = cloneJSON(topicFixtures["/t/54077.json"]);
    fixture.id = 11996;
    fixture.slug =
      "its-really-hard-to-navigate-the-create-topic-reply-pane-with-the-keyboard";
    server.get("/t/11996.json", () => helper.response(fixture));
  });
  test("last visited topic receives focus when you return back to the topic list", async function (assert) {
    await visit("/");
    await visit(
      "/t/its-really-hard-to-navigate-the-create-topic-reply-pane-with-the-keyboard/11996"
    );
    await visit("/");
    const visitedTopicTitle = query(
      '.topic-list-body tr[data-topic-id="11996"] .main-link'
    );
    assert.ok(visitedTopicTitle.classList.contains("focused"));
  });
});
