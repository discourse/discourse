import UploadPlaceholderNodeView from "../components/upload-placeholder-node-view";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    upload_placeholder: {
      inline: true,
      atom: true,
      selectable: true,
      draggable: true,
      group: "inline",
      attrs: {
        fileId: { default: null },
        filename: { default: "" },
      },
      toDOM(node) {
        return [
          "span",
          {
            class: "upload-placeholder --file",
            "data-upload-id": node.attrs.fileId,
          },
          node.attrs.filename,
        ];
      },
      parseDOM: [],
    },
  },

  nodeViews: {
    upload_placeholder: {
      component: UploadPlaceholderNodeView,
    },
  },

  serializeNode: {
    upload_placeholder() {},
  },

  plugins({ pmState: { Plugin, PluginKey }, getContext }) {
    function collectPlaceholderIds(doc) {
      const ids = new Set();
      doc.descendants((node) => {
        if (node.type.name === "upload_placeholder") {
          ids.add(node.attrs.fileId);
        } else if (node.type.name === "image" && node.attrs.placeholder) {
          ids.add(node.attrs.title);
        }
      });
      return ids;
    }

    return new Plugin({
      key: new PluginKey("uploadPlaceholder"),

      appendTransaction(transactions, oldState, newState) {
        const isUserAction = transactions.some(
          (tr) => tr.docChanged && tr.getMeta("addToHistory") !== false
        );
        if (!isUserAction) {
          return;
        }

        const oldIds = collectPlaceholderIds(oldState.doc);
        if (oldIds.size === 0) {
          return;
        }

        const newIds = collectPlaceholderIds(newState.doc);
        for (const id of oldIds) {
          if (!newIds.has(id)) {
            getContext().appEvents.trigger("composer:cancel-upload", {
              fileId: id,
            });
          }
        }

        // Remove duplicated placeholders (e.g. from Option+drag)
        const seen = new Set();
        const dupes = [];
        newState.doc.descendants((node, pos) => {
          const id =
            node.type.name === "upload_placeholder"
              ? node.attrs.fileId
              : node.type.name === "image" && node.attrs.placeholder
                ? node.attrs.title
                : null;
          if (id) {
            if (seen.has(id)) {
              dupes.push({ pos, size: node.nodeSize });
            } else {
              seen.add(id);
            }
          }
        });

        if (dupes.length) {
          const tr = newState.tr;
          for (const { pos, size } of dupes.reverse()) {
            tr.delete(pos, pos + size);
          }
          return tr.setMeta("addToHistory", false);
        }
      },
    });
  },
};

export default extension;
