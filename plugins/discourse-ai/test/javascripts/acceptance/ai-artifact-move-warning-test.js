import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("AI artifacts | move warning", function (needs) {
  needs.user({ admin: true });
  needs.settings({
    discourse_ai_enabled: true,
    ai_artifact_security: "strict",
  });
  needs.pretender((server, helper) => {
    server.get("/t/12.json", () => {
      const topic = cloneJSON(topicFixtures["/t/12/1.json"]);
      topic.is_bot_pm = true;
      return helper.response(topic);
    });
  });

  test("explains live artifact access without adding a confirmation step", async function (assert) {
    pretender.post("/t/12/move-posts", () => {
      assert.step("move");
      return response({ success: true });
    });

    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");
    await click(".selected-posts .move-to-topic");

    assert
      .dom(".ai-artifact-move-warning")
      .includesText("Separate shared snapshots are not affected");
    assert.verifySteps([], "opening the move dialog does not move anything");

    await fillIn("#split-topic-name", "Private artifact conversation");
    await click(".d-modal__footer .btn-primary");
    assert.verifySteps(["move"], "the normal move button submits directly");
    assert.dom(".dialog-container").doesNotExist();
  });

  test("does not add an AI warning to ordinary private conversations", async function (assert) {
    pretender.get("/t/12.json", () =>
      response(cloneJSON(topicFixtures["/t/12/1.json"]))
    );

    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");
    await click(".selected-posts .move-to-topic");

    assert.dom(".ai-artifact-move-warning").doesNotExist();
  });
});
