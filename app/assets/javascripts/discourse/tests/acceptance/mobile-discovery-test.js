import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Topic Discovery - Mobile", function (needs) {
  needs.mobileView();
  test("Visit Discovery Pages", async function (assert) {
    await visit("/");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");

    assert.strictEqual(
      query("a[data-user-card=codinghorror] img.avatar").getAttribute(
        "loading"
      ),
      "lazy",
      "it adds loading=`lazy` to topic list avatars"
    );

    await visit("/categories");
    assert.ok(exists(".category"), "has a list of categories");
  });
});
