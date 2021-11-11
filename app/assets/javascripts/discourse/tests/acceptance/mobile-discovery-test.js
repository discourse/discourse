import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Topic Discovery - Mobile", function (needs) {
  needs.mobileView();
  test("Visit Discovery Pages", async function (assert) {
    await visit("/");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");

    await visit("/categories");
    assert.ok(exists(".category"), "has a list of categories");
  });
});
