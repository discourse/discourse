import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
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
        assert.strictEqual(
          query("span.top-span").innerText,
          "TOP",
          "it inserted the template"
        );
      }
    );
  });
});
