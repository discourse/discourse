function FootnoteNodeView({
  pmView: { EditorView },
  pmState: { EditorState },
  pmTransform: { StepMap },
}) {
  return class {
    constructor(node, view, getPos) {
      this.node = node;
      this.outerView = view;
      this.getPos = getPos;

      this.dom = document.createElement("footnote");
      this.innerView = null;
    }

    selectNode() {
      this.dom.classList.add("ProseMirror-selectednode");
      if (!this.innerView) {
        this.open();
      }
    }

    deselectNode() {
      this.dom.classList.remove("ProseMirror-selectednode");
      if (this.innerView) {
        this.close();
      }
    }

    open() {
      // Append a tooltip to the outer node
      const tooltip = this.dom.appendChild(document.createElement("div"));
      tooltip.style.setProperty(
        "--footnote-counter",
        `"${getFootnoteCounterValue(this.dom)}"`
      );
      tooltip.className = "footnote-tooltip";

      // And put a sub-ProseMirror into that
      this.innerView = new EditorView(tooltip, {
        // You can use any node as an editor document
        state: EditorState.create({
          doc: this.node,
          plugins: this.outerView.state.plugins.filter(
            (plugin) =>
              !/^(placeholder|trailing-paragraph)\$.*/.test(plugin.key)
          ),
        }),
        // This is the magic part
        dispatchTransaction: this.dispatchInner.bind(this),
        handleDOMEvents: {
          mousedown: () => {
            // Kludge to prevent issues due to the fact that the whole
            // footnote is node-selected (and thus DOM-selected) when
            // the parent editor is focused.
            if (this.outerView.hasFocus()) {
              this.innerView.focus();
            }
          },
        },
      });
    }

    close() {
      this.innerView.destroy();
      this.innerView = null;
      this.dom.textContent = "";
    }

    dispatchInner(tr) {
      let { state, transactions } = this.innerView.state.applyTransaction(tr);
      this.innerView.updateState(state);

      if (!tr.getMeta("fromOutside")) {
        let outerTr = this.outerView.state.tr,
          offsetMap = StepMap.offset(this.getPos() + 1);
        for (let i = 0; i < transactions.length; i++) {
          let steps = transactions[i].steps;
          for (let j = 0; j < steps.length; j++) {
            outerTr.step(steps[j].map(offsetMap));
          }
        }
        if (outerTr.docChanged) {
          this.outerView.dispatch(outerTr);
        }
      }
    }

    update(node) {
      if (!node.sameMarkup(this.node)) {
        return false;
      }
      this.node = node;
      if (this.innerView) {
        let state = this.innerView.state;
        let start = node.content.findDiffStart(state.doc.content);
        if (start != null) {
          let { a: endA, b: endB } = node.content.findDiffEnd(
            state.doc.content
          );
          let overlap = start - Math.min(endA, endB);
          if (overlap > 0) {
            endA += overlap;
            endB += overlap;
          }
          this.innerView.dispatch(
            state.tr
              .replace(start, endB, node.slice(start, endA))
              .setMeta("fromOutside", true)
          );
        }
      }
      return true;
    }

    destroy() {
      if (this.innerView) {
        this.close();
      }
    }

    stopEvent(event) {
      return this.innerView && this.innerView.dom.contains(event.target);
    }

    ignoreMutation() {
      return true;
    }
  };
}

/** @type {RichEditorExtension} */
const extension = {
  nodeViews: {
    footnote: FootnoteNodeView,
  },
  nodeSpec: {
    footnote: {
      attrs: { id: {} },
      group: "inline",
      content: "block*",
      inline: true,
      atom: true,
      draggable: false,
      parseDOM: [{ tag: "footnote" }],
      toDOM: () => ["footnote", 0],
    },
  },
  parse({ pmModel: { Slice, Fragment } }) {
    return {
      footnote_ref: {
        node: "footnote",
        getAttrs: (token) => {
          return { id: token.meta.id };
        },
      },
      footnote_block: { ignore: true },
      footnote_open(state, token, tokens, i) {
        // footnote_open should be at the root level
        const doc = state.top();

        doc.content.forEach((node, pos) => {
          const replacements = [];
          node.descendants((child, childPos) => {
            const id = child.attrs.id;

            if (child.type.name !== "footnote" || id !== token.meta.id) {
              return;
            }

            let innerTokens = tokens.slice(i + 1, tokens.length - 1);
            const footnoteCloseIndex = innerTokens.findIndex(
              (t) => t.type === "footnote_close"
            );
            innerTokens = innerTokens.slice(0, footnoteCloseIndex);

            // remove the inner tokens + footnote_close from the tokens stream
            tokens.splice(i + 1, innerTokens.length + 1);

            // this is a trick to parse this subset of tokens having the footnote as parent
            state.stack = [];
            state.openNode(state.schema.nodes.footnote, { id });
            state.parseTokens(innerTokens);
            const footnote = state.closeNode();
            state.stack = [doc];
            // then we restore the stack as it was before

            const slice = new Slice(Fragment.from(footnote), 0, 0);
            replacements.push({ from: childPos, to: childPos + 2, slice });
          });

          for (const { from, to, slice } of replacements) {
            doc.content[pos] = doc.content[pos].replace(from, to, slice);
          }
        });
      },
      footnote_anchor: { ignore: true, noCloseToken: true },
    };
  },
  serializeNode: {
    footnote(state, node) {
      if (
        node.content.content.length === 1 &&
        node.content.firstChild.type.name === "paragraph"
      ) {
        state.write(`^[`);
        state.renderContent(node.content.firstChild);
        state.write(`]`);
      } else {
        state.footnoteCount ??= 0;
        state.footnoteCount++;
        state.write(`[^${state.footnoteCount}]`);
        state.footnoteMap ??= new Map();
        state.footnoteMap.set(state.footnoteCount, node.content);
      }
    },
    afterSerialize(state) {
      if (!state.footnoteMap) {
        return;
      }

      for (const [id, content] of state.footnoteMap) {
        const oldDelim = state.delim;
        state.write(`[^${id}]: `);
        state.delim += "    ";
        state.renderContent(content);
        state.delim = oldDelim;
      }
    },
  },
  inputRules: [
    {
      match: /\^\[(.*?)]$/,
      handler: (state, match, start, end) => {
        const footnote = state.schema.nodes.footnote.create(
          null,
          state.schema.nodes.paragraph.create(null, state.schema.text(match[1]))
        );
        return state.tr.replaceWith(start, end, footnote);
      },
    },
  ],
};

function getFootnoteCounterValue(footnoteElement) {
  // Find the parent .ProseMirror
  const proseMirror = footnoteElement.closest(".ProseMirror");
  if (!proseMirror) {
    return null;
  }

  // Get all <footnote> elements within the same .ProseMirror
  const footnotes = proseMirror.querySelectorAll("footnote");

  // Find the index of the target footnote (adding 1 since counter starts at 1)
  return Array.from(footnotes).indexOf(footnoteElement) + 1;
}

export default extension;
