import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import WorkflowSettings from "discourse/plugins/discourse-workflows/admin/components/workflows/settings";

const FIELD = "[data-identifier='workflow-timezone'][data-trigger]";

module(
  "Integration | Component | Workflows | WorkflowSettings",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
      this.saves = [];
      pretender.put(
        "/admin/plugins/discourse-workflows/workflows/1.json",
        (request) => {
          this.saves.push(decodeURIComponent(request.requestBody));
          return response({});
        }
      );
    });

    test("workflow settings: saves the time zone picked with the new select", async function (assert) {
      const workflow = { id: 1, timezone: "Europe/Paris" };

      await render(
        <template><WorkflowSettings @workflow={{workflow}} /></template>
      );

      assert.dSelect(FIELD).hasName("Paris, France");

      const select = dSelect(FIELD);
      await select.open();
      await select.search("lisbon");
      await select.select("Europe/Lisbon");

      assert.strictEqual(this.saves.length, 1);
      assert.true(
        this.saves[0].includes("workflow[timezone]=Europe/Lisbon"),
        "the picked zone is saved"
      );
    });
  }
);
