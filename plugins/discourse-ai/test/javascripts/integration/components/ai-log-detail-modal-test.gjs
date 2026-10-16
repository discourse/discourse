import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiLogDetailModal from "discourse/plugins/discourse-ai/discourse/components/modal/ai-log-detail-modal";

module("Integration | Component | AiLogDetailModal", function (hooks) {
  setupRenderingTest(hooks);

  test("renders incomplete outcomes, raw stop reasons, and explicit zero reasoning tokens", async function (assert) {
    pretender.get("/admin/plugins/discourse-ai/ai-logs/1.json", () =>
      response({
        id: 1,
        outcome: "empty",
        response_status: 200,
        reasoning_tokens: 0,
        stop_reason: "length",
      })
    );
    const model = { logId: 1 };
    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(AiLogDetailModal, { model });
    await settled();
    assert
      .dom(".ai-log-detail-modal__metadata")
      .includesText(
        "Empty response (200)",
        "the server outcome is used in details"
      );
    assert
      .dom(".ai-log-detail-modal__metadata-reasoning dd")
      .hasText("0", "explicit zero reasoning usage is retained in details");
    assert
      .dom(".ai-log-detail-modal__metadata-stop-reason dd")
      .hasText("length", "the raw provider stop reason is shown");
  });

  test("omits absent provider metadata", async function (assert) {
    pretender.get("/admin/plugins/discourse-ai/ai-logs/1.json", () =>
      response({ id: 1, outcome: "successful", response_status: 200 })
    );
    const model = { logId: 1 };
    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(AiLogDetailModal, { model });
    await settled();
    assert
      .dom(".ai-log-detail-modal__metadata-reasoning")
      .doesNotExist("unknown reasoning usage is omitted");
    assert
      .dom(".ai-log-detail-modal__metadata-stop-reason")
      .doesNotExist("unknown stop reasons are omitted");
  });
});
