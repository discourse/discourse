import { render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { registerCodeEditorLanguage } from "discourse/lib/code-editor-languages";
import { overrideCodemirrorImportForTesting } from "discourse/lib/load-codemirror";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import VariableInput from "discourse/plugins/discourse-workflows/admin/components/workflows/variable/input";
import { resetExpressionLanguageForTesting } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-language/index";

function editorText(element) {
  return element.querySelector(".cm-content")?.textContent ?? "";
}

module(
  "Integration | Component | Workflows | Variable | Input",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
        response(200, { variables: [] })
      );
    });

    test("renders CodeMirror editor", async function (assert) {
      await render(<template><VariableInput @value="" /></template>);
      await waitFor(".cm-editor");

      assert.dom(".workflows-variable-input").exists();
      assert.dom(".cm-editor").exists();
      assert.dom(".cm-content").exists();
    });

    test("displays expression value as text", async function (assert) {
      const value = "Hello {{ $current_user.username }}!";

      await render(<template><VariableInput @value={{value}} /></template>);
      await waitFor(".cm-editor");

      const text = editorText(this.element);
      assert.true(
        text.includes("$current_user.username"),
        "editor displays the expression variable"
      );
    });

    test("displays multiple expressions", async function (assert) {
      const value = "{{ $execution.id }} - {{ $json.title }}";

      await render(<template><VariableInput @value={{value}} /></template>);
      await waitFor(".cm-editor");

      const text = editorText(this.element);
      assert.true(text.includes("$execution.id"), "contains first expression");
      assert.true(text.includes("$json.title"), "contains second expression");
    });

    test("preserves value through render cycle", async function (assert) {
      const value = "prefix {{ $vars.API_URL }} suffix";

      await render(<template><VariableInput @value={{value}} /></template>);
      await waitFor(".cm-editor");

      const text = editorText(this.element);
      assert.true(text.includes("$vars.API_URL"), "expression is preserved");
      assert.true(text.includes("prefix"), "prefix text is preserved");
      assert.true(text.includes("suffix"), "suffix text is preserved");
    });

    test("fires onChange when user types", async function (assert) {
      let captured = null;
      let editorView = null;
      const onChange = (val) => (captured = val);
      const onSetup = (view) => (editorView = view);

      await render(
        <template>
          <VariableInput
            @onChange={{onChange}}
            @onSetup={{onSetup}}
            @value=""
          />
        </template>
      );
      await waitFor(".cm-editor");

      editorView.dispatch({ changes: { from: 0, insert: "hello" } });

      assert.strictEqual(
        captured,
        "hello",
        "onChange was called with the value"
      );
    });

    test("shows an error when the editor fails to load", async function (assert) {
      const failure = new Error("chunk failed");
      overrideCodemirrorImportForTesting(() => Promise.reject(failure));
      const consoleError = sinon.stub(console, "error");

      try {
        await render(<template><VariableInput @value="$json" /></template>);

        assert
          .dom(".workflows-variable-input__error")
          .hasText(i18n("code_editor.load_failed"));
        assert.true(consoleError.calledWith(failure), "the cause is logged");
      } finally {
        overrideCodemirrorImportForTesting(null);
      }
    });

    test("stays a plain text field when the expression language fails to load", async function (assert) {
      const failure = new Error("chunk failed");
      resetExpressionLanguageForTesting();
      registerCodeEditorLanguage("javascript", () => Promise.reject(failure));
      const consoleError = sinon.stub(console, "error");
      const extensions = sinon.stub().returns([]);

      try {
        await render(
          <template>
            <VariableInput @extensions={{extensions}} @value="$json" />
          </template>
        );

        assert.dom(".cm-content").hasText("$json");
        assert.false(extensions.called, "expression extensions are skipped");
        assert.true(consoleError.calledWith(failure), "the cause is logged");
      } finally {
        resetExpressionLanguageForTesting();
      }
    });

    test("stays a plain text field when its extensions fail to build", async function (assert) {
      const failure = new Error("bad scope");
      const consoleError = sinon.stub(console, "error");
      const extensions = () => {
        throw failure;
      };

      await render(
        <template>
          <VariableInput @extensions={{extensions}} @value="$json" />
        </template>
      );

      assert.dom(".cm-content").hasText("$json");
      assert.true(consoleError.calledWith(failure), "the cause is logged");
    });
  }
);
