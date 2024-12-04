import {
  click,
  currentURL,
  fillIn,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const openModal = async (assert) => {
  await visit("/t/internationalization-localization/280");
  await click(".topic-admin-menu-trigger");
  assert.dom(".topic-admin-menu-content").exists();

  await click(".topic-admin-menu-content .topic-admin-multi-select button");
  await click(".select-posts .select-post");
  await click(".selected-posts .move-to-topic");
};

acceptance("Modal - move-to-topic", function (needs) {
  needs.user({ admin: true });

  let lastPayload = null;
  needs.pretender((server, helper) => {
    server.put("/u/eviltrout.json", (request) => {
      lastPayload = request.requestBody;

      return helper.response({
        success: true,
        user: { user_option: {} },
      });
    });
  });

  test("Transformer can modify merge and move options", async function (assert) {
    ["move-to-topic-merge-options", "move-to-topic-move-options"].forEach(
      (transformerName) => {
        api.registerValueTransformer(transformerName, (transformer) => {
          transformer.value.sillyVal = true;
          return transformer.value;
        });
      }
    );

    await openModal(assert);

    // MARK NOW YOU NEED TO FILL IN THE MODAL, AND ASSERT THAT WE DID SEND THE VALUE TO THE SERVER

    assert.dom(".d-header").exists();
  });
});
