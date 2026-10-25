import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { trustHTML } from "@ember/template";
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
import { currentCompletions, startCompletion } from "@codemirror/autocomplete";
import { undo } from "@codemirror/commands";
import { EditorSelection, EditorState } from "@codemirror/state";
import { EditorView } from "@codemirror/view";
import { module, test } from "qunit";
import CodeEditor from "discourse/components/code-editor";
import loadCodemirror from "discourse/lib/load-codemirror";
import { capabilities } from "discourse/services/capabilities";
import { codeEditorView } from "discourse/tests/helpers/code-editor-helper";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { dragPointer } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
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

async function openCompletions(view) {
  view.dispatch({ selection: { anchor: view.state.doc.length } });
  startCompletion(view);
  await waitFor(".cm-tooltip-autocomplete li");
}

function completionLabels() {
  return [
    ...document.querySelectorAll(
      ".cm-tooltip-autocomplete .cm-completionLabel"
    ),
  ].map((label) => label.textContent.trim());
}

function highlightedTokens() {
  return [...document.querySelectorAll(".cm-content span[class]")].map((span) =>
    span.textContent.trim()
  );
}

function withTranslations(overrides, callback) {
  const translations = I18n.translations[I18n.locale].js.code_editor;
  const originals = overrides.map(([path]) => [
    path,
    path.reduce((o, k) => o[k], translations),
  ]);
  const set = (path, value) => {
    const parent = path.slice(0, -1).reduce((o, k) => o[k], translations);
    parent[path.at(-1)] = value;
  };
  overrides.forEach(([path, value]) => set(path, value));
  return Promise.resolve(callback()).finally(() =>
    originals.forEach(([path, value]) => set(path, value))
  );
}

