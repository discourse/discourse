import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Topic - Anonymous", function () {
  test("Enter a Topic", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    assert.dom("#topic").exists("The topic was rendered");
    assert.dom("#topic .cooked").exists("The topic has cooked posts");
    assert
      .dom(".shared-draft-notice")
      .doesNotExist("no shared draft unless there's a dest category id");
  });

  test("Enter without an id", async function (assert) {
    await visit("/t/internationalization-localization");
    assert.dom("#topic").exists("The topic was rendered");
  });

  test("Enter a 404 topic", async function (assert) {
    await visit("/t/not-found/404");
    assert.dom("#topic").doesNotExist("The topic was not rendered");
    assert.dom(".topic-error").exists("An error message is displayed");
  });

  test("Enter without access", async function (assert) {
    await visit("/t/i-dont-have-access/403");
    assert.dom("#topic").doesNotExist("The topic was not rendered");
    assert.dom(".topic-error").exists("An error message is displayed");
  });

  test("Enter with 500 errors", async function (assert) {
    await visit("/t/throws-error/500");
    assert.dom("#topic").doesNotExist("The topic was not rendered");
    assert.dom(".topic-error").exists("An error message is displayed");
  });
});
