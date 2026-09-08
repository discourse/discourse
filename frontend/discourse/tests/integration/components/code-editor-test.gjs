import { tracked } from "@glimmer/tracking";
import { render, settled, waitFor, waitUntil } from "@ember/test-helpers";
import { startCompletion } from "@codemirror/autocomplete";
import { module, test } from "qunit";
import CodeEditor from "discourse/components/code-editor";
import { capabilities } from "discourse/services/capabilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// The editor binds to whichever modifier the platform uses for its commands.
function pressWithModifier(element, key) {
  const modifier = capabilities.isApple ? "metaKey" : "ctrlKey";

  element.dispatchEvent(
    new KeyboardEvent("keydown", {
      key,
      [modifier]: true,
      bubbles: true,
      cancelable: true,
    })
  );
}

function highlightedTokens(element) {
  return [...element.querySelectorAll(".cm-content span[class]")].map((span) =>
    span.textContent.trim()
  );
}

module("Integration | Component | code-editor", function (hooks) {
  setupRenderingTest(hooks);

  test("renders an editor for the value", async function (assert) {
    await render(<template><CodeEditor @value="select 1" /></template>);
    await waitFor(".cm-editor");

    assert.dom(".code-editor").exists();
    assert.dom(".cm-content").hasText("select 1");
  });

  test("highlights according to the language shortcut", async function (assert) {
    await render(
      <template><CodeEditor @language="sql" @value="select 1" /></template>
    );
    await waitFor(".cm-content span[class]");

    assert.true(
      highlightedTokens(this.element).includes("select"),
      "the keyword is tokenized"
    );
  });

  test("re-highlights when the language changes", async function (assert) {
    class State {
      @tracked language = "sql";
    }
    const state = new State();

    await render(
      <template>
        <CodeEditor @language={{state.language}} @value="select 1" />
      </template>
    );
    await waitFor(".cm-content span[class]");
    const before = this.element.querySelector(".cm-content").innerHTML;

    state.language = "yaml";
    await settled();
    await waitFor(".cm-editor");

    assert.notStrictEqual(
      this.element.querySelector(".cm-content").innerHTML,
      before,
      "switching the shortcut re-tokenizes the document"
    );
  });

  test("falls back to plain text for an unknown language", async function (assert) {
    await render(
      <template><CodeEditor @language="klingon" @value="select 1" /></template>
    );
    await waitFor(".cm-editor");

    assert.dom(".cm-content").hasText("select 1", "the document still renders");
  });

  test("reports edits through onChange", async function (assert) {
    let captured;
    let view;
    const onChange = (value) => (captured = value);
    const onSetup = (editorView) => (view = editorView);

    await render(
      <template>
        <CodeEditor @value="" @onChange={{onChange}} @onSetup={{onSetup}} />
      </template>
    );
    await waitFor(".cm-editor");

    view.dispatch({ changes: { from: 0, insert: "typed" } });

    assert.strictEqual(captured, "typed");
  });

  test("disabled makes the content read-only, and lifts when cleared", async function (assert) {
    class State {
      @tracked disabled = true;
    }
    const state = new State();

    await render(
      <template>
        <CodeEditor @value="fixed" @disabled={{state.disabled}} />
      </template>
    );
    await waitFor(".cm-editor");

    assert.dom(".cm-content").hasAttribute("contenteditable", "false");

    state.disabled = false;
    await settled();

    assert
      .dom(".cm-content")
      .hasAttribute("contenteditable", "true", "editing is restored");
  });

  test("binds save and submit to their shortcuts", async function (assert) {
    let saved = 0;
    let submitted = 0;
    const save = () => saved++;
    const submit = () => submitted++;

    await render(
      <template>
        <CodeEditor @value="" @save={{save}} @submit={{submit}} />
      </template>
    );
    await waitFor(".cm-editor");

    const content = this.element.querySelector(".cm-content");
    pressWithModifier(content, "s");
    pressWithModifier(content, "Enter");
    await settled();

    assert.strictEqual(saved, 1, "save fires on its shortcut");
    assert.strictEqual(submitted, 1, "submit fires on its shortcut");
  });

  test("surfaces the completions a language contributes", async function (assert) {
    let view;
    const onSetup = (editorView) => (view = editorView);
    const languageOptions = {
      schema: { badges: ["allow_title", "grant_count"] },
    };

    await render(
      <template>
        <CodeEditor
          @language="sql"
          @languageOptions={{languageOptions}}
          @value="SELECT badges."
          @onSetup={{onSetup}}
        />
      </template>
    );
    await waitFor(".cm-content span[class]");

    view.dispatch({ selection: { anchor: view.state.doc.length } });
    startCompletion(view);
    await waitUntil(() =>
      document.querySelector(".cm-tooltip-autocomplete li")
    );

    const labels = [
      ...document.querySelectorAll(".cm-tooltip-autocomplete li"),
    ].map((li) => li.textContent.trim());

    assert.true(
      labels.includes("allow_title"),
      "a column from the configured schema is offered"
    );
  });

  test("resizable adds a drag handle", async function (assert) {
    await render(
      <template><CodeEditor @value="" @resizable={{true}} /></template>
    );
    await waitFor(".cm-editor");

    assert.dom(".code-editor .grippie").exists();
  });

  test("omits the drag handle by default", async function (assert) {
    await render(<template><CodeEditor @value="" /></template>);
    await waitFor(".cm-editor");

    assert.dom(".code-editor .grippie").doesNotExist();
  });
});
