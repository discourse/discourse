import { acceptance } from "helpers/qunit-helpers";
import compile from "handlebars-compiler";
import {
  addRawTemplate,
  removeRawTemplate
} from "discourse-common/lib/raw-templates";

const CONNECTOR =
  "javascripts/raw-test/connectors/topic-list-before-status/lala";

acceptance("Raw Plugin Outlet", {
  beforeEach() {
    addRawTemplate(
      CONNECTOR,
      compile(`<span class='topic-lala'>{{context.topic.id}}</span>`)
    );
  },

  afterEach() {
    removeRawTemplate(CONNECTOR);
  }
});

QUnit.test("Renders the raw plugin outlet", async assert => {
  await visit("/");
  assert.ok(find(".topic-lala").length > 0, "it renders the outlet");
  assert.equal(
    find(".topic-lala:eq(0)").text(),
    "11557",
    "it has the topic id"
  );
});
