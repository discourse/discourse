import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import { updatePosition } from "discourse/float-kit/lib/update-position";

const IDENTIFIER = "chat-selection-toolbar";

class SelectionToolbarView {
  #view;
  #getContext;
  #getToolbar;
  #menuInstance;
  #showing = false;

  constructor(view, { getContext, getToolbar }) {
    this.#view = view;
    this.#getContext = getContext;
    this.#getToolbar = getToolbar;
  }

  update(view) {
    this.#view = view;

    if (this.#shouldShow()) {
      this.#show();
    } else {
      this.hide();
    }
  }

  destroy() {
    this.hide();
  }

  hide() {
    this.#showing = false;
    this.#menuInstance?.destroy();
    this.#menuInstance = null;
  }

  #shouldShow() {
    const { state } = this.#view;
    const { selection, schema } = state;

    if (
      selection.empty ||
      !this.#view.hasFocus() ||
      !selection.$from.parent.inlineContent ||
      selection.$from.parent.type.spec.code
    ) {
      return false;
    }

    // the link toolbar already floats over links
    return !selection.$head
      .marks()
      .some((mark) => mark.type === schema.marks.link);
  }

  #show() {
    const trigger = { getBoundingClientRect: () => this.#selectionRect() };

    if (this.#menuInstance?.expanded) {
      this.#menuInstance.trigger = trigger;
      updatePosition(trigger, this.#menuInstance.content, {});
      return;
    }

    if (this.#showing) {
      return;
    }

    this.#showing = true;
    this.#getContext()
      .menu.show(trigger, {
        identifier: IDENTIFIER,
        component: ToolbarButtons,
        data: this.#getToolbar(),
        placement: "top",
        fallbackPlacements: ["bottom"],
        padding: 0,
        offset: 6,
        closeOnClickOutside: false,
        closeOnEscape: false,
      })
      .then((instance) => {
        if (this.#showing) {
          this.#menuInstance = instance;
        } else {
          instance.destroy();
        }
      });
  }

  #selectionRect() {
    const { from, to } = this.#view.state.selection;
    const start = this.#view.coordsAtPos(from);
    const end = this.#view.coordsAtPos(to);
    const left = Math.min(start.left, end.left);

    return {
      left,
      top: Math.min(start.top, end.top),
      width: Math.max(start.right, end.right) - left,
      height: Math.max(start.bottom, end.bottom) - Math.min(start.top, end.top),
    };
  }
}

/**
 * Floats formatting buttons over a text selection, for desktop pointers.
 *
 * @param {() => import("discourse/lib/composer/toolbar").ToolbarBase} getToolbar
 * @returns {RichEditorExtension}
 */
export default function richEditorSelectionToolbar(getToolbar) {
  return {
    plugins({ pmState: { Plugin }, getContext }) {
      let toolbarView;

      return new Plugin({
        view(view) {
          toolbarView = new SelectionToolbarView(view, {
            getContext,
            getToolbar,
          });
          return toolbarView;
        },
        props: {
          handleDOMEvents: {
            blur() {
              toolbarView?.hide();
              return false;
            },
          },
        },
      });
    },
  };
}
