import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Topic - Anonymous", function () {
  test("Enter a Topic", async (assert) => {
    await visit("/t/internationalization-localization/280/1");
    assert.ok(exists("#topic"), "The topic was rendered");
    assert.ok(exists("#topic .cooked"), "The topic has cooked posts");
    assert.ok(
      find(".shared-draft-notice").length === 0,
      "no shared draft unless there's a dest category id"
    );
  });

  test("Enter without an id", async (assert) => {
    await visit("/t/internationalization-localization");
    assert.ok(exists("#topic"), "The topic was rendered");
  });

  test("Enter a 404 topic", async (assert) => {
    await visit("/t/not-found/404");
    assert.ok(!exists("#topic"), "The topic was not rendered");
    assert.ok(exists(".topic-error"), "An error message is displayed");
  });

  test("Enter without access", async (assert) => {
    await visit("/t/i-dont-have-access/403");
    assert.ok(!exists("#topic"), "The topic was not rendered");
    assert.ok(exists(".topic-error"), "An error message is displayed");
  });

  test("Enter with 500 errors", async (assert) => {
    await visit("/t/throws-error/500");
    assert.ok(!exists("#topic"), "The topic was not rendered");
    assert.ok(exists(".topic-error"), "An error message is displayed");
  });
});
