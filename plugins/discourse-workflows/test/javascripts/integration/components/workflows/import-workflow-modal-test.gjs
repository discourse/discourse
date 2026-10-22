import {
  click,
  fillIn,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ImportWorkflowModal from "discourse/plugins/discourse-workflows/admin/components/workflows/import-workflow-modal";

const WORKFLOW_JSON = JSON.stringify({
  name: "Imported workflow",
  nodes: [
    {
      id: "n1",
      type: "trigger:manual",
      typeVersion: 1,
      name: "Manual trigger",
    },
  ],
  connections: {},
});

function attachFile(input, name, text) {
  const file = new File([text], name, { type: "application/json" });
  Object.defineProperty(input, "files", {
    value: [file],
    configurable: true,
  });
  return triggerEvent(input, "change");
}

module(
  "Integration | Component | discourse-workflows | ImportWorkflowModal",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.imported = null;
      this.closed = false;
      this.model = {
        onImport: (workflow) => {
          this.imported = workflow;
        },
      };
      this.closeModal = () => {
        this.closed = true;
      };

      // DModal renders into the modal service's container, which only exists
      // when the full app is booted; provide one for the component test
      this.modalContainer = document.createElement("div");
      document.body.append(this.modalContainer);
      this.owner
        .lookup("service:modal")
        .setContainerElement(this.modalContainer);

      // the availability check consults the node type registry, which is
      // loaded over ajax; every node type is trivially available here
      const nodeTypes = this.owner.lookup("service:workflows-node-types");
      nodeTypes.nodeTypes = [{ identifier: "trigger:manual" }];
      nodeTypes.findNodeType = () => ({ available: true });
    });

    hooks.afterEach(function () {
      this.modalContainer.remove();
    });

    test("picking a .json file populates the textarea and shows the file name", async function (assert) {
      await render(
        <template>
          <ImportWorkflowModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );

      // the modal teleports outside the test fixture, so assertions must
      // search from the document rather than the default fixture root
      assert
        .dom(".import-workflow-modal__select-file-btn", document)
        .exists("the select file button renders");

      const input = document.querySelector(
        ".import-workflow-modal input[type='file']"
      );
      await attachFile(input, "imported-workflow.json", WORKFLOW_JSON);
      await settled();

      assert
        .dom(".import-workflow-modal__json", document)
        .hasValue(WORKFLOW_JSON, "the file contents fill the textarea");
      assert
        .dom(".import-workflow-modal__file-name", document)
        .hasText(
          "Selected file: imported-workflow.json",
          "the picked file name is displayed"
        );
    });

    test("manually editing the textarea clears the file name hint", async function (assert) {
      await render(
        <template>
          <ImportWorkflowModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );

      const input = document.querySelector(
        ".import-workflow-modal input[type='file']"
      );
      await attachFile(input, "imported-workflow.json", WORKFLOW_JSON);
      await settled();
      assert.dom(".import-workflow-modal__file-name", document).exists();

      await fillIn(
        this.modalContainer.querySelector(".import-workflow-modal__json"),
        `{"name": "Edited"}`
      );

      assert
        .dom(".import-workflow-modal__file-name", document)
        .doesNotExist("stale file name hint is removed on manual edit");
    });

    test("importing after picking a file submits the parsed workflow", async function (assert) {
      await render(
        <template>
          <ImportWorkflowModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );

      assert
        .dom(".import-workflow-modal__actions .btn-primary", document)
        .isDisabled("import starts disabled with an empty textarea");

      const input = document.querySelector(
        ".import-workflow-modal input[type='file']"
      );
      await attachFile(input, "imported-workflow.json", WORKFLOW_JSON);
      await settled();

      assert
        .dom(".import-workflow-modal__actions .btn-primary", document)
        .isNotDisabled("picking a file enables the import button");

      await click(
        this.modalContainer.querySelector(
          ".import-workflow-modal__actions .btn-primary"
        )
      );

      assert.notStrictEqual(
        this.imported,
        null,
        "onImport received the parsed workflow"
      );
      assert.strictEqual(this.imported.name, "Imported workflow");
      assert.true(this.closed, "the modal closes after a successful import");
    });

    test("a typed name allows importing a nameless graph", async function (assert) {
      await render(
        <template>
          <ImportWorkflowModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );

      const graph = JSON.parse(WORKFLOW_JSON);
      delete graph.name;
      await fillIn(
        this.modalContainer.querySelector(".import-workflow-modal__json"),
        JSON.stringify(graph)
      );
      await fillIn(
        this.modalContainer.querySelector("#import-workflow-name"),
        "  Named in the modal  "
      );
      await click(
        this.modalContainer.querySelector(
          ".import-workflow-modal__actions .btn-primary"
        )
      );

      assert.strictEqual(this.imported?.name, "Named in the modal");
      assert.true(this.closed);
    });

    test("an invalid timezone prevents creation before retrying with a valid timezone", async function (assert) {
      await render(
        <template>
          <ImportWorkflowModal
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );

      const graph = {
        ...JSON.parse(WORKFLOW_JSON),
        settings: { timezone: "UTC+2" },
      };
      const textarea = this.modalContainer.querySelector(
        ".import-workflow-modal__json"
      );
      const button = this.modalContainer.querySelector(
        ".import-workflow-modal__actions .btn-primary"
      );
      await fillIn(textarea, JSON.stringify(graph));
      await click(button);

      assert.strictEqual(this.imported, null, "creation was not requested");
      assert.false(this.closed);
      assert.dom(".import-workflow-modal__errors", document).exists();

      graph.settings.timezone = "Europe/Paris";
      await fillIn(textarea, JSON.stringify(graph));
      await click(button);

      assert.strictEqual(this.imported?.settings.timezone, "Europe/Paris");
      assert.true(this.closed);
    });
  }
);
