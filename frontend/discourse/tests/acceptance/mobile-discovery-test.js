import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Topic Discovery - Mobile", function (needs) {
  needs.mobileView();
  test("Visit Discovery Pages", async function (assert) {
    await visit("/");
    assert.dom(".topic-list").exists("the list of topics is rendered");
    assert.dom(".topic-list .topic-list-item").exists("has topics");

    await visit("/categories");
    assert.dom(".category").exists("has a list of categories");
  });
});
