import { i18n } from "discourse-i18n";
import UploadPlaceholderNodeView from "../components/upload-placeholder-node-view";

const imageUploadProgress = new Map();

export function updateImageUploadProgress(fileId, percentage) {
  if (percentage === null) {
    imageUploadProgress.delete(fileId);
  } else {
    imageUploadProgress.set(fileId, percentage);
  }
}

export function clearAllImageUploadProgress() {
  imageUploadProgress.clear();
}

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
            class: "upload-placeholder-file",
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

  plugins({
    pmState: { Plugin, PluginKey },
    pmView: { Decoration, DecorationSet },
    getContext,
  }) {
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

      props: {
        decorations(state) {
          const decos = [];

          state.doc.descendants((node, pos) => {
            if (node.type.name === "image" && node.attrs.placeholder) {
              const fileId = node.attrs.title;

              const overlay = document.createElement("span");
              overlay.className = "upload-placeholder-image__overlay";
              overlay.dataset.uploadId = fileId;

              const progress = document.createElement("span");
              progress.className = "upload-placeholder__progress";
              progress.textContent = `${imageUploadProgress.get(fileId) ?? 0}%`;
              overlay.appendChild(progress);

              const cancel = document.createElement("span");
              cancel.className = "upload-placeholder__cancel";
              cancel.textContent = "\u00D7";
              cancel.title = i18n("cancel");
              cancel.addEventListener("click", (e) => {
                e.preventDefault();
                e.stopPropagation();
                getContext().appEvents.trigger("composer:cancel-upload", {
                  fileId,
                });
              });
              overlay.appendChild(cancel);

              decos.push(
                Decoration.widget(pos + node.nodeSize, overlay, {
                  key: `img-overlay-${fileId}`,
                  side: -1,
                })
              );
            }
          });

          if (decos.length === 0) {
            return DecorationSet.empty;
          }

          return DecorationSet.create(state.doc, decos);
        },
      },
    });
  },
};

export default extension;
