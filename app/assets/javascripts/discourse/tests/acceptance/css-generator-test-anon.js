import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("CSS Generator | anon, login required", function (needs) {
  needs.site({ categories: null });
  needs.settings({ login_required: true });

  test("category CSS variables are not generated", async function (assert) {
    await visit("/");
    const cssTag = document.querySelector("style#category-color-css-generator");
    assert.notOk(exists(cssTag));
  });

  test("category badge CSS variables are not generated", async function (assert) {
    await visit("/");
    const cssTag = document.querySelector("style#category-badge-css-generator");
    assert.notOk(exists(cssTag));
  });
});
