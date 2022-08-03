import {
  acceptance,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";

acceptance("Welcome Topic Banner", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {

      const json = cloneJSON(discoveryFixtures["/latest.json"]);
      json.topic_list.show_welcome_topic_banner = true
      return helper.response(json);
    });
  });

  test("Navigation", async function (assert) {
    await visit("/");
    assert.ok(exists(".welcome-topic-banner"), "has the welcome topic banner");
    assert.ok(exists("button.welcome-topic-cta"), "has the welcome topic edit button");
  });
});
