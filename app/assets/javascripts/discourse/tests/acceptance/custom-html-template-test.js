import { visit } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { registerTemporaryModule } from "discourse/tests/helpers/temporary-module-helper";
import { withSilencedDeprecationsAsync } from "discourse-common/lib/deprecated";

acceptance("CustomHTML template", function (needs) {
  needs.hooks.beforeEach(() => {
    registerTemporaryModule(
      "discourse/templates/top",
      hbs`<span class='top-span'>TOP</span>`
    );
  });

  test("renders custom template", async function (assert) {
    await withSilencedDeprecationsAsync(
      "discourse.custom_html_template",
      async () => {
        await visit("/static/faq");
        assert.dom("span.top-span").hasText("TOP", "inserted the template");
      }
    );
  });
});
