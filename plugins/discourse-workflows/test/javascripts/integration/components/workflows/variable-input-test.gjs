import { render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VariableInput from "discourse/plugins/discourse-workflows/admin/components/workflows/variable/input";

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
            @value=""
            @onChange={{onChange}}
            @onSetup={{onSetup}}
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
  }
);
