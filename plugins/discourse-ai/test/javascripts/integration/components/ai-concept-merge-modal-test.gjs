import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AiConceptMergeModal from "discourse/plugins/discourse-ai/discourse/components/modal/ai-concept-merge-modal";

module("Integration | Component | AiConceptMergeModal", function (hooks) {
  setupRenderingTest(hooks);

  test("searches and selects a merge target concept beyond the initial list", async function (assert) {
    let mergePayload = null;
    const onMerged = sinon.spy();

    pretender.get("/admin/plugins/discourse-ai/ai-concepts.json", (request) => {
      if (request.queryParams.filter === "Zebra") {
        return response(200, {
          ai_concepts: [
            { id: 10, name: "Source Concept", status: "candidate" },
            { id: 300, name: "Zebra", status: "active" },
          ],
          meta: { has_more: false },
        });
      }

      return response(200, {
        ai_concepts: [{ id: 1, name: "Alpha", status: "active" }],
        meta: { has_more: true },
      });
    });

    pretender.post(
      "/admin/plugins/discourse-ai/ai-concepts/10/merge.json",
      (request) => {
        mergePayload = JSON.parse(request.requestBody);
        return response(200, {
          ai_concept: { id: 300, name: "Zebra", status: "active" },
        });
      }
    );

    const model = {
      concept: { id: 10, name: "Source Concept", status: "candidate" },
      onMerged,
    };

    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(AiConceptMergeModal, { model });
    await settled();

    const chooser = selectKit(".ai-concept-merge-modal__target-chooser");
    await chooser.expand();
    await chooser.fillInFilter("Zebra");

    assert.false(
      chooser.rowByValue(10).exists(),
      "excludes the source concept from merge target options"
    );

    await chooser.selectRowByValue(300);
    await click(".ai-concept-merge-modal__submit");

    assert.strictEqual(
      mergePayload.target_concept_id,
      300,
      "submits the searched target_concept_id"
    );
    assert.true(
      onMerged.calledOnceWithExactly({
        id: 300,
        name: "Zebra",
        status: "active",
      }),
      "invokes onMerged with the canonical concept"
    );
    assert
      .dom(".ai-concept-merge-modal")
      .doesNotExist("closes the modal after merging");
  });
});
