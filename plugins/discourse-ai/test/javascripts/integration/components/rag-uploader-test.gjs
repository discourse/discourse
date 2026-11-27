import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import {
  click,
  find,
  render,
  rerender,
  settled,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import RagUploader from "discourse/plugins/discourse-ai/discourse/components/rag-uploader";

const ROWS = ".rag-uploader__uploads-list tr";
const first = { id: 1, original_filename: "first.txt" };
const second = { id: 2, original_filename: "second.md" };

module("Integration | Component | RagUploader", function (hooks) {
  setupRenderingTest(hooks);

  test("accepts images when @allowImages is set", async function (assert) {
    await render(<template><RagUploader @allowImages={{true}} /></template>);

    assert
      .dom(".hidden-upload-field")
      .hasAttribute("accept", ".txt,.md,.png,.jpg,.jpeg");
  });

  test("lists the uploads of @target", async function (assert) {
    const target = tracked({ rag_uploads: [first] });
    let removed;
    const onRemove = (upload) => (removed = upload);

    await render(
      <template>
        <RagUploader @onRemove={{onRemove}} @target={{target.value}} />
      </template>
    );
    assert.dom(ROWS).exists({ count: 1 }, "renders the initial uploads");

    target.value = { rag_uploads: [first, second] };
    await rerender();
    assert.dom(ROWS).exists({ count: 2 }, "renders added uploads");

    await click(`${ROWS}:first-child .btn-flat`);
    assert.strictEqual(removed, first, "reports the removed upload");
  });

  test("keeps the rows when the uploads are replaced with copies", async function (assert) {
    const target = tracked({ rag_uploads: [first] });

    await render(<template><RagUploader @target={{target.value}} /></template>);
    const row = find(ROWS);

    target.value = { rag_uploads: [{ ...first }] };
    await rerender();
    assert.strictEqual(find(ROWS), row);
  });

  test("fetches indexing statuses once per set of uploads", async function (assert) {
    const requests = [];
    pretender.get(
      "/admin/plugins/discourse-ai/rag-document-fragments/files/status.json",
      (request) => {
        requests.push(request.queryParams);
        return response({ 1: { total: 2, indexed: 2, left: 0 } });
      }
    );
    const target = tracked({ id: 7, rag_uploads: [first] });

    await render(
      <template>
        <RagUploader @target={{target.value}} @targetName="AiAgent" />
      </template>
    );
    assert.deepEqual(requests, [{ target_type: "AiAgent", target_id: "7" }]);
    assert.dom(".rag-uploader .indexed").exists("renders the fetched status");

    target.value = { ...target.value, name: "renamed" };
    await settled();
    assert.strictEqual(
      requests.length,
      1,
      "does not refetch for other changes"
    );

    target.value = { ...target.value, rag_uploads: [first, second] };
    await settled();
    assert.strictEqual(requests.length, 2, "refetches for new uploads");
  });

  test("hands over a finished upload when another one is cancelled", async function (assert) {
    pretender.post(
      "/admin/plugins/discourse-ai/rag-document-fragments/files/upload.json",
      async (request) => {
        if (request.requestBody.get("file").name === "slow.txt") {
          await new Promise(() => {});
        }
        return response({ upload: { id: 3, original_filename: "fast.txt" } });
      }
    );
    const target = tracked({ rag_uploads: [first] });
    const updateUploads = (uploads) =>
      (target.value = { rag_uploads: uploads });

    await render(
      <template>
        <RagUploader
          @target={{target.value}}
          @updateUploads={{updateUploads}}
        />
      </template>
    );
    getOwner(this)
      .lookup("service:app-events")
      .trigger("upload-mixin:discourse-ai-rag-uploader:add-files", [
        createFile("fast.txt", "text/plain"),
        createFile("slow.txt", "text/plain"),
      ]);
    await waitUntil(() => target.value.rag_uploads.length === 2);

    assert
      .dom(`${ROWS}:has(.spinner)`)
      .hasText(/slow\.txt/, "names the file being uploaded");

    await click(`${ROWS}:has(.spinner) .btn-flat`);
    assert.deepEqual(
      target.value.rag_uploads.map((upload) => upload.id),
      [1, 3],
      "keeps the finished upload"
    );
  });
});
