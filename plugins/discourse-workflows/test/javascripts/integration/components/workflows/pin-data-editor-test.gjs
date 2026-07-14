import { click, render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import PinDataEditor from "discourse/plugins/discourse-workflows/admin/components/workflows/context/pin-data-editor";
import WorkflowEditorSession from "discourse/plugins/discourse-workflows/admin/lib/workflows/editor-session";

async function setBuffer(element, value) {
  const editorContent = element.querySelector(
    ".workflows-context-panel__editor .cm-content"
  );
  if (!editorContent) {
    throw new Error("CodeMirror content not found");
  }
  const view = editorContent.cmTile?.root?.view;
  if (!view) {
    throw new Error("CodeMirror view not found");
  }
  view.dispatch({
    changes: { from: 0, to: view.state.doc.length, insert: value },
  });
  await settled();
}

module(
  "Integration | Component | Workflows | Context | PinDataEditor",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.session = new WorkflowEditorSession({ workflowId: 7, pinData: {} });
    });

    hooks.afterEach(function () {
      this.owner.lookup("service:workflows-node-types").clear();
    });

    test("renders the empty-state CTA when there are no items", async function (assert) {
      await render(
        <template>
          <PinDataEditor
            @nodeName="n1"
            @initialItems={{undefined}}
            @canEdit={{true}}
            @session={{this.session}}
          />
        </template>
      );

      assert.dom(".workflows-context-panel__empty-state").exists();
      assert
        .dom(".workflows-context-panel__empty-state-btn")
        .hasText(/Add sample data/);
    });

    test("clicking Add sample data enters edit mode with the empty seed", async function (assert) {
      await render(
        <template>
          <PinDataEditor
            @nodeName="n1"
            @initialItems={{undefined}}
            @canEdit={{true}}
            @session={{this.session}}
          />
        </template>
      );

      await click(".workflows-context-panel__empty-state-btn");
      await waitFor(".cm-editor");

      const text = this.element
        .querySelector(".cm-content")
        ?.textContent.replace(/\s+/g, "");
      assert.strictEqual(
        text,
        "[{}]",
        `expected seed to be the unwrapped '[{}]', got ${text}`
      );
    });

    test("disables Save when JSON is invalid", async function (assert) {
      await render(
        <template>
          <PinDataEditor
            @nodeName="n1"
            @initialItems={{undefined}}
            @canEdit={{true}}
            @session={{this.session}}
          />
        </template>
      );

      await click(".workflows-context-panel__empty-state-btn");
      await waitFor(".cm-editor");

      await setBuffer(this.element, "{ not json");
      await waitFor(".workflows-context-panel__editor-error");

      assert
        .dom(".workflows-context-panel__editor-save")
        .hasAttribute("disabled");
      assert
        .dom(".workflows-context-panel__editor-error")
        .containsText("Invalid JSON");
    });

    test("disables Save when shape is invalid", async function (assert) {
      await render(
        <template>
          <PinDataEditor
            @nodeName="n1"
            @initialItems={{undefined}}
            @canEdit={{true}}
            @session={{this.session}}
          />
        </template>
      );

      await click(".workflows-context-panel__empty-state-btn");
      await waitFor(".cm-editor");

      await setBuffer(this.element, '"not an array"');
      await waitFor(".workflows-context-panel__editor-error");

      assert
        .dom(".workflows-context-panel__editor-save")
        .hasAttribute("disabled");
      assert
        .dom(".workflows-context-panel__editor-error")
        .containsText("Pinned data must be an array of items");
    });

    test("Save calls pinNodeData and exits edit mode", async function (assert) {
      let requestBody = null;
      pretender.put(
        "/admin/plugins/discourse-workflows/workflows/7/pin-data.json",
        (request) => {
          requestBody = JSON.parse(request.requestBody);
          return response(200, {});
        }
      );

      await render(
        <template>
          <PinDataEditor
            @nodeName="n1"
            @initialItems={{undefined}}
            @canEdit={{true}}
            @session={{this.session}}
          />
        </template>
      );

      await click(".workflows-context-panel__empty-state-btn");
      await waitFor(".cm-editor");

      // Unwrapped form — the editor wraps it as `{json: ...}` on save.
      await setBuffer(this.element, '[{"id": 42}]');
      await waitFor(".workflows-context-panel__editor-save:not([disabled])");

      await click(".workflows-context-panel__editor-save");

      assert.deepEqual(
        requestBody,
        { node_name: "n1", items: [{ json: { id: 42 } }] },
        "PUT payload wraps the unwrapped buffer back into storage shape"
      );

      assert.deepEqual(
        this.session.pinData,
        { n1: [{ json: { id: 42 } }] },
        "session pinData is updated optimistically with wrapped items"
      );

      assert
        .dom(".workflows-context-panel__editor-toolbar")
        .doesNotExist("Save/Cancel toolbar hides after a successful save");
    });

    test("Save also accepts the wrapped {json: ...} storage form", async function (assert) {
      let requestBody = null;
      pretender.put(
        "/admin/plugins/discourse-workflows/workflows/7/pin-data.json",
        (request) => {
          requestBody = JSON.parse(request.requestBody);
          return response(200, {});
        }
      );

      await render(
        <template>
          <PinDataEditor
            @nodeName="n1"
            @initialItems={{undefined}}
            @canEdit={{true}}
            @session={{this.session}}
          />
        </template>
      );

      await click(".workflows-context-panel__empty-state-btn");
      await waitFor(".cm-editor");

      await setBuffer(this.element, '[{"json": {"id": 1}}]');
      await waitFor(".workflows-context-panel__editor-save:not([disabled])");
      await click(".workflows-context-panel__editor-save");

      assert.deepEqual(requestBody, {
        node_name: "n1",
        items: [{ json: { id: 1 } }],
      });
    });

    test("renders the editor pre-populated with unwrapped items and no Save toolbar", async function (assert) {
      const items = [{ json: { hello: "world" } }];

      await render(
        <template>
          <PinDataEditor
            @nodeName="n1"
            @initialItems={{items}}
            @canEdit={{true}}
            @session={{this.session}}
          />
        </template>
      );

      await waitFor(".cm-editor");

      assert
        .dom(".workflows-context-panel__editor-toolbar")
        .doesNotExist("Save/Cancel toolbar only appears when buffer is dirty");
      assert.dom(".workflows-context-panel__empty-state").doesNotExist();
      const text = this.element
        .querySelector(".cm-content")
        ?.textContent.replace(/\s+/g, "");
      assert.true(
        text.includes('"hello":"world"'),
        `expected unwrapped JSON to contain '"hello":"world"', got ${text}`
      );
      assert.false(
        text.includes('"json":'),
        "the JSON envelope must not be shown to the user"
      );
    });

    test("Save/Cancel toolbar appears once the buffer is edited", async function (assert) {
      const items = [{ json: { hello: "world" } }];

      await render(
        <template>
          <PinDataEditor
            @nodeName="n1"
            @initialItems={{items}}
            @canEdit={{true}}
            @session={{this.session}}
          />
        </template>
      );

      await waitFor(".cm-editor");
      await setBuffer(this.element, '[{"hello": "edited"}]');

      assert.dom(".workflows-context-panel__editor-toolbar").exists();
      assert.dom(".workflows-context-panel__editor-save").exists();
      assert.dom(".workflows-context-panel__editor-cancel").exists();
    });

    test("read-only empty state when canEdit is false", async function (assert) {
      await render(
        <template>
          <PinDataEditor
            @nodeName="n1"
            @initialItems={{undefined}}
            @canEdit={{false}}
            @session={{this.session}}
          />
        </template>
      );

      assert.dom(".workflows-context-panel__empty-state-btn").doesNotExist();
      assert.dom(".workflows-context-panel__empty-state-title").exists();
    });
  }
);
