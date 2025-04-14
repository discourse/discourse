function createFootnoteNodeView({
  pmView: { EditorView },
  pmState: { EditorState },
  pmTransform: { StepMap },
}) {
  // from https://prosemirror.net/examples/footnote/
  return class FootnoteNodeView {
    constructor(node, view, getPos) {
      this.node = node;
      this.outerView = view;
      this.getPos = getPos;

      this.dom = document.createElement("div");
      this.dom.className = "footnote";
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
      const tooltip = this.dom.appendChild(document.createElement("div"));
      tooltip.style.setProperty(
        "--footnote-counter",
        `"${this.#getFootnoteCounterValue()}"`
      );
      tooltip.className = "footnote-tooltip";

      this.innerView = new EditorView(tooltip, {
        state: EditorState.create({
          doc: this.node,
          plugins: this.outerView.state.plugins.filter(
            (plugin) =>
              !/^(placeholder|trailing-paragraph)\$.*/.test(plugin.key)
          ),
        }),
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

    #getFootnoteCounterValue() {
      const footnotes = this.dom
        .closest(".ProseMirror")
        ?.querySelectorAll(".footnote");

      return Array.from(footnotes).indexOf(this.dom) + 1;
    }

    close() {
      this.innerView.destroy();
      this.innerView = null;
      this.dom.textContent = "";
    }

    dispatchInner(tr) {
      const { state, transactions } = this.innerView.state.applyTransaction(tr);
      this.innerView.updateState(state);

      if (!tr.getMeta("fromOutside")) {
        const outerTr = this.outerView.state.tr,
          offsetMap = StepMap.offset(this.getPos() + 1);
        for (let i = 0; i < transactions.length; i++) {
          const steps = transactions[i].steps;
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
        const state = this.innerView.state;
        const start = node.content.findDiffStart(state.doc.content);
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
  nodeViews: { footnote: createFootnoteNodeView },
  nodeSpec: {
    footnote: {
      attrs: { id: {} },
      group: "inline",
      content: "block*",
      inline: true,
      atom: true,
      draggable: false,
      parseDOM: [{ tag: "div.footnote" }],
      toDOM: () => ["div", { class: "footnote" }, 0],
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

        const id = token.meta.id;
        let innerTokens = tokens.slice(i + 1, tokens.length - 1);
        const footnoteCloseIndex = innerTokens.findIndex(
          (t) => t.type === "footnote_close"
        );
        innerTokens = innerTokens.slice(0, footnoteCloseIndex);

        doc.content.forEach((node, pos) => {
          const replacements = [];
          node.descendants((child, childPos) => {
            if (child.type.name !== "footnote" || child.attrs.id !== id) {
              return;
            }

            // this is a trick to parse this subset of tokens having the footnote as parent
            state.stack = [];
            state.openNode(state.schema.nodes.footnote);
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

        // remove the inner tokens + footnote_close from the tokens stream
        tokens.splice(i + 1, innerTokens.length + 1);
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
        const contents = (state.footnoteContents ??= []);
        contents.push(node.content);
        state.write(`[^${contents.length}]`);
      }
    },
    afterSerialize(state) {
      const contents = state.footnoteContents;

      if (!contents) {
        return;
      }

      for (let i = 0; i < contents.length; i++) {
        const oldDelim = state.delim;
        state.write(`[^${i + 1}]: `);
        state.delim += "    ";
        state.renderContent(contents[i]);
        state.delim = oldDelim;
      }
    },
  },
  inputRules: [
    {
      match: /\^\[(.*?)]$/,
      handler: (state, match, start, end) => {
        const content = state.doc.slice(start + 2, end).content;
        const paragraph = state.schema.nodes.paragraph.create(null, content);
        const footnote = state.schema.nodes.footnote.create(null, paragraph);

        return state.tr.replaceWith(start, end, footnote);
      },
    },
  ],
};

export default extension;
