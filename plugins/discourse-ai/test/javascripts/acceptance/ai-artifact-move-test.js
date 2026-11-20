import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("AI artifact | moving posts", function (needs) {
  needs.user({ admin: true });
  needs.settings({
    discourse_ai_enabled: true,
    ai_artifact_security: "strict",
  });

  test("warns before revoking public access and allows the move to be cancelled", async function (assert) {
    pretender.post("/discourse-ai/ai-bot/artifacts/move-warning.json", () => {
      assert.step("preview");
      return response({ count: 1 });
    });
    pretender.post("/t/280/move-posts", () => {
      assert.step("move");
      return response({ success: true });
    });

    await visit("/t/internationalization-localization/280");
    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click(".select-posts .select-post");
    await click(".selected-posts .move-to-topic");
    await click("input#move-to-existing-topic");
    await fillIn("input#choose-topic-title", "1");
    await click(".choose-topic-list .existing-topic input");
    await click(".d-modal__footer .btn-primary");

    assert
      .dom(".dialog-body")
      .includesText("Existing public artifact links will no longer work");
    assert.verifySteps(["preview"], "no move occurs before confirmation");
    await click(".dialog-overlay");
    assert
      .dom(".choose-topic-modal")
      .exists("cancelling keeps the move dialog open");

    await click(".d-modal__footer .btn-primary");
    await click(".dialog-footer .btn-danger");
    assert.verifySteps(["preview", "move"]);
  });

  test("keeps the move dialog open after a preview error and allows a retry without a warning", async function (assert) {
    let previewFails = true;
    pretender.post("/discourse-ai/ai-bot/artifacts/move-warning.json", () => {
      assert.step("preview");
      if (previewFails) {
        return response(500, { errors: ["Could not check artifact access"] });
      }
      return response({ count: 0 });
    });
    pretender.post("/t/280/move-posts", () => {
      assert.step("move");
      return response({ success: true });
    });

    await visit("/t/internationalization-localization/280");
    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click(".select-posts .select-post");
    await click(".selected-posts .move-to-topic");
    await click("input#move-to-existing-topic");
    await fillIn("input#choose-topic-title", "1");
    await click(".choose-topic-list .existing-topic input");
    await click(".d-modal__footer .btn-primary");

    assert.dom("#modal-alert").includesText("Could not check artifact access");
    assert.dom(".choose-topic-modal").exists();
    assert.verifySteps(["preview"], "a preview error does not move posts");

    previewFails = false;
    await click(".d-modal__footer .btn-primary");
    assert.dom(".dialog-body").doesNotExist();
    assert.verifySteps(["preview", "move"]);
  });
});
