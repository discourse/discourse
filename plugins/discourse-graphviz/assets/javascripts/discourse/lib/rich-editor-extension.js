import PreviewNodeView from "discourse/components/composer/preview-node-view";
import {
  previewSourceNode,
  selectPreviewSource,
} from "discourse/lib/composer/preview-block";
import GraphvizFullscreen from "../components/graphviz-fullscreen";
import GraphvizPreview from "../components/graphviz-preview";

const LANGUAGE = "dot";

// kept in step with the engines the markdown rule accepts
const ENGINES = ["dot", "neato", "circo", "fdp", "osage", "twopi"];

const toEngine = (engine) => (ENGINES.includes(engine) ? engine : "dot");

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  nodeSpec: {
    graphviz: {
      attrs: { engine: { default: "dot" } },
      group: "block",
      content: "preview_source",
      atom: true,
      defining: true,
      isolating: true,
      createGapCursor: true,
      parseDOM: [
        {
          tag: "div.graphviz",
          getAttrs: (dom) => ({ engine: toEngine(dom.dataset.engine) }),
          // cooked source is plain text the parser would otherwise collapse
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
        engine: token.attrGet("data-engine"),
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
