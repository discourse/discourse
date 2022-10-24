import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import Ember from "ember";

acceptance("CustomHTML template", function (needs) {
  needs.hooks.beforeEach(() => {
    Ember.TEMPLATES["top"] = hbs`<span class='top-span'>TOP</span>`;
  });

  needs.hooks.afterEach(() => {
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
