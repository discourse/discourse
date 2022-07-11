import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("CustomHTML template", function (needs) {
  needs.hooks.beforeEach(() => {
    // eslint-disable-next-line no-undef
    Ember.TEMPLATES["top"] = hbs`<span class='top-span'>TOP</span>`;
  });

  needs.hooks.afterEach(() => {
    // eslint-disable-next-line no-undef
    delete Ember.TEMPLATES["top"];
  });

  test("renders custom template", async function (assert) {
    await visit("/static/faq");
    assert.strictEqual(
      query("span.top-span").innerText,
      "TOP",
      "it inserted the template"
    );
  });
});
