import { getOwner } from "@ember/owner";
import { click, find, render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import AiToolEditorForm from "discourse/plugins/discourse-ai/discourse/components/ai-tool-editor-form";

const ROWS = ".rag-uploader__uploads-list tr";

let model;

function renderForm() {
  const tools = { content: [model] };

  return render(
    <template>
      <AiToolEditorForm
        @editingModel={{model}}
        @model={{model}}
        @tools={{tools}}
      />
    </template>
  );
}

module("Integration | Component | AiToolEditorForm", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.ai_embeddings_enabled = true;
    sinon.stub(getOwner(this).lookup("service:router"), "replaceWith");

    model = {
      name: "Weather",
      tool_name: "weather",
      description: "Looks up the weather",
      summary: "Weather lookup",
      script: "function invoke(params) { return 1; }",
      rag_uploads: [
        { id: 1, original_filename: "first.txt" },
        { id: 2, original_filename: "second.md" },
      ],
      save: sinon.stub().resolves(),
    };
  });

  test("keeps the other uploads when one is removed", async function (assert) {
    await renderForm();

    await click(`${ROWS}:first-child .btn-flat`);
    await click(".ai-tool-editor__save");

    assert.deepEqual(
      model.save.firstCall.args[0].rag_uploads.map((upload) => upload.id),
      [2],
      "submits the remaining upload"
    );
  });

  test("submits each upload once after a new one finishes", async function (assert) {
    pretender.post(
      "/admin/plugins/discourse-ai/rag-document-fragments/files/upload.json",
      () => response({ upload: { id: 3, original_filename: "third.txt" } })
    );
    await renderForm();

    getOwner(this)
      .lookup("service:app-events")
      .trigger("upload-mixin:discourse-ai-rag-uploader:add-files", [
        createFile("third.txt", "text/plain"),
      ]);
    await waitUntil(
      () => find(`${ROWS}:nth-child(3)`) && !find(".rag-uploader .spinner")
    );
    await click(".ai-tool-editor__save");

    assert.deepEqual(
      model.save.firstCall.args[0].rag_uploads.map((upload) => upload.id),
      [1, 2, 3],
      "submits each upload once"
    );
  });
});
