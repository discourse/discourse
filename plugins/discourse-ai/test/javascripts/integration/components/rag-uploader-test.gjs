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
import {
  createFile,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import RagUploader from "discourse/plugins/discourse-ai/discourse/components/rag-uploader";

const STATUS_PATH =
  "/admin/plugins/discourse-ai/rag-document-fragments/files/status.json";
const UPLOAD_PATH =
  "/admin/plugins/discourse-ai/rag-document-fragments/files/upload.json";
const ADD_FILES = "upload-mixin:discourse-ai-rag-uploader:add-files";
const ROWS = ".rag-uploader__uploads-list tr";

const first = { id: 1, original_filename: "first.txt" };
const second = { id: 2, original_filename: "second.md" };

module("Integration | Component | RagUploader", function (hooks) {
  setupRenderingTest(hooks);

  let statusRequests;

  hooks.beforeEach(function () {
    statusRequests = [];
    pretender.get(STATUS_PATH, (request) => {
      statusRequests.push(request.queryParams);
      return response({ 1: { total: 2, indexed: 2, left: 0 } });
    });
  });

  test("accepts images only when @allowImages is set", async function (assert) {
    const allowImages = tracked(false);
    const target = { rag_uploads: [] };

    await render(
      <template>
        <RagUploader @allowImages={{allowImages.value}} @target={{target}} />
      </template>
    );

    assert
      .dom(".hidden-upload-field")
      .hasAttribute("accept", ".txt,.md,.pdf", "accepts documents");

    allowImages.value = true;
    await rerender();

    assert
      .dom(".hidden-upload-field")
      .hasAttribute("accept", ".txt,.md,.png,.jpg,.jpeg", "accepts images");
  });

  test("lists the uploads of @target as it changes", async function (assert) {
    const target = tracked({ id: 7, rag_uploads: [first] });
    const removed = [];
    const onRemove = (upload) => {
      removed.push(upload);
      target.value = {
        ...target.value,
        rag_uploads: target.value.rag_uploads.filter((u) => u !== upload),
      };
    };

    await render(
      <template>
        <RagUploader
          @onRemove={{onRemove}}
          @target={{target.value}}
          @targetName="AiAgent"
        />
      </template>
    );

    assert
      .dom(".rag-uploader__uploads-list tr")
      .exists({ count: 1 }, "renders the initial uploads");

    target.value = { id: 7, rag_uploads: [first, second] };
    await rerender();

    assert
      .dom(".rag-uploader__uploads-list tr")
      .exists({ count: 2 }, "renders uploads added to the target");

    await click(".rag-uploader__uploads-list tr:first-child .btn-flat");

    assert.deepEqual(removed, [first], "reports the removed upload");
    assert
      .dom(".rag-uploader__uploads-list tr")
      .hasText(/second\.md/, "renders the uploads left on the target");
    assert.dom(".rag-uploader__uploads-list tr").exists({ count: 1 });
  });

  test("fetches indexing statuses once per set of uploads", async function (assert) {
    const target = tracked({ id: 7, rag_uploads: [first] });

    await render(
      <template>
        <RagUploader @target={{target.value}} @targetName="AiAgent" />
      </template>
    );

    assert.deepEqual(
      statusRequests,
      [{ target_type: "AiAgent", target_id: "7" }],
      "fetches the statuses of the target"
    );
    assert.dom(".rag-uploader .indexed").exists("renders the fetched status");

    target.value = { ...target.value, name: "renamed" };
    await settled();

    assert.strictEqual(
      statusRequests.length,
      1,
      "does not refetch when the uploads stay the same"
    );

    target.value = { ...target.value, rag_uploads: [first, second] };
    await settled();

    assert.strictEqual(statusRequests.length, 2, "refetches for new uploads");
  });

  test("hands finished uploads to @updateUploads", async function (assert) {
    pretender.post(UPLOAD_PATH, () =>
      response({ upload: { id: 3, original_filename: "third.txt" } })
    );

    const target = tracked({ rag_uploads: [first] });
    let updated;
    const updateUploads = (uploads) => {
      updated = uploads;
      target.value = { rag_uploads: uploads.slice() };
    };

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
      .trigger(ADD_FILES, [createFile("third.txt", "text/plain")]);
    await waitUntil(() => updated);
    await settled();

    assert.deepEqual(
      updated.map((upload) => upload.id),
      [1, 3],
      "passes the target's uploads plus the new one"
    );
    assert
      .dom(".rag-uploader__uploads-list tr")
      .exists({ count: 2 }, "renders each upload once");
  });

  test("hands over a finished upload when another one is cancelled", async function (assert) {
    let release;
    const held = new Promise((resolve) => (release = resolve));
    pretender.post(UPLOAD_PATH, async (request) => {
      if (request.requestBody.get("file").name === "slow.txt") {
        await held;
      }
      return response({ upload: { id: 3, original_filename: "fast.txt" } });
    });

    const target = tracked({ rag_uploads: [first] });
    const updateUploads = (uploads) => {
      target.value = { rag_uploads: uploads.slice() };
    };

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
      .trigger(ADD_FILES, [
        createFile("fast.txt", "text/plain"),
        createFile("slow.txt", "text/plain"),
      ]);

    try {
      await waitUntil(() => target.value.rag_uploads.length === 2);

      assert
        .dom(".rag-uploader__upload-status:has(.spinner)")
        .exists({ count: 1 }, "keeps uploading the slow file");
      assert
        .dom(`${ROWS}:has(.spinner)`)
        .hasText(/slow\.txt/, "names the file being uploaded");

      await click(`${ROWS}:has(.spinner) .btn-flat`);
    } finally {
      release();
    }

    assert.deepEqual(
      target.value.rag_uploads.map((upload) => upload.id),
      [1, 3],
      "keeps the finished upload on the target"
    );
    assert.dom(ROWS).exists({ count: 2 }, "renders the finished uploads");
  });

  test("keeps uploading when @target is replaced", async function (assert) {
    let release;
    const held = new Promise((resolve) => (release = resolve));
    pretender.post(UPLOAD_PATH, async () => {
      await held;
      return response({ upload: { id: 3, original_filename: "third.txt" } });
    });

    const target = tracked({ id: 7, rag_uploads: [] });

    await render(
      <template>
        <RagUploader @target={{target.value}} @targetName="AiAgent" />
      </template>
    );

    getOwner(this)
      .lookup("service:app-events")
      .trigger(ADD_FILES, [createFile("third.txt", "text/plain")]);

    try {
      await waitUntil(() => document.querySelector(".rag-uploader .spinner"));

      target.value = { ...target.value, name: "renamed" };
      await rerender();

      assert
        .dom(".rag-uploader .spinner")
        .exists("keeps uploading when the target is replaced");
    } finally {
      release();
    }
  });

  test("keeps tracking indexing when the uploads are replaced with copies", async function (assert) {
    const target = tracked({ id: 7, rag_uploads: [{ ...first }] });

    await render(
      <template>
        <RagUploader @target={{target.value}} @targetName="AiAgent" />
      </template>
    );

    const row = find(ROWS);

    target.value = { ...target.value, rag_uploads: [{ ...first }] };
    await rerender();

    assert.strictEqual(find(ROWS), row, "keeps the row");

    await publishToMessageBus("/discourse-ai/rag/1", {
      total: 2,
      indexed: 1,
      left: 1,
    });

    assert
      .dom(`${ROWS} .indexing`)
      .includesText("50%", "renders indexing updates");
  });
});
