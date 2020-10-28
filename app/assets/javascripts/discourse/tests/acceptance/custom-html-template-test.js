import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import Ember from "ember";

acceptance("CustomHTML template", function (needs) {
  needs.hooks.beforeEach(() => {
    Ember.TEMPLATES["top"] = Ember.HTMLBars.compile(
      `<span class='top-span'>TOP</span>`
    );
  });
  needs.hooks.afterEach(() => {
    delete Ember.TEMPLATES["top"];
  });

  test("renders custom template", async (assert) => {
    await visit("/static/faq");
    assert.equal(
      queryAll("span.top-span").text(),
      "TOP",
      "it inserted the template"
    );
  });
});
