import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import { updatePosition } from "discourse/float-kit/lib/update-position";

const IDENTIFIER = "composer-selection-toolbar";
const MENU_OPTIONS = {
  placement: "top",
  fallbackPlacements: ["bottom"],
  padding: 0,
  offset: 6,
};

class SelectionToolbarView {
  #view;
  #getContext;
  #getToolbar;
  #utils;
  #menuInstance;
  #showing = false;

  constructor(view, { getContext, getToolbar, utils }) {
    this.#view = view;
    this.#getContext = getContext;
    this.#getToolbar = getToolbar;
    this.#utils = utils;
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
      !this.#getToolbar() ||
      selection.empty ||
      !this.#view.hasFocus() ||
      !selection.$from.parent.inlineContent ||
      selection.$from.parent.type.spec.code
    ) {
      return false;
    }

    // the link toolbar floats over links, judged from the same position
    return !this.#utils.getMarkRange(selection.$head, schema.marks.link);
  }

  #show() {
    const trigger = { getBoundingClientRect: () => this.#selectionRect() };

    if (this.#menuInstance?.expanded) {
      this.#menuInstance.trigger = trigger;
      updatePosition(trigger, this.#menuInstance.content, MENU_OPTIONS);
      return;
    }

    // another menu with this identifier may have closed ours
    if (this.#showing && !this.#menuInstance) {
      return;
    }
    this.#menuInstance = null;

    this.#showing = true;
    this.#getContext()
      .menu.show(trigger, {
        identifier: IDENTIFIER,
        component: ToolbarButtons,
        data: this.#getToolbar(),
        ...MENU_OPTIONS,
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
 * A rich editor extension that floats a toolbar over a non-empty text
 * selection, outside code and links. Not registered by default: editors opt
 * in by passing it with their extensions.
 *
 * @param {() => import("discourse/lib/composer/toolbar").ToolbarBase | null} getToolbar
 *   returns null while the toolbar should stay hidden
 * @returns {RichEditorExtension}
 */
export default function selectionToolbarExtension(getToolbar) {
  return {
    plugins({ pmState: { Plugin }, getContext, utils }) {
      let toolbarView;

      return new Plugin({
        view(view) {
          toolbarView = new SelectionToolbarView(view, {
            getContext,
            getToolbar,
            utils,
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
