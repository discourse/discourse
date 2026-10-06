import { find } from "@ember/test-helpers";
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
const TALL_GRAPH = `[graphviz]\ndigraph G {\n${Array.from(
  { length: 50 },
  (_, index) => `  // node ${index}`
).join("\n")}\n  a -> b;\n}\n[/graphviz]`;

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

    test("constrains a diagram with tall source", async function (assert) {
      await setupRichEditor(assert, TALL_GRAPH);

      const block = find(".composer-graphviz-node");
      const source = find(".composer-preview-node__source");
      const pre = source.querySelector("pre");
      const { height, width } = block.getBoundingClientRect();

      assert.true(
        Math.abs(height / width - 9 / 16) < 0.01,
        "the diagram uses the same aspect ratio as its cooked preview"
      );

      assert.true(
        Math.abs(source.clientHeight - block.clientHeight) <= 1,
        "the source face fills the frame, neither overflowing nor falling short"
      );

      assert.true(
        pre.scrollHeight > pre.clientHeight,
        "the source scrolls within the frame"
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
