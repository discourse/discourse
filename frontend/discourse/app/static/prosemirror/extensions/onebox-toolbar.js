import { trackedObject } from "@ember/reactive/collections";
import { NodeSelection, TextSelection } from "prosemirror-state";
import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import { ToolbarBase } from "discourse/lib/composer/toolbar";
import { rovingButtonBar } from "discourse/lib/roving-button-bar";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

const MENU_PADDING = 8;

class OneboxToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    this.addButton({
      id: "onebox-copy",
      icon: "copy",
      title: "composer.onebox_toolbar.copy",
      className: "composer-onebox-toolbar__copy",
      action: opts.copyLink,
    });

    this.addButton({
      id: "onebox-remove-preview",
      icon: "compress",
      title: "composer.onebox_toolbar.remove_preview",
      className: "composer-onebox-toolbar__remove-preview",
      action: opts.removePreview,
    });

    this.addSeparator({});

    this.addButton({
      id: "onebox-visit",
      icon: "up-right-from-square",
      title: "composer.onebox_toolbar.visit",
      className: "composer-onebox-toolbar__visit",
      get href() {
        return opts.getUrl();
      },
    });
  }
}

class OneboxToolbarPluginView {
  #menuInstance;
  #menuType;
  #toolbarReplaced = false;
  #toolbar;
  #state;

  #view;
  #getContext;

  constructor({ getContext }) {
    this.#getContext = getContext;
  }

  update(view) {
    this.#view = view;
    const { selection } = view.state;

    if (!(selection instanceof NodeSelection)) {
      this.#resetToolbar();
      return;
    }

    const node = selection.node;
    if (node.type.name !== "onebox" && node.type.name !== "onebox_inline") {
      this.#resetToolbar();
      return;
    }

    this.#updateState(node, selection);
    this.#displayToolbar();
  }

  #resetToolbar() {
    this.#menuInstance?.destroy();
    this.#menuInstance = null;

