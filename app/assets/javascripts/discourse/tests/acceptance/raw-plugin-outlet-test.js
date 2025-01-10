import { visit } from "@ember/test-helpers";
import { compile } from "handlebars";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { withSilencedDeprecations } from "discourse-common/lib/deprecated";
import {
  addRawTemplate,
  removeRawTemplate,
} from "discourse-common/lib/raw-templates";

const CONNECTOR =
  "javascripts/raw-test/connectors/topic-list-before-status/lala";

acceptance("Raw Plugin Outlet", function (needs) {
  needs.hooks.beforeEach(function () {
    withSilencedDeprecations("discourse.hbr-topic-list-overrides", () => {
      addRawTemplate(
        CONNECTOR,
        compile(`<span class='topic-lala'>{{context.topic.id}}</span>`)
      );
    });
  });

  needs.hooks.afterEach(function () {
    removeRawTemplate(CONNECTOR);
  });

  test("Renders the raw plugin outlet", async function (assert) {
    await visit("/");
    assert.dom(".topic-lala").exists("renders the outlet");
    assert.dom(".topic-lala").hasText("11557", "has the topic id");
  });
});
