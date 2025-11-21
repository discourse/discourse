import { Fragment, Slice } from "prosemirror-model";
import { NodeSelection, Plugin } from "prosemirror-state";

// A 1px transparent image to use as drag image
// This prevents the default drag image from appearing, the image gets in the way and make it harder
// to see where it'll land.
// In the future a better solution will be to use the image but less opaque and smaller.
const EMPTY_DRAG_IMG = new Image();
EMPTY_DRAG_IMG.src =
  "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";

/**
 * Overrides the default drag image with an empty image, giving room for the drop cursor.
 *
 * @type {RichEditorExtension}
 *
 **/

const dropSelectionPlugin = new Plugin({
  appendTransaction(transactions, oldState, newState) {
    // Check if any transaction has the drop UI event
    const hasDropEvent = transactions.some(
      (tr) => tr.getMeta("uiEvent") === "drop"
    );

    if (!hasDropEvent) {
      return null;
    }

    // Check if current selection is a paragraph containing exactly one image
    const { selection } = newState;
    if (
      selection instanceof NodeSelection &&
      selection.node.type.name === "paragraph" &&
      selection.node.childCount === 1 &&
      selection.node.firstChild.type.name === "image"
    ) {
      // Select the image inside the paragraph instead
      const imagePos = selection.from + 1; // paragraph boundary + image position
      return newState.tr.setSelection(
        NodeSelection.create(newState.doc, imagePos)
      );
    }
    return null;
  },
});

const extension = {
  plugins: [
    dropSelectionPlugin,
    {
      props: {
        handleDOMEvents: {
          dragover(view) {
            if (!view.dragging) {
              return false;
            }

            const dragging = view.dragging.slice.content.firstChild;
            if (dragging.type.name === "image") {
              const wrappedNode = view.state.schema.nodes.paragraph.create(
                null,
                dragging
              );
              view.dragging.slice = new Slice(Fragment.from(wrappedNode), 0, 0);
            }
            return false;
          },
          dragstart(view, event) {
            event.dataTransfer.setDragImage(EMPTY_DRAG_IMG, 0, 0);
            return false;
          },
        },
      },
    },
  ],
};

export default extension;
