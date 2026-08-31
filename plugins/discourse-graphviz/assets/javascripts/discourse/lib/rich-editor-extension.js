import PreviewNodeView from "discourse/components/composer/preview-node-view";
import {
  previewSourceNode,
  selectPreviewSource,
} from "discourse/lib/composer/preview-block";
import GraphvizFullscreen from "../components/graphviz-fullscreen";
import GraphvizPreview from "../components/graphviz-preview";

// highlight.js calls the DOT language "dot"; sites whose highlighted_languages
// exclude it simply get an unhighlighted code block
const LANGUAGE = "dot";

// kept in step with the engines the markdown rule accepts, so a diagram parsed
// from pasted HTML cannot serialize an engine the bbcode tag would not survive
const ENGINES = ["dot", "neato", "circo", "fdp", "osage", "twopi"];

const toEngine = (engine) => (ENGINES.includes(engine) ? engine : "dot");

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  nodeSpec: {
    graphviz: {
      attrs: { engine: { default: "dot" } },
      group: "block",
      content: "preview_source",
      // the node view owns the source, so the editor moves over the block as a
      // unit rather than stepping into text it is not showing
      atom: true,
      defining: true,
      // keeps the text around it from merging into the source
      isolating: true,
      selectable: true,
      createGapCursor: true,
      parseDOM: [
        {
          tag: "div.graphviz",
          getAttrs: (dom) => ({ engine: toEngine(dom.dataset.engine) }),
          // a cooked diagram holds its source as plain text, which the parser
          // would otherwise collapse, running the statements together
          getContent: (dom, schema) =>
            schema.nodes.graphviz.create(
              null,
              previewSourceNode(schema, dom.textContent, LANGUAGE)
            ).content,
        },
      ],
      toDOM: (node) => [
        "div",
        { class: "graphviz", "data-engine": node.attrs.engine },
        0,
      ],
      previewControls: [
        {
          id: "graphviz-fullscreen",
          icon: "discourse-expand",
          title: "graphviz.fullscreen",
          className: "composer-preview-toolbar__graphviz-fullscreen",
          action: ({ node, context }) =>
            context.modal.show(GraphvizFullscreen, {
              model: { src: node.textContent, engine: node.attrs.engine },
            }),
        },
      ],
    },
  },

  nodeViews: {
    graphviz: {
      component: PreviewNodeView,
      hasContent: true,
      options: { preview: GraphvizPreview },
    },
  },

  parse: {
    graphviz: (state, token) => {
      state.openNode(state.schema.nodes.graphviz, {
        engine: toEngine(token.attrGet("data-engine")),
      });
      state.openNode(state.schema.nodes.preview_source, { params: LANGUAGE });
      state.addText(token.content.trim());
      state.closeNode();
      state.closeNode();

      return true;
    },
  },

  inputRules: ({ schema, pmState: { TextSelection } }) => ({
    match: /\[graphviz(?: engine=(\w+))?]$/,
    handler: (state, match, start, end) => {
      const graphviz = schema.nodes.graphviz.create(
        { engine: toEngine(match[1]) },
        previewSourceNode(schema, "", LANGUAGE)
      );
      const isAtStart = state.doc.resolve(start).parentOffset === 0;
      const from = isAtStart ? start - 1 : start;

      return selectPreviewSource(
        state.tr.replaceWith(from, end, graphviz),
        TextSelection,
        from
      );
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
