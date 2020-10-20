import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import compile from "handlebars-compiler";
import {
  addRawTemplate,
  removeRawTemplate,
} from "discourse-common/lib/raw-templates";

const CONNECTOR =
  "javascripts/raw-test/connectors/topic-list-before-status/lala";

acceptance("Raw Plugin Outlet", function (needs) {
  needs.hooks.beforeEach(() => {
    addRawTemplate(
      CONNECTOR,
      compile(`<span class='topic-lala'>{{context.topic.id}}</span>`)
    );
  });

  needs.hooks.afterEach(() => {
    removeRawTemplate(CONNECTOR);
  });
  test("Renders the raw plugin outlet", async (assert) => {
    await visit("/");
    assert.ok(find(".topic-lala").length > 0, "it renders the outlet");
    assert.equal(
      find(".topic-lala:eq(0)").text(),
      "11557",
      "it has the topic id"
    );
  });
});
