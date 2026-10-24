import { tracked } from "@glimmer/tracking";
import {
  find,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import LiquidControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/liquid-control";
import { WORKFLOW_VARIABLE_MIME } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context";

async function renderEditor(field, { node, session } = {}) {
  await render(
    <template>
      <LiquidControl @field={{field}} @node={{node}} @session={{session}} />
    </template>
  );
  await waitFor(".cm-editor");
  return find(".codemirror-editor").codemirrorView;
}

// Dropped at the end of the document.
async function dropVariable(view, id) {
  const coords = view.coordsAtPos(view.state.doc.length);
  await triggerEvent(".cm-editor", "drop", {
    clientX: coords?.right,
    clientY: coords?.top,
    dataTransfer: {
      getData: (mime) =>
        mime === WORKFLOW_VARIABLE_MIME
          ? JSON.stringify({ id, type: "string" })
          : "",
    },
  });
}

// Each keystroke goes through the editor's input handlers, as typing does; a
// read-only editor takes nothing.
function type(view, text) {
  for (const char of text) {
    const { from, to } = view.state.selection.main;
    const handled = view.state
      .facet(view.constructor.inputHandler)
      .some((handler) => handler(view, from, to, char, () => null));
    if (!handled && !view.state.readOnly) {
      view.dispatch(view.state.replaceSelection(char));
    }
  }
}

module("Integration | Component | Workflows | Liquid editor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
      response(200, { variables: [] })
    );
  });

  test("wires the field's accessibility and validation state", async function (assert) {
    const field = new (class {
      @tracked error = "Invalid template";
      id = "template-input";
      name = "template";
      describedBy = "template-help";
      value = "original";

      set() {}
    })();

    await renderEditor(field);

    assert.dom(".cm-content").hasAttribute("id", field.id);
    assert
      .dom(".cm-content")
      .hasAttribute("aria-describedby", field.describedBy);
    assert.dom(".cm-content").hasAttribute("aria-invalid", "true");
    assert.dom(".code-editor .grippie").exists("resizable");

    field.error = null;
    await settled();
    assert.dom(".cm-content").doesNotHaveAttribute("aria-invalid");
  });

  test("ignores typing and drops on a disabled template", async function (assert) {
    const field = {
      value: "{",
      disabled: true,
      set() {
        assert.step("changed");
      },
    };
    const view = await renderEditor(field);

    assert.dom(".cm-content").hasAttribute("contenteditable", "false");

    type(view, "{");
    await dropVariable(view, "$json.name");

    assert.strictEqual(view.state.doc.toString(), "{");
    assert.verifySteps([]);
  });

  test("completes a branch at its original input port after a connection is removed", async function (assert) {
    const node = { clientId: "template", name: "Template" };
    const session = {
      graphNodes: [
        { clientId: "first", name: "First" },
        { clientId: "third", name: "Third" },
        node,
      ],
      graphConnections: [
        {
          sourceClientId: "first",
          targetClientId: "template",
          targetInputIndex: 0,
        },
        {
          sourceClientId: "third",
          targetClientId: "template",
          targetInputIndex: 2,
        },
      ],
      pinnedItemsForNode(name) {
        return name === "Third"
          ? [{ json: { email: "alice@example.com" } }]
          : [{ json: { name: "Alice" } }];
      },
    };
    const view = await renderEditor(
      { value: "{{ inputs[2][0].", set() {} },
      { node, session }
    );

    view.dispatch({ selection: { anchor: view.state.doc.length } });
    view.focus();
    await triggerKeyEvent(view.contentDOM, "keydown", 32, { ctrlKey: true });
    await waitFor(".cm-completionLabel");

    assert.dom(".cm-tooltip-autocomplete").includesText("email");
    assert.dom(".cm-tooltip-autocomplete").doesNotIncludeText("name");
  });

  test("typing an opening delimiter closes it once", async function (assert) {
    const view = await renderEditor({ value: "", set() {} });
    await waitUntil(() => view.state.languageDataAt("closeBrackets", 0).length);

    type(view, "{{");
    assert.strictEqual(view.state.doc.toString(), "{{  }}", "output tag");

    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: "" },
    });
    type(view, "{%");
    assert.strictEqual(view.state.doc.toString(), "{%  %}", "logic tag");

    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: "}}" },
      selection: { anchor: 0 },
    });
    type(view, "{{");
    assert.strictEqual(
      view.state.doc.toString(),
      "{{  }}",
      "an existing closer is reused"
    );
  });

  test("highlights the template's tags and output", async function (assert) {
    await renderEditor({
      value: "{% for item in items %}{{ item.name | upcase }}{% endfor %}",
      set() {},
    });
    await waitFor(".cm-hl-bracket");

    assert.dom(".cm-hl-keyword").hasText("for");
    assert.dom(".cm-hl-property").hasText("name");
    assert.dom(".cm-hl-function").hasText("upcase");
  });

  test("drops a dragged field as a path the template can render", async function (assert) {
    const view = await renderEditor({
      value: "{% for row in items %}\n",
      set() {},
    });

    await dropVariable(view, "$json.name");

    assert.strictEqual(
      view.state.doc.toString(),
      "{% for row in items %}\n{{ row.name }}"
    );
  });

  test("drops a bare path inside an open output tag", async function (assert) {
    const view = await renderEditor({ value: "{{ ", set() {} });

    await dropVariable(view, "$json.topic.title");

    assert.strictEqual(view.state.doc.toString(), "{{ items[0].topic.title");
  });
});
