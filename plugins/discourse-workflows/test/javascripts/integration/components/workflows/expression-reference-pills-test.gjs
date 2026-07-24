import { render, waitFor, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VariableInput from "discourse/plugins/discourse-workflows/admin/components/workflows/variable/input";
import { buildFocusEmptyArea } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-extensions/focus-empty-area";
import { buildReferencePills } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-extensions/reference-pills";

// A scope where `$json` resolves, so simple references classify as valid.
const SCOPE = { $json: { title: "Hello", value: 1.2345 } };

// Minimal extension set: the expression language (so `{{ ... }}` parses into
// Expression nodes) plus the pill view plugin under test. Avoids the
// network-backed builders (completions, evaluation) that the full bundle adds.
function pillExtensions(cmParams) {
  return [
    cmParams.utils.expressionLanguage(),
    buildReferencePills(cmParams, { scope: SCOPE, onOpenReferencePicker() {} }),
  ];
}

function focusExtensions(cmParams) {
  return [buildFocusEmptyArea(cmParams)];
}

module(
  "Integration | Component | Workflows | expression reference pills",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
        response(200, { variables: [] })
      );
    });

    test("renders a simple reference as a pill, hiding the raw syntax", async function (assert) {
      const value = "{{ $json.title }}";

      await render(
        <template>
          <VariableInput @value={{value}} @extensions={{pillExtensions}} />
        </template>
      );
      await waitFor(".cm-wf-reference-pill");

      const pill = this.element.querySelector(".cm-wf-reference-pill");
      assert.dom(pill).exists("the reference renders as a pill");
      assert.true(
        pill.textContent.includes("title"),
        "the pill shows the property path"
      );
      assert.false(
        this.element
          .querySelector(".cm-content")
          .textContent.includes("$json.title"),
        "the raw expression syntax is hidden"
      );
    });

    test("leaves a complex expression as raw code (no pill)", async function (assert) {
      const value = "{{ $json.value.toFixed(2) }}";

      await render(
        <template>
          <VariableInput @value={{value}} @extensions={{pillExtensions}} />
        </template>
      );
      await waitFor(".cm-editor");

      assert
        .dom(".cm-wf-reference-pill")
        .doesNotExist("a method call is not pilled");
      assert.true(
        this.element
          .querySelector(".cm-content")
          .textContent.includes("toFixed"),
        "the raw expression stays visible for editing"
      );
    });

    test("selecting the expression marks the pill as selected", async function (assert) {
      const value = "{{ $json.title }}";
      let editorView;
      const onSetup = (view) => (editorView = view);

      await render(
        <template>
          <VariableInput
            @value={{value}}
            @extensions={{pillExtensions}}
            @onSetup={{onSetup}}
          />
        </template>
      );
      await waitFor(".cm-wf-reference-pill");

      editorView.dispatch({
        selection: { anchor: 0, head: editorView.state.doc.length },
      });
      await waitUntil(() =>
        this.element.querySelector(".cm-wf-reference-pill.--selected")
      );

      assert
        .dom(".cm-wf-reference-pill.--selected")
        .exists("the whole-pill selection renders the selected state");
    });

    test("clicking the empty area below the text focuses the editor and moves the caret to the end", async function (assert) {
      const value = "{{ $json.title }} more";
      let editorView;
      const onSetup = (view) => (editorView = view);

      await render(
        <template>
          <VariableInput
            @value={{value}}
            @extensions={{focusExtensions}}
            @onSetup={{onSetup}}
          />
        </template>
      );
      await waitFor(".cm-editor");

      // Caret at the start, then a mousedown on the empty scroller area.
      editorView.dispatch({ selection: { anchor: 0 } });
      this.element
        .querySelector(".cm-scroller")
        .dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

      assert.strictEqual(
        editorView.state.selection.main.anchor,
        editorView.state.doc.length,
        "the caret jumps to the end of the document"
      );
    });
  }
);
