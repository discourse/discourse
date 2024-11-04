import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Topic Discovery - Mobile", function (needs) {
  needs.mobileView();
  test("Visit Discovery Pages", async function (assert) {
    await visit("/");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");

    assert
      .dom("a[data-user-card=codinghorror] img.avatar")
      .hasAttribute(
        "loading",
        "lazy",
        "it adds loading=`lazy` to topic list avatars"
      );

    await visit("/categories");
    assert.ok(exists(".category"), "has a list of categories");
  });
});
