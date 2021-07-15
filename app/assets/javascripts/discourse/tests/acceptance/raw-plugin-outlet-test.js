import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import {
  addRawTemplate,
  removeRawTemplate,
} from "discourse-common/lib/raw-templates";
import { compile } from "handlebars";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

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
    assert.ok(exists(".topic-lala"), "it renders the outlet");
    assert.equal(
      query(".topic-lala:nth-of-type(1)").innerText,
      "11557",
      "it has the topic id"
    );
  });
});
