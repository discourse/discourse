import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import formKit from "discourse/tests/helpers/form-kit-helper";
import AiLlmQuotaModal from "discourse/plugins/discourse-ai/discourse/components/modal/ai-llm-quota-modal";

module("Integration | Component | AiLlmQuotaModal", function (hooks) {
  setupRenderingTest(hooks);

  test("with the new select controls, a quota is added for the picked group", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.owner.lookup("service:site").groups = [
      { id: 0, name: "everyone", automatic: true },
      { id: 10, name: "support", automatic: false },
      { id: 11, name: "sales", automatic: false },
    ];
    const model = {
      id: 5,
      llm: { llm_quotas: [{ group_id: 11 }] },
      addItemToCollection: sinon.spy(),
    };

    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(AiLlmQuotaModal, { model });
    await settled();

    const group = dSelect(".ai-llm-quota-modal .group-chooser");
    await group.open();
    assert.deepEqual(
      [...document.querySelectorAll("[role='option']")].map(
        (row) => row.dataset.value
      ),
      ["10"],
      "everyone and groups that have a quota are not offered"
    );
    await group.selectByName("support");
    await formKit().field("max_tokens").fillIn("100");
    await formKit().submit();

    assert.true(model.addItemToCollection.calledOnce);
    assert.strictEqual(model.addItemToCollection.lastCall.args[0].group_id, 10);
    assert.strictEqual(
      model.addItemToCollection.lastCall.args[0].group_name,
      "support"
    );
  });
});
