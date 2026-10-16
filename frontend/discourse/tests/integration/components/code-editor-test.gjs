import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import {
  click,
  fillIn,
  find,
  render,
  settled,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { startCompletion } from "@codemirror/autocomplete";
import { undo } from "@codemirror/commands";
import { module, test } from "qunit";
import CodeEditor from "discourse/components/code-editor";
import { capabilities } from "discourse/services/capabilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

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

function completionLabels() {
  return [
    ...document.querySelectorAll(
      ".cm-tooltip-autocomplete .cm-completionLabel"
    ),
  ].map((label) => label.textContent.trim());
}

function highlightedTokens(element) {
  return [...element.querySelectorAll(".cm-content span[class]")].map((span) =>
    span.textContent.trim()
  );
}

module("Integration | Component | code-editor", function (hooks) {
  setupRenderingTest(hooks);

  test("uses translated search labels and announcements", async function (assert) {
    const translations = I18n.translations[I18n.locale].js.code_editor.search;
    const original = translations.find;
    translations.find = "Buscar";
    try {
      await render(<template><CodeEditor @value="one" /></template>);
      pressWithModifier(find(".cm-content"), "f");
      await waitFor(".cm-search");
      assert
        .dom('.cm-search input[name="search"]')
        .hasAttribute(
          "aria-label",
          "Buscar",
          "the search field uses Discourse translations"
        );
      const view = find(".codemirror-editor").codemirrorView;
      assert.strictEqual(
        view.state.phrase("replaced $ matches", 3),
        "Replaced matches: 3",
        "CodeMirror substitutes announcement arguments"
      );
    } finally {
      translations.find = original;
    }
  });

  test("Escape closes search before allowing Tab to leave the editor", async function (assert) {
    await render(<template><CodeEditor @value="one" /></template>);
    pressWithModifier(find(".cm-content"), "f");
    await waitFor(".cm-search");
    const view = find(".codemirror-editor").codemirrorView;
    view.focus();
    await triggerKeyEvent(".cm-content", "keydown", "Escape");
    assert.dom(".cm-search").doesNotExist("Escape closes the search panel");
    assert.true(view.hasFocus, "closing search keeps editor focus");

    await triggerKeyEvent(".cm-content", "keydown", "Escape");
    const tab = new KeyboardEvent("keydown", {
      key: "Tab",
      keyCode: 9,
      bubbles: true,
      cancelable: true,
    });
    view.contentDOM.dispatchEvent(tab);
    assert.false(tab.defaultPrevented, "the browser can move focus on Tab");
    assert.strictEqual(
      view.state.doc.toString(),
      "one",
      "the escape sequence does not indent"
    );
  });

  test("Escape stays inside the editor until it has nothing left to close", async function (assert) {
    const seen = [];
    const spy = (event) => event.key === "Escape" && seen.push(event);
    document.documentElement.addEventListener("keydown", spy, {
      capture: true,
    });

    try {
      await render(<template><CodeEditor @value="one" /></template>);
      const view = find(".codemirror-editor").codemirrorView;
      view.focus();
      pressWithModifier(find(".cm-content"), "f");
      await waitFor(".cm-search");
      view.focus();

      await triggerKeyEvent(".cm-content", "keydown", "Escape");
      await triggerKeyEvent(".cm-content", "keydown", "Escape");
      assert.strictEqual(
        seen.length,
        0,
        "closing search and freeing Tab do not reach the document"
      );

      await triggerKeyEvent(".cm-content", "keydown", "Escape");
      assert.strictEqual(seen.length, 1, "a further Escape passes through");

      await triggerKeyEvent(".cm-content", "keydown", 65);
      await triggerKeyEvent(".cm-content", "keydown", "Escape");
      assert.strictEqual(
        seen.length,
        1,
        "typing puts Tab back to indenting, so Escape stays inside again"
      );
    } finally {
      document.documentElement.removeEventListener("keydown", spy, {
        capture: true,
      });
    }
  });

  test("finds and replaces text inside the editor", async function (assert) {
    await render(<template><CodeEditor @value="one two one" /></template>);
    pressWithModifier(find(".cm-content"), "f");
    await waitFor(".cm-search");
    await fillIn('.cm-search input[name="search"]', "one");
    await fillIn('.cm-search input[name="replace"]', "three");
    await click('.cm-search button[name="replaceAll"]');

    assert
      .dom(".cm-content")
      .hasText("three two three", "replace all edits the document");
  });

  test("indents and outdents with Tab", async function (assert) {
    await render(<template><CodeEditor @value="one" /></template>);
    await triggerKeyEvent(".cm-content", "keydown", "Tab");
    const view = find(".codemirror-editor").codemirrorView;
    assert.strictEqual(
      view.state.doc.toString(),
      "  one",
      "Tab indents the line"
    );
    await triggerKeyEvent(".cm-content", "keydown", "Tab", { shiftKey: true });
    assert.strictEqual(
      view.state.doc.toString(),
      "one",
      "Shift-Tab outdents the line"
    );
  });

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
        <CodeEditor @onChange={{onChange}} @onSetup={{onSetup}} @value="" />
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
        <CodeEditor @disabled={{state.disabled}} @value="fixed" />
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
        <CodeEditor @save={{save}} @submit={{submit}} @value="" />
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
          @onSetup={{onSetup}}
          @value="SELECT badges."
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

  test("highlights the active line", async function (assert) {
    await render(<template><CodeEditor @value="one" /></template>);

    assert.dom(".cm-activeLine").exists();
    assert.dom(".cm-activeLineGutter").exists();
  });

  test("a value replaced from outside cannot be undone into the old document", async function (assert) {
    let view;
    const onSetup = (editorView) => (view = editorView);
    const state = new (class {
      @tracked value = "one";
    })();

    await render(
      <template>
        <CodeEditor
          @onChange={{fn (mut state.value)}}
          @onSetup={{onSetup}}
          @value={{state.value}}
        />
      </template>
    );
    view.dispatch({ changes: { from: 3, insert: " typed" } });
    await settled();

    state.value = "two";
    await settled();
    undo(view);
    await settled();

    assert.strictEqual(view.state.doc.toString(), "two");
    assert.strictEqual(state.value, "two");
  });

  test("picks up language options that change after the editor is built", async function (assert) {
    let view;
    const onSetup = (editorView) => (view = editorView);
    const state = new (class {
      @tracked languageOptions = { schema: {} };
    })();

    await render(
      <template>
        <CodeEditor
          @language="sql"
          @languageOptions={{state.languageOptions}}
          @onSetup={{onSetup}}
          @value="SELECT badges."
        />
      </template>
    );
    await waitFor(".cm-content span[class]");

    state.languageOptions = { schema: { badges: ["allow_title"] } };
    await settled();

    view.dispatch({ selection: { anchor: view.state.doc.length } });
    startCompletion(view);
    await waitUntil(() =>
      document.querySelector(".cm-tooltip-autocomplete li")
    );

    assert.true(
      completionLabels().includes("allow_title"),
      "a schema that arrived later is offered"
    );
  });

  test("offers the completions a caller lists, with no language set", async function (assert) {
    let view;
    const onSetup = (editorView) => (view = editorView);
    const completions = ["alpha_one", { label: "alpha_two", detail: "number" }];

    await render(
      <template>
        <CodeEditor
          @completions={{completions}}
          @onSetup={{onSetup}}
          @value="alp"
        />
      </template>
    );

    view.dispatch({ selection: { anchor: view.state.doc.length } });
    startCompletion(view);
    await waitUntil(() =>
      document.querySelector(".cm-tooltip-autocomplete li")
    );

    assert.deepEqual(completionLabels(), ["alpha_one", "alpha_two"]);
  });

  test("stacks a caller's completion source on the language's own", async function (assert) {
    let view;
    const onSetup = (editorView) => (view = editorView);
    const languageOptions = { schema: { badges: ["allow_title"] } };
    const completions = (context) => {
      const word = context.matchBefore(/\w+/);
      return word && { from: word.from, options: [{ label: "b_custom" }] };
    };

    await render(
      <template>
        <CodeEditor
          @completions={{completions}}
          @language="sql"
          @languageOptions={{languageOptions}}
          @onSetup={{onSetup}}
          @value="SELECT b"
        />
      </template>
    );
    await waitFor(".cm-content span[class]");

    view.dispatch({ selection: { anchor: view.state.doc.length } });
    startCompletion(view);
    await waitUntil(() =>
      document.querySelector(".cm-tooltip-autocomplete li")
    );

    const labels = completionLabels();
    assert.true(labels.includes("badges"), "the language still offers its own");
    assert.true(
      labels.includes("b_custom"),
      "the caller's source is offered too"
    );
  });

  test("marks the lines a caller reports as warnings", async function (assert) {
    class State {
      @tracked warnings = [{ line: 2, message: "Avoid this" }];
    }
    const state = new State();
    const value = ["fine", "suspect", "fine"].join("\n");

    await render(
      <template>
        <CodeEditor @lineWarnings={{state.warnings}} @value={{value}} />
      </template>
    );
    await waitUntil(() => document.querySelector(".cm-lintRange"));

    assert
      .dom(".cm-lintRange")
      .exists({ count: 1 }, "only the reported line is marked");

    state.warnings = [];
    await settled();
    await waitUntil(() => !document.querySelector(".cm-lintRange"));

    assert
      .dom(".cm-lintRange")
      .doesNotExist("clearing the warnings unmarks it");
  });

  test("shows a placeholder that arrives after the editor is built", async function (assert) {
    class State {
      @tracked placeholder = "";
    }
    const state = new State();

    await render(
      <template>
        <CodeEditor @placeholder={{state.placeholder}} @value="" />
      </template>
    );
    await waitFor(".cm-editor");

    assert
      .dom(".cm-placeholder")
      .doesNotExist("nothing to show while the placeholder is empty");

    state.placeholder = "Write something";
    await settled();
    await waitUntil(() => document.querySelector(".cm-placeholder"));

    assert
      .dom(".cm-placeholder")
      .hasText(
        "Write something",
        "a later placeholder still reaches the editor"
      );

    state.placeholder = "";
    await settled();
    await waitUntil(() => !document.querySelector(".cm-placeholder"));

    assert.dom(".cm-placeholder").doesNotExist("and clearing it removes it");
  });

  test("releases the element handle when torn down", async function (assert) {
    class State {
      @tracked shown = true;
    }
    const state = new State();

    await render(
      <template>{{#if state.shown}}<CodeEditor @value="" />{{/if}}</template>
    );
    await waitFor(".cm-editor");

    const container = this.element.querySelector(".codemirror-editor");
    assert.strictEqual(
      typeof container.codemirrorView?.dispatch,
      "function",
      "the handle is live while mounted"
    );

    state.shown = false;
    await settled();

    assert.strictEqual(
      container.codemirrorView,
      undefined,
      "a destroyed view is not left reachable from the element"
    );
  });

  test("resizable adds a drag handle", async function (assert) {
    await render(
      <template><CodeEditor @resizable={{true}} @value="" /></template>
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
