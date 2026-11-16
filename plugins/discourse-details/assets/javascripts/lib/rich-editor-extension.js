/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    details: {
      attrs: { open: { default: true }, ai: { default: false } },
      content: "summary block+",
      group: "block",
      selectable: true,
      defining: true,
      isolating: true,
      parseDOM: [
        {
          tag: "details",
          getAttrs: (dom) => ({ ai: dom.classList.contains("ai-quote") }),
        },
      ],
      toDOM: (node) => [
        "details",
        {
          open: node.attrs.open || undefined,
          class: node.attrs.ai ? "ai-quote" : undefined,
        },
        0,
      ],
    },
    summary: {
      content: "inline*",
      parseDOM: [
        {
          tag: "details.ai-quote > summary",
          contentElement: (dom) =>
            dom.querySelector(":scope > .ai-details-label") &&
            dom.firstElementChild?.matches("span")
              ? dom.firstElementChild
              : dom,
        },
        { tag: "summary" },
      ],
      toDOM: () => ["summary", 0],
    },
  },
  parse: {
    bbcode_open(state, token) {
      if (token.tag === "details") {
        state.openNode(state.schema.nodes.details, {
          ai: token.attrGet("class") === "ai-quote",
        });
        return true;
      }

      if (token.tag === "summary") {
        state.openNode(state.schema.nodes.summary);
        return true;
      }
    },
    bbcode_close(state, token) {
      if (token.tag === "details" || token.tag === "summary") {
        state.closeNode();
        return true;
      }
    },
  },
  serializeNode: {
    details(state, node) {
      state.renderContent(node);
      state.write("[/details]\n\n");
    },
    summary(state, node, details) {
      if (node.content.childCount > 0) {
        state.write('[details="');
        node.content.forEach(
          (child) =>
            child.text &&
            state.text(child.text.replace(/"/g, "“"), state.inAutolink)
        );
        state.write('"');
      } else {
        state.write("[details");
      }
      if (details.attrs?.ai) {
        state.write(" ai=true");
      }
      state.write("]\n");
    },
  },
  plugins: {
    props: {
      handleClickOn(view, pos, node, nodePos) {
        // if the click position in the document is not the first within the summary node
        if (pos > nodePos + 1 || node.type.name !== "summary") {
          return false;
        }

        const details = view.state.doc.nodeAt(nodePos - 1);
        view.dispatch(
          view.state.tr.setNodeMarkup(nodePos - 1, null, {
            ...details.attrs,
            open: !details.attrs.open,
          })
        );
        return true;
      },
    },
  },
};

export default extension;
