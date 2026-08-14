import PreviewNodeView from "discourse/components/composer/preview-node-view";
import { i18n } from "discourse-i18n";
import GraphvizFullscreen from "../components/graphviz-fullscreen";
import GraphvizPreview from "../components/graphviz-preview";

// highlight.js calls the DOT language "dot"; sites whose highlighted_languages
// exclude it simply get an unhighlighted code block
const LANGUAGE = "dot";

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  nodeSpec: {
    graphviz: {
      attrs: { engine: { default: "dot" } },
      group: "block",
      // isolating keeps the text around it from merging into the source
      content: "preview_source",
      // the node view owns the source, so the editor moves over the block as a
      // unit rather than stepping into text it is not showing
      atom: true,
      defining: true,
      isolating: true,
      selectable: true,
      createGapCursor: true,
      parseDOM: [
        {
          tag: "div.graphviz",
          getAttrs: (dom) => ({ engine: dom.dataset.engine || "dot" }),
        },
      ],
      toDOM: (node) => [
        "div",
        { class: "graphviz", "data-engine": node.attrs.engine },
        0,
      ],
    },
  },

  nodeViews: {
    graphviz: {
      component: PreviewNodeView,
      hasContent: true,
      options: {
        preview: GraphvizPreview,
        controls: [
          {
            icon: "discourse-expand",
            label: i18n("graphviz.fullscreen"),
            action: ({ node, context }) =>
              context.modal.show(GraphvizFullscreen, {
                model: { src: node.textContent, engine: node.attrs.engine },
              }),
          },
        ],
      },
    },
  },

  parse: {
    graphviz: (state, token) => {
      state.openNode(state.schema.nodes.graphviz, {
        engine: token.attrGet("data-engine") || "dot",
      });
      state.openNode(state.schema.nodes.preview_source, { params: LANGUAGE });
      state.addText(token.content.trim());
      state.closeNode();
      state.closeNode();

      return true;
    },
  },

  inputRules: ({ schema }) => ({
    match: /\[graphviz(?: engine=(\w+))?]$/,
    handler: (state, match, start, end) => {
      const graphviz = schema.nodes.graphviz.createAndFill(
        { engine: match[1] || "dot" },
        schema.nodes.preview_source.create({ params: LANGUAGE })
      );
      const isAtStart = state.doc.resolve(start).parentOffset === 0;

      return state.tr.replaceWith(isAtStart ? start - 1 : start, end, graphviz);
    },
  }),

  serializeNode: {
    graphviz(state, node) {
      const { engine } = node.attrs;

      state.write(`[graphviz${engine === "dot" ? "" : ` engine=${engine}`}]\n`);
      state.text(node.textContent, false);
      state.write("\n[/graphviz]");
      state.closeBlock(node);
    },
  },
};

export default extension;
