import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";
import richEditorExtension from "discourse/plugins/discourse-graphviz/discourse/lib/rich-editor-extension";

const GRAPH = "[graphviz]\ndigraph G {\n  a -> b;\n}\n[/graphviz]";

module(
  "Integration | Component | prosemirror-editor - graphviz extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      this.siteSettings.discourse_graphviz_enabled = true;

      await resetRichEditorExtensions();
      registerRichEditorExtension(richEditorExtension);
    });

    [
      ["no engine", GRAPH],
      ["an engine", GRAPH.replace("[graphviz]", "[graphviz engine=neato]")],
    ].forEach(([name, markdown]) => {
      test(`round-trips a graph with ${name}`, async function (assert) {
        await testMarkdown(assert, markdown, () => {}, markdown);
      });
    });

    test("keeps the line breaks of a pasted diagram", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "");
      const { view } = editorClass;

      view.pasteHTML(
        '<div class="graphviz is-loading" data-engine="neato">\ndigraph G {\n  a -&gt; b;\n  b -&gt; c;\n}\n</div>'
      );

      assert.strictEqual(
        editorClass.value.trim(),
        "[graphviz engine=neato]\ndigraph G {\n  a -> b;\n  b -> c;\n}\n[/graphviz]",
        "the source survives the round trip through cooked HTML"
      );
    });

    test("puts the caret in the source of a diagram it just inserted", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "before");
      const { view } = editorClass;

      view.dispatch(view.state.tr.insertText("[graphviz"));
      const pos = view.state.selection.from;
      view.someProp("handleTextInput", (f) => f(view, pos, pos, "]"));

      const { selection } = view.state;
      assert.strictEqual(
        selection.$head.parent.type.name,
        "preview_source",
        "typing carries on inside the new diagram"
      );
    });
  }
);
