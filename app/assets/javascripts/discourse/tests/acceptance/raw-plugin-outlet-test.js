import { queryAll } from "discourse/tests/helpers/qunit-helpers";
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
  test("Renders the raw plugin outlet", async function (assert) {
    await visit("/");
    assert.ok(queryAll(".topic-lala").length > 0, "it renders the outlet");
    assert.equal(
      queryAll(".topic-lala:nth-of-type(1)")[0].innerText,
      "11557",
      "it has the topic id"
    );
  });
});