    if (this.#toolbarReplaced) {
      this.#getContext().replaceToolbar(null, this.#toolbar);
      this.#toolbarReplaced = false;
    }
  }

  #updateState(node, selection) {
    const attrs = {
      url: node.attrs.url,
      type: node.type.name,
      from: selection.from,
      to: selection.to,
    };

    if (!this.#toolbar) {
      this.#state = trackedObject(attrs);

      this.#toolbar = new OneboxToolbar({
        copyLink: () => this.#copyLink(),
        removePreview: () => this.#removePreview(),
        getUrl: () => this.#state.url,
      });

      this.#toolbar.rovingButtonBar = this.#rovingButtonBar.bind(this);
    } else {
      Object.assign(this.#state, attrs);
    }
  }

  #rovingButtonBar(event) {
    if (event.key === "Tab") {
      event.preventDefault();
      this.#view.focus();
      return false;
    }
    return rovingButtonBar(event);
  }

  #displayToolbar() {
    if (this.#getContext().capabilities.viewport.sm) {
      this.#showFloatingToolbar();
    } else {
      this.#getContext().replaceToolbar(this.#toolbar);
      this.#toolbarReplaced = true;
    }
  }

  async #copyLink() {
    await clipboardCopy(this.#state.url);
    this.#getContext().toasts.success({
      duration: "short",
      data: {
        message: i18n("composer.onebox_toolbar.link_copied"),
      },
    });
  }

  #removePreview() {
    const { state, dispatch } = this.#view;
    const { selection } = state;
    const node = selection.node;
    const url = node.attrs.url;
    const href = /^https?:\/\//.test(url) ? url : `https://${url}`;
    const isBlock = node.type.name === "onebox";

    const linkMark = state.schema.marks.link.create({
      href,
      markup: "autolink",
    });
    const textNode = state.schema.text(href, [linkMark]);

    const content = isBlock
      ? state.schema.nodes.paragraph.create(null, textNode)
      : textNode;
    const tr = state.tr.replaceWith(selection.from, selection.to, content);

    // Place cursor at end of the new text
    const cursorPos = isBlock
      ? selection.from + 1 + href.length
      : selection.from + href.length;
    tr.setSelection(
      TextSelection.create(tr.doc, Math.min(cursorPos, tr.doc.content.size))
    );

    dispatch(tr);
    this.#view.focus();
  }

  #getNodeDOM() {
    const { from } = this.#state;

    // nodeDOM works for inline nodes, domAtPos for block nodes
    const nodeDOM = this.#view.nodeDOM(from);
    if (nodeDOM) {
      return nodeDOM;
    }

    const { node, offset } = this.#view.domAtPos(from);
    if (node.nodeType === Node.ELEMENT_NODE) {
      return node.childNodes[offset];
    }
    return node.parentElement;
  }

  #showFloatingToolbar() {
    const trigger = this.#getNodeDOM();
    if (!trigger) {
      return;
    }

    const type = this.#state.type;

    // Reuse existing menu if same type
    if (this.#menuInstance?.expanded && this.#menuType === type) {
      this.#menuInstance.trigger = trigger;
      return;
    }

    // Destroy and recreate when switching between block/inline
    this.#menuInstance?.destroy();
    this.#menuInstance = null;
    this.#menuType = type;

    if (type === "onebox") {
      this.#showBlockToolbar(trigger);
    } else {
      this.#showInlineToolbar(trigger);
    }
  }

  // Image-style positioning, portaled into the onebox element, top-right
  async #showBlockToolbar(trigger) {
    this.#menuInstance = await this.#getContext().menu.newInstance(trigger, {
      identifier: "composer-onebox-toolbar",
      component: ToolbarButtons,
      placement: "top-end",
      fallbackPlacements: ["top-end"],
      padding: MENU_PADDING,
      data: this.#toolbar,
      portalOutletElement: trigger,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      trapTab: false,
      offset({ rects }) {
        return {
          mainAxis: -MENU_PADDING - rects.floating.height,
          crossAxis: -MENU_PADDING,
        };
      },
    });

    await this.#menuInstance.show();
  }

  // Link-toolbar-style: anchored below the inline onebox element
  #showInlineToolbar(trigger) {
    this.#getContext()
      .menu.show(trigger, {
        portalOutletElement: this.#view.dom.parentElement,
        identifier: "composer-onebox-toolbar",
        component: ToolbarButtons,
        placement: "bottom",
        padding: 0,
        hide: true,
        boundary: this.#view.dom.parentElement,
        fallbackPlacements: [
          "bottom-end",
          "bottom-start",
          "top",
          "top-end",
          "top-start",
        ],
        closeOnClickOutside: false,
        onClose: () => this.#view.focus(),
        data: this.#toolbar,
      })
      .then((instance) => {
        this.#menuInstance = instance;
      });
  }

  destroy() {
    this.#menuInstance?.destroy();
    this.#menuInstance = null;
    this.#toolbar = null;
  }
}

/** @type {RichEditorExtension} */
const extension = {
  plugins: ({ pmState: { Plugin }, getContext }) => {
    return new Plugin({
      props: {
        handleKeyDown(view, event) {
          if (event.key !== "Tab" || event.shiftKey) {
            return false;
          }

          const { selection } = view.state;
          if (!(selection instanceof NodeSelection)) {
            return false;
          }

          const node = selection.node;
          if (
            node.type.name !== "onebox" &&
            node.type.name !== "onebox_inline"
          ) {
            return false;
          }

          const activeMenu = document.querySelector(
            '[data-identifier="composer-onebox-toolbar"]'
          );
          if (!activeMenu) {
            return false;
          }

          event.preventDefault();

          const focusable = activeMenu.querySelector(
            'button, a, [tabindex]:not([tabindex="-1"]), .select-kit'
          );

          if (focusable) {
            focusable.focus();
            return true;
          }

          return false;
        },
      },

      view() {
        return new OneboxToolbarPluginView({ getContext });
      },
    });
  },
};

export default extension;