module("Integration | Component | code-editor", function (hooks) {
  setupRenderingTest(hooks);

  test("renders plain text when no language matches", async function (assert) {
    await render(
      <template><CodeEditor @language="klingon" @value="select 1" /></template>
    );
    await waitFor(".cm-editor");

    assert.dom(".cm-content").hasText("select 1");
    assert.deepEqual(highlightedTokens(), [], "nothing is tokenized");
  });

  test("highlights by the language shortcut, following changes to it", async function (assert) {
    const state = new (class {
      @tracked language = "sql";
    })();

    await render(
      <template>
        <CodeEditor @language={{state.language}} @value="select 1" />
      </template>
    );
    await waitFor(".cm-content span[class]");

    assert.true(highlightedTokens().includes("select"));
    const before = highlightedTokens();

    state.language = "yaml";
    await settled();
    await waitUntil(
      () => JSON.stringify(highlightedTokens()) !== JSON.stringify(before)
    );

    assert.false(highlightedTokens().includes("select"), "re-tokenized");
  });

  test("localizes the editor's UI", async function (assert) {
    await withTranslations(
      [
        [["search", "find"], "Buscar"],
        [["completions"], "Sugerencias"],
        [["fold", "fold_line"], "Plegar"],
      ],
      async () => {
        await render(<template><CodeEditor @value="one" /></template>);
        const view = codeEditorView();

        pressWithModifier(find(".cm-content"), "f");
        await waitFor(".cm-search");

        assert
          .dom('.cm-search input[name="search"]')
          .hasAttribute("aria-label", "Buscar");
        assert.strictEqual(view.state.phrase("Completions"), "Sugerencias");
        assert.strictEqual(view.state.phrase("Fold line"), "Plegar");
        assert.strictEqual(
          view.state.phrase("replaced $ matches", 3),
          "Replaced matches: 3",
          "arguments are substituted"
        );
      }
    );
  });

  test("Escape closes what the editor owns before leaving it", async function (assert) {
    const seen = [];
    const spy = (event) => event.key === "Escape" && seen.push(event);
    document.documentElement.addEventListener("keydown", spy, {
      capture: true,
    });

    try {
      await render(<template><CodeEditor @value="one" /></template>);
      const view = codeEditorView();
      view.focus();
      pressWithModifier(find(".cm-content"), "f");
      await waitFor(".cm-search");

      await triggerKeyEvent(".cm-content", "keydown", "Escape");
      assert.dom(".cm-search").doesNotExist("the first Escape closes search");
      assert.true(view.hasFocus, "without leaving the editor");

      await triggerKeyEvent(".cm-content", "keydown", "Escape");
      assert.strictEqual(seen.length, 0, "neither reaches the document");

      await triggerKeyEvent(".cm-content", "keydown", "Escape");
      assert.strictEqual(seen.length, 1, "a third passes through");

      const tab = new KeyboardEvent("keydown", {
        key: "Tab",
        keyCode: 9,
        bubbles: true,
        cancelable: true,
      });
      view.contentDOM.dispatchEvent(tab);
      assert.false(tab.defaultPrevented, "and Tab is free to move focus");
      assert.strictEqual(view.state.doc.toString(), "one", "not indent");

      await triggerKeyEvent(".cm-content", "keydown", 65);
      await triggerKeyEvent(".cm-content", "keydown", "Escape");
      assert.strictEqual(seen.length, 1, "typing re-arms the sequence");
    } finally {
      document.documentElement.removeEventListener("keydown", spy, {
        capture: true,
      });
    }
  });

  test("turns on code-editing behaviour", async function (assert) {
    await render(<template><CodeEditor @value="" /></template>);
    const view = codeEditorView();

    view.state
      .facet(EditorView.inputHandler)
      .some((handler) => handler(view, 0, 0, "(", () => null));
    assert.strictEqual(view.state.doc.toString(), "()", "brackets pair");
    await triggerKeyEvent(".cm-content", "keydown", "Backspace");
    assert.strictEqual(view.state.doc.toString(), "", "and unpair");

    view.dispatch({
      changes: { from: 0, insert: "(one) two one" },
      selection: { anchor: 0 },
    });
    await waitFor(".cm-matchingBracket");
    assert.dom(".cm-matchingBracket").exists({ count: 2 }, "brackets match");

    view.dispatch({ selection: { anchor: 1, head: 4 } });
    await waitFor(".cm-selectionMatch");
    assert.dom(".cm-selectionMatch").hasText("one", "selection matches show");

    view.dispatch({
      selection: EditorSelection.create([
        EditorSelection.cursor(0),
        EditorSelection.cursor(6),
      ]),
    });
    view.dispatch(view.state.replaceSelection("x"));
    assert.strictEqual(
      view.state.doc.toString(),
      "x(one) xtwo one",
      "several cursors edit at once"
    );

    assert.dom(".cm-activeLine").exists("the active line is marked");
    assert
      .dom(".cm-gutter:last-of-type")
      .hasClass("cm-foldGutter", "the fold gutter follows the line numbers");
  });

  test("re-indents and folds blocks of the language", async function (assert) {
    const value = "if (a) {\n  b;\n  ";
    await render(
      <template>
        <CodeEditor @language="javascript" @value={{value}} />
      </template>
    );
    await waitFor(".cm-content span[class]");
    const view = codeEditorView();

    const end = view.state.doc.length;
    view.dispatch({
      changes: { from: end, insert: "}" },
      selection: { anchor: end + 1 },
      userEvent: "input.type",
    });
    assert.strictEqual(view.state.doc.toString(), "if (a) {\n  b;\n}");

    // The gutter's first element is a hidden spacer, not a line marker.
    const marker =
      '.cm-foldGutter .cm-gutterElement:not([style*="visibility"]) [title]';
    await waitFor(marker);
    await click(marker);

    assert.dom(".cm-foldPlaceholder").exists();
    assert.dom(".cm-line").exists({ count: 1 }, "the block collapses");
  });

  test("leaves the bare editor without code-editing behaviour", async function (assert) {
    const Editor = await loadCodemirror();
    await render(<template><Editor @value="(one)" /></template>);
    const view = codeEditorView(".codemirror-editor");

    view.dispatch({ selection: { anchor: 0 } });
    await settled();

    assert.dom(".cm-matchingBracket").doesNotExist();
    assert.dom(".cm-foldGutter").doesNotExist();
    assert.dom(".cm-activeLine").doesNotExist();
    assert.false(view.state.facet(EditorState.allowMultipleSelections));
  });

  test("finds and replaces text inside the editor", async function (assert) {
    await render(<template><CodeEditor @value="one two one" /></template>);
    pressWithModifier(find(".cm-content"), "f");
    await waitFor(".cm-search");
    await fillIn('.cm-search input[name="search"]', "one");
    await fillIn('.cm-search input[name="replace"]', "three");
    await click('.cm-search button[name="replaceAll"]');

    assert.dom(".cm-content").hasText("three two three");
  });

  test("indents and outdents with Tab", async function (assert) {
    await render(<template><CodeEditor @value="one" /></template>);
    const view = codeEditorView();

    await triggerKeyEvent(".cm-content", "keydown", "Tab");
    assert.strictEqual(view.state.doc.toString(), "  one");

    await triggerKeyEvent(".cm-content", "keydown", "Tab", { shiftKey: true });
    assert.strictEqual(view.state.doc.toString(), "one");
  });

  test("reports edits and focus through its callbacks", async function (assert) {
    const events = [];
    const onChange = (value) => events.push(`change:${value}`);
    const onFocusIn = () => events.push("in");
    const onFocusOut = () => events.push("out");

    await render(
      <template>
        <CodeEditor
          @onChange={{onChange}}
          @onFocusIn={{onFocusIn}}
          @onFocusOut={{onFocusOut}}
          @value=""
        />
      </template>
    );
    const view = codeEditorView();

    view.dispatch({ changes: { from: 0, insert: "typed" } });
    view.focus();
    await waitUntil(() => events.includes("in"));
    view.contentDOM.blur();
    await waitUntil(() => events.includes("out"));

    assert.deepEqual(events, ["change:typed", "in", "out"]);
  });

  test("wires the field's accessibility attributes", async function (assert) {
    const state = new (class {
      @tracked invalid = true;
    })();

    await render(
      <template>
        <CodeEditor
          @describedBy="help"
          @inputId="field"
          @invalid={{state.invalid}}
          @value=""
        />
      </template>
    );
    await waitFor(".cm-editor");

    assert.dom(".cm-content").hasAttribute("id", "field");
    assert.dom(".cm-content").hasAttribute("aria-describedby", "help");
    assert.dom(".cm-content").hasAttribute("aria-invalid", "true");

    state.invalid = false;
    await settled();

    assert.dom(".cm-content").doesNotHaveAttribute("aria-invalid");
  });

  test("disabled rejects edits but keeps the document focusable", async function (assert) {
    const state = new (class {
      @tracked disabled = true;
    })();

    await render(
      <template>
        <CodeEditor @disabled={{state.disabled}} @value="fixed" />
      </template>
    );
    const view = codeEditorView();

    assert.true(view.state.readOnly);
    view.focus();
    assert.true(view.hasFocus, "it can still be read and copied");

    state.disabled = false;
    await settled();

    assert.false(view.state.readOnly);
  });

  test("binds save and submit to their shortcuts", async function (assert) {
    const calls = [];
    const save = () => calls.push("save");
    const submit = () => calls.push("submit");

    await render(
      <template>
        <CodeEditor @onSave={{save}} @onSubmit={{submit}} @value="one" />
      </template>
    );
    await waitFor(".cm-editor");

    pressWithModifier(find(".cm-content"), "s");
    pressWithModifier(find(".cm-content"), "Enter");
    await settled();

    assert.deepEqual(calls, ["save", "submit"]);
    assert.strictEqual(
      codeEditorView().state.doc.toString(),
      "one",
      "submit does not insert a newline"
    );
  });

  test("honours the layout arguments", async function (assert) {
    await render(
      <template>
        <CodeEditor
          @autofocus={{true}}
          @lineNumbers={{false}}
          @lineWrapping={{true}}
          @value="one"
        />
      </template>
    );
    await waitFor(".cm-editor");

    assert.true(codeEditorView().hasFocus, "autofocus");
    assert.dom(".cm-lineNumbers").doesNotExist("no line numbers");
    assert.dom(".cm-lineWrapping").exists("wrapping");
  });

  test("adds a caller's raw extensions", async function (assert) {
    const extensions = ({ cmView }) => [
      cmView.EditorView.editorAttributes.of({ "data-custom": "yes" }),
    ];

    await render(
      <template><CodeEditor @extensions={{extensions}} @value="" /></template>
    );
    await waitFor(".cm-editor");

    assert.dom(".cm-editor").hasAttribute("data-custom", "yes");
  });

  test("a value replaced from outside cannot be undone into the old document", async function (assert) {
    const state = new (class {
      @tracked value = "one";
    })();

    await render(
      <template>
        <CodeEditor @onChange={{fn (mut state.value)}} @value={{state.value}} />
      </template>
    );
    const view = codeEditorView();
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
    const state = new (class {
      @tracked languageOptions = { schema: {} };
    })();

    await render(
      <template>
        <CodeEditor
          @language="sql"
          @languageOptions={{state.languageOptions}}
          @value="SELECT badges."
        />
      </template>
    );
    await waitFor(".cm-content span[class]");

    state.languageOptions = { schema: { badges: ["allow_title"] } };
    await settled();
    await openCompletions(codeEditorView());

    assert.true(completionLabels().includes("allow_title"));
  });

  test("offers the completions a caller lists, beside the language's own", async function (assert) {
    const languageOptions = { schema: { badges: ["allow_title"] } };
    const completions = ["b_custom"];

    await render(
      <template>
        <CodeEditor
          @completions={{completions}}
          @language="sql"
          @languageOptions={{languageOptions}}
          @value="SELECT b"
        />
      </template>
    );
    await waitFor(".cm-content span[class]");
    const view = codeEditorView();
    await openCompletions(view);

    const labels = currentCompletions(view.state).map((c) => c.label);
    assert.true(labels.includes("badges"), "the language's own");
    assert.true(labels.includes("b_custom"), "and the caller's");
  });

  test("marks the lines a caller reports as warnings", async function (assert) {
    const state = new (class {
      @tracked warnings = [{ line: 2, message: "Avoid this" }];
    })();
    const value = ["fine", "suspect", "fine"].join("\n");

    await render(
      <template>
        <CodeEditor @lineWarnings={{state.warnings}} @value={{value}} />
      </template>
    );
    await waitFor(".cm-lintRange");

    assert.dom(".cm-lintRange").exists({ count: 1 }).hasText("suspect");
    assert.dom(".cm-lint-marker").exists({ count: 1 }, "with a gutter icon");

    state.warnings = [];
    await settled();
    await waitUntil(() => !document.querySelector(".cm-lintRange"));

    assert.dom(".cm-lintRange").doesNotExist();
  });

  test("keeps line warnings when the value is swapped", async function (assert) {
    const state = new (class {
      @tracked value = "one\ntwo";
    })();
    const warnings = [{ line: 1, message: "Avoid this" }];

    await render(
      <template>
        <CodeEditor @lineWarnings={{warnings}} @value={{state.value}} />
      </template>
    );
    await waitFor(".cm-lintRange");

    state.value = "uno\ndos";
    await settled();

    assert.dom(".cm-lintRange").exists({ count: 1 }).hasText("uno");
  });

  test("fills a host that only sets a minimum height", async function (assert) {
    await render(
      <template><CodeEditor style="min-height: 240px" @value="one" /></template>
    );
    await waitFor(".cm-editor");

    assert.true(find(".cm-editor").offsetHeight >= 230);
  });

  test("keeps code left to right inside a right-to-left page", async function (assert) {
    await render(
      <template>
        <div dir="rtl"><CodeEditor @value="one" /></div>
      </template>
    );
    await waitFor(".cm-editor");

    assert.strictEqual(getComputedStyle(find(".cm-content")).direction, "ltr");
  });

  test("renders a placeholder as markup only when it is trusted", async function (assert) {
    const plain = "<b>bold</b>";
    const trusted = trustHTML("<b>bold</b>");

    await render(
      <template>
        <div class="plain"><CodeEditor @placeholder={{plain}} @value="" /></div>
        <div class="trusted"><CodeEditor
            @placeholder={{trusted}}
            @value=""
          /></div>
      </template>
    );
    await waitUntil(
      () => document.querySelectorAll(".cm-placeholder").length === 2
    );

    assert.dom(".plain .cm-placeholder b").doesNotExist();
    assert.dom(".plain .cm-placeholder").hasText("<b>bold</b>");
    assert.dom(".trusted .cm-placeholder b").hasText("bold");
  });

  test("shows a placeholder that arrives after the editor is built", async function (assert) {
    const state = new (class {
      @tracked placeholder = "";
    })();

    await render(
      <template>
        <CodeEditor @placeholder={{state.placeholder}} @value="" />
      </template>
    );
    await waitFor(".cm-editor");

    assert.dom(".cm-placeholder").doesNotExist();

    state.placeholder = "Write something";
    await settled();
    await waitFor(".cm-placeholder");

    assert.dom(".cm-placeholder").hasText("Write something");

    state.placeholder = "";
    await settled();
    await waitUntil(() => !document.querySelector(".cm-placeholder"));

    assert.dom(".cm-placeholder").doesNotExist();
  });

  test("resizes from its handle when asked for one", async function (assert) {
    await render(<template><CodeEditor @value="" /></template>);
    await waitFor(".cm-editor");
    assert.dom(".code-editor .grippie").doesNotExist("none by default");

    await render(
      <template>
        <CodeEditor
          style="height: 200px"
          @resizable={{true}}
          @value="SELECT 1"
        />
      </template>
    );
    await waitFor(".cm-editor");

    const editor = find(".code-editor");
    const initialHeight = editor.offsetHeight;
    await dragPointer(find(".code-editor .grippie"), { from: 50, to: 170 });

    assert.strictEqual(editor.offsetHeight, initialHeight + 120);
  });
});
