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

    hooks.beforeEach(function () {
      this.siteSettings.discourse_graphviz_enabled = true;

      resetRichEditorExtensions().then(() => {
        registerRichEditorExtension(richEditorExtension);
      });
    });

    test("round-trips a graph", async function (assert) {
      await testMarkdown(
        assert,
        GRAPH,
        (a) => a.dom(".composer-preview-node").exists(),
        GRAPH
      );
    });

    test("round-trips a graph with an engine", async function (assert) {
      const graph = GRAPH.replace("[graphviz]", "[graphviz engine=neato]");

      await testMarkdown(
        assert,
        graph,
        (a) => a.dom(".composer-preview-node").exists(),
        graph
      );
    });

    test("keeps the source when the text around it is edited", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        `before\n\n${GRAPH}\n\nafter`
      );
      const { view } = editorClass;

      let graphPos;
      view.state.doc.descendants((node, pos) => {
        if (node.type.name === "graphviz") {
          graphPos = pos;
        }
      });

      // delete across the graph's closing boundary, as backspacing at the start
      // of the paragraph that follows it would
      const boundary = graphPos + view.state.doc.nodeAt(graphPos).nodeSize;
      view.dispatch(view.state.tr.delete(boundary, boundary + 1));

      assert.true(
        editorClass.value.includes(GRAPH),
        `the graph source is untouched, got: ${editorClass.value}`
      );
    });
  }
);
