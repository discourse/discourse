import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import { updatePosition } from "discourse/float-kit/lib/update-position";

const IDENTIFIER = "chat-selection-toolbar";
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
  #menuInstance;
  #showing = false;
  #generation = 0;
  #destroyed = false;

  #focusChanged = (event) => this.#checkFocus(event.target);

  #toolbarKeydown = (event) => {
    if (
      this.#menuInstance?.content?.contains(event.target) &&
      (event.key === "Escape" || event.key === "Tab")
    ) {
      event.preventDefault();
      event.stopPropagation();
      this.#view.focus();
      this.hide();
    }
  };

  constructor(view, { getContext, getToolbar }) {
    this.#view = view;
    this.#getContext = getContext;
    this.#getToolbar = getToolbar;
    view.dom.ownerDocument.addEventListener("focusin", this.#focusChanged);
    view.dom.ownerDocument.addEventListener(
      "keydown",
      this.#toolbarKeydown,
      true
    );
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
    this.#destroyed = true;
    this.#view.dom.ownerDocument.removeEventListener(
      "focusin",
      this.#focusChanged
    );
    this.#view.dom.ownerDocument.removeEventListener(
      "keydown",
      this.#toolbarKeydown,
      true
    );
    this.hide();
  }

  hide() {
    this.#generation++;
    this.#showing = false;
    this.#menuInstance?.destroy();
    this.#menuInstance = null;
  }

  blur(event) {
    if (event.relatedTarget) {
      this.#checkFocus(event.relatedTarget);
    } else {
      queueMicrotask(() => {
        if (!this.#destroyed) {
          this.#checkFocus(this.#view.dom.ownerDocument.activeElement);
        }
      });
    }
  }

  keydown(event) {
    if (
      event.key !== "Tab" ||
      event.shiftKey ||
      !this.#menuInstance?.expanded
    ) {
      return false;
    }
    const button = this.#menuInstance.content?.querySelector(
      'button[tabindex="0"]'
    );
    if (!button) {
      return false;
    }
    event.preventDefault();
    button.focus();
    return true;
  }

  #checkFocus(target) {
    if (
      !this.#view.dom.contains(target) &&
      !this.#menuInstance?.content?.contains(target)
    ) {
      this.hide();
    }
  }

  #shouldShow() {
    const { state } = this.#view;
    const { selection, schema } = state;

    // selected nodes, like images, float their own toolbars
    if (
      !this.#getToolbar() ||
      selection.empty ||
      selection.node ||
      (!this.#view.hasFocus() &&
        !this.#menuInstance?.content?.contains(
          this.#view.dom.ownerDocument.activeElement
        )) ||
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
      updatePosition(trigger, this.#menuInstance.content, MENU_OPTIONS);
      return;
    }

    if (this.#showing) {
      return;
    }

    this.#showing = true;
    const generation = ++this.#generation;
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
        if (generation === this.#generation && !this.#destroyed) {
          this.#menuInstance = instance;
        } else {
          instance?.destroy();
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
 * @param {() => import("discourse/lib/composer/toolbar").ToolbarBase | null} getToolbar
 *   returns null while the toolbar should stay hidden
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
            keydown(_view, event) {
              return toolbarView?.keydown(event) ?? false;
            },
            blur(_view, event) {
              toolbarView?.blur(event);
              return false;
            },
          },
        },
      });
    },
  };
}
