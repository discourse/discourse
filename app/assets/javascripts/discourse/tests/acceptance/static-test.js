import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Static", function () {
  test("Static Pages", async (assert) => {
    await visit("/faq");
    assert.ok($("body.static-faq").length, "has the body class");
    assert.ok(exists(".body-page"), "The content is present");

    await visit("/guidelines");
    assert.ok($("body.static-guidelines").length, "has the body class");
    assert.ok(exists(".body-page"), "The content is present");

    await visit("/tos");
    assert.ok($("body.static-tos").length, "has the body class");
    assert.ok(exists(".body-page"), "The content is present");

    await visit("/privacy");
    assert.ok($("body.static-privacy").length, "has the body class");
    assert.ok(exists(".body-page"), "The content is present");

    await visit("/login");
    assert.equal(
      currentPath(),
      "discovery.latest",
      "it redirects them to latest unless `login_required`"
    );
  });
});
