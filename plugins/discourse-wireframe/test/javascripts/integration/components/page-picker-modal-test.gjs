import { hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PagePickerModal from "discourse/plugins/discourse-wireframe/discourse/components/editor/simulation/page-picker-modal";

module(
  "Integration | discourse-wireframe | Component | page picker modal",
  function (hooks) {
    setupRenderingTest(hooks);

    test("picking a page navigates bound to and previewing the chosen theme", async function (assert) {
      // The modal renders into the modal service's container, which no app
      // outlet provides in a rendering test.
      this.owner
        .lookup("service:modal")
        .setContainerElement(document.querySelector("#ember-testing"));
      const assign = sinon.stub(PagePickerModal.prototype, "_assign");
      const theme = { id: 42, name: "Acme" };
      const closeModal = () => {};

      await render(
        <template>
          <PagePickerModal
            @model={{hash theme=theme}}
            @closeModal={{closeModal}}
          />
        </template>
      );
      await click(".wireframe-page-list li:first-child button");

      assert.deepEqual(
        assign.firstCall?.args,
        ["/custom?wf_theme=42&preview_theme_id=42"],
        "the homepage entry targets /custom with both theme params"
      );
    });
  }
);
