import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Create topic button click transformer", function (needs) {
  needs.user();

  test("a behavior transformer can take over the click", async function (assert) {
    withPluginApi((api) => {
      api.registerBehaviorTransformer(
        "create-topic-button-click",
        ({ context }) => {
          assert.step(`intercepted:${context.category?.slug}`);
        }
      );
    });

    await visit("/c/bug/1");
    await click("#create-topic");

    assert.verifySteps(["intercepted:bug"]);
    assert.dom("#reply-control.open").doesNotExist("the composer stays closed");
  });

  test("calling next keeps the default composer behaviour", async function (assert) {
    withPluginApi((api) => {
      api.registerBehaviorTransformer(
        "create-topic-button-click",
        ({ next }) => {
          assert.step("passed through");
          next();
        }
      );
    });

    await visit("/c/bug/1");
    await click("#create-topic");

    assert.verifySteps(["passed through"]);
    assert.dom("#reply-control.open").exists("the composer opens");
  });
});
