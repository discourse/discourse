import { getOwner } from "@ember/owner";
import { click, render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import AiToolEditorForm from "discourse/plugins/discourse-ai/discourse/components/ai-tool-editor-form";

const STATUS_PATH =
  "/admin/plugins/discourse-ai/rag-document-fragments/files/status.json";
const UPLOAD_PATH =
  "/admin/plugins/discourse-ai/rag-document-fragments/files/upload.json";
const ADD_FILES = "upload-mixin:discourse-ai-rag-uploader:add-files";
const ROWS = ".rag-uploader__uploads-list tr";

module("Integration | Component | AiToolEditorForm", function (hooks) {
  setupRenderingTest(hooks);

  let model;
  let saved;

  hooks.beforeEach(function () {
    this.siteSettings.ai_embeddings_enabled = true;
    sinon.stub(getOwner(this).lookup("service:router"), "replaceWith");
    pretender.get(STATUS_PATH, () => response({}));

    saved = null;
    model = {
      id: 5,
      name: "Weather",
      tool_name: "weather",
      description: "Looks up the weather",
      summary: "Weather lookup",
      script: "function invoke(params) { return 1; }",
      parameters: [],
      rag_uploads: [
        { id: 1, original_filename: "first.txt" },
        { id: 2, original_filename: "second.md" },
      ],
      save: (data) => {
        saved = data;
        return Promise.resolve();
      },
    };
  });

  test("keeps the other uploads when one is removed", async function (assert) {
    const tools = { content: [model] };
    const llms = [];

    await render(
      <template>
        <AiToolEditorForm
          @editingModel={{model}}
          @llms={{llms}}
          @model={{model}}
          @tools={{tools}}
        />
      </template>
    );

    assert.dom(ROWS).exists({ count: 2 }, "renders the tool's uploads");

    await click(`${ROWS}:first-child .rag-uploader__remove-file .btn-flat`);

    assert.dom(ROWS).exists({ count: 1 }, "removes the upload from the list");
    assert.dom(ROWS).hasText(/second\.md/, "keeps the other upload");

    await click(".ai-tool-editor__save");

    assert.deepEqual(
      saved.rag_uploads.map((upload) => upload.id),
      [2],
      "submits the remaining upload"
    );
  });

  test("lists each upload once after a new one finishes", async function (assert) {
    pretender.post(UPLOAD_PATH, () =>
      response({ upload: { id: 3, original_filename: "third.txt" } })
    );
    const tools = { content: [model] };
    const llms = [];

    await render(
      <template>
        <AiToolEditorForm
          @editingModel={{model}}
          @llms={{llms}}
          @model={{model}}
          @tools={{tools}}
        />
      </template>
    );

    getOwner(this)
      .lookup("service:app-events")
      .trigger(ADD_FILES, [createFile("third.txt", "text/plain")]);
    await waitUntil(
      () =>
        !document.querySelector(".rag-uploader .spinner") &&
        document
          .querySelector(ROWS)
          ?.parentElement.textContent.includes("third.txt")
    );

    assert.dom(ROWS).exists({ count: 3 }, "renders each upload once");

    await click(".ai-tool-editor__save");

    assert.deepEqual(
      saved.rag_uploads.map((upload) => upload.id),
      [1, 2, 3],
      "submits each upload once"
    );
  });
});
