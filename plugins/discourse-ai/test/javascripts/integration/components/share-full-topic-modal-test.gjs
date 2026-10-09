import { click, find, render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import ShareFullTopicModal from "discourse/plugins/discourse-ai/discourse/components/modal/share-full-topic-modal";

module(
  "Integration | Component | Modal | ShareFullTopicModal",
  function (hooks) {
    setupRenderingTest(hooks);

    test("cancel retains the conversation key and confirmation deletes it once", async function (assert) {
      let deletes = 0;
      pretender.delete(
        "/discourse-ai/ai-bot/shared-ai-conversations/shared.json",
        () => {
          deletes++;
          return response({});
        }
      );
      await render(<template><ModalContainer /><DialogHolder /></template>);
      this.owner.lookup("service:modal").show(ShareFullTopicModal, {
        model: { share_key: "shared", topic_id: 42, context: [] },
      });
      await settled();

      assert
        .dom(".ai-share-full-topic-modal .btn-danger")
        .exists("delete is red");
      await click(".ai-share-full-topic-modal .btn-danger");
      assert
        .dom("#dialog-title")
        .hasText(
          i18n("discourse_ai.ai_artifact.confirm_revoke_conversation_title")
        );
      assert
        .dom(".dialog-body")
        .hasText(
          i18n("discourse_ai.ai_artifact.confirm_revoke_conversation_message")
        );
      assert
        .dom(".dialog-footer .btn-danger")
        .hasText(i18n("discourse_ai.ai_artifact.revoke_conversation"));
      assert
        .dom(".ai-share-full-topic-modal .confirm")
        .isDisabled("sharing blocked during confirmation");
      assert.strictEqual(deletes, 0, "opening confirmation does not delete");
      await click(".dialog-footer .btn-default");
      assert.strictEqual(deletes, 0, "cancel does not delete");
      assert
        .dom(".ai-share-full-topic-modal .btn-danger")
        .exists("cancel retains the key");
      await click(".ai-share-full-topic-modal .btn-danger");
      await click(".dialog-footer .btn-danger");
      assert.strictEqual(deletes, 1, "confirmation deletes once");
      assert
        .dom(".ai-share-full-topic-modal .btn-danger")
        .doesNotExist("deleted key is cleared");
    });
    test("pending deletion cannot overlap with share or a second deletion", async function (assert) {
      let respond;
      let deletes = 0;
      let shares = 0;
      pretender.delete(
        "/discourse-ai/ai-bot/shared-ai-conversations/shared.json",
        () => {
          deletes++;
          return new Promise((resolve) => {
            respond = resolve;
          });
        }
      );
      pretender.post("/discourse-ai/ai-bot/shared-ai-conversations", () => {
        shares++;
        return response({ share_key: "new" });
      });
      await render(<template><ModalContainer /><DialogHolder /></template>);
      this.owner.lookup("service:modal").show(ShareFullTopicModal, {
        model: { share_key: "shared", topic_id: 42, context: [] },
      });
      await settled();
      await click(".ai-share-full-topic-modal .btn-danger");
      find(".dialog-footer .btn-danger").click();
      await waitUntil(() => deletes === 1);
      assert
        .dom(".ai-share-full-topic-modal .confirm")
        .isDisabled("share is disabled");
      assert
        .dom(".ai-share-full-topic-modal .btn-danger")
        .isDisabled("delete is disabled");
      find(".ai-share-full-topic-modal .confirm").click();
      find(".ai-share-full-topic-modal .btn-danger").click();
      assert.strictEqual(shares, 0, "no concurrent sharing");
      assert.strictEqual(deletes, 1, "no duplicate deletion");
      respond(response({}));
      await settled();
    });
  }
);
