import { i18n } from "discourse-i18n";

function createSummaryNodeView() {
  return (_node, view, getPos) => {
    const pos = getPos();
    if (pos == null || !view.state.doc.resolve(pos).parent.attrs.ai) {
      return null;
    }

    const dom = document.createElement("summary");
    const contentDOM = document.createElement("span");
    const badge = document.createElement("span");
    badge.className = "ai-badge";
    badge.dataset.aiLabel = i18n("post.ai_generated");
    badge.title = i18n("post.ai_generated_title");
    badge.contentEditable = false;
    dom.append(contentDOM, badge);
    return { dom, contentDOM };
  };
}

/** @type {RichEditorExtension} */
const extension = {
  nodeViews: { summary: createSummaryNodeView },

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
            dom.querySelector(
              ":scope > .ai-badge, :scope > .ai-details-label"
            ) && dom.firstElementChild?.matches("span")
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
        state.write(" ai");
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
