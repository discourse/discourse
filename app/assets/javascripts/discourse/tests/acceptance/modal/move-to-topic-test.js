import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Modal - move-to-topic", function (needs) {
  needs.user({ admin: true });

  test("Transformer can modify merge/move options sent in request", async function (assert) {
    withPluginApi("1.24.0", (api) => {
      ["move-to-topic-merge-options", "move-to-topic-move-options"].forEach(
        (transformerName) => {
          api.registerValueTransformer(transformerName, (transformer) => {
            transformer.value.sillyVal = true;
            return transformer.value;
          });
        }
      );
    });

    await visit("/t/internationalization-localization/280");

    // Open admin menu, select a post, and open move to topic modal
    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click(".select-posts .select-post");
    await click(".selected-posts .move-to-topic");

    // Choose existing topic, and pick the first topic.
    await click("input#move-to-existing-topic");
    await fillIn("input#choose-topic-title", 1);
    await click(".choose-topic-list .existing-topic input");

    pretender.post("/t/280/move-posts", (request) => {
      assert.step("request");
      const data = parsePostData(request.requestBody);
      assert.strictEqual(data.sillyVal, "true");
      return response({ success: true });
    });

    // Submit!
    await click(".d-modal__footer .btn-primary");
    assert.verifySteps(["request"]);
  });
});
