import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { TextSelection } from "prosemirror-state";
import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import InsertHyperlink from "discourse/components/modal/insert-hyperlink";
import { ToolbarBase } from "discourse/lib/composer/toolbar";
import { rovingButtonBar } from "discourse/lib/roving-button-bar";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import { updatePosition } from "float-kit/lib/update-position";

const AUTO_LINKS = ["autolink", "linkify"];
const MENU_OFFSET = 12;
const STRIP_PROTOCOLS = /^(mailto:|https:\/\/)/;

class LinkToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    this.addButton({
      id: "link-edit",
      icon: "pen",
      title: "composer.link_toolbar.edit",
      className: "composer-link-toolbar__edit",
      preventFocus: true,
      action: opts.editLink,
    });

    this.addButton({
      id: "link-copy",
      icon: "copy",
      title: "composer.link_toolbar.copy",
      className: "composer-link-toolbar__copy",
      preventFocus: true,
      action: opts.copyLink,
    });

    this.addButton({
      id: "link-unlink",
      icon: "link-slash",
      title: "composer.link_toolbar.remove",
      className: "composer-link-toolbar__unlink",
      preventFocus: true,
      condition: opts.canUnlink,
      action: opts.unlinkText,
    });

    this.addSeparator({
      condition: () => opts.canVisit() || opts.canUnlink(),
    });

    this.addButton({
      id: "link-visit",
      get icon() {
        return opts.canVisit() ? "up-right-from-square" : null;
      },
      title: "composer.link_toolbar.visit",
      className: "composer-link-toolbar__visit",
      preventFocus: true,
      condition: () => opts.canVisit() || opts.canUnlink(),
      get href() {
        return opts.canVisit() ? opts.getHref() : null;
      },
      get translatedLabel() {
        if (opts.canUnlink()) {
          const label = opts.getHref();

          // strip base url from label
          const origin = window.location.origin;
          if (label.startsWith(origin)) {
            return label.replace(origin, "");
          }

          // strip protocol from label if mailto or https
          return label.replace(STRIP_PROTOCOLS, "");
        }
      },
      get disabled() {
        return !opts.canVisit();
      },
    });
  }
}

class LinkToolbarPluginView {
  #menuInstance;
  #toolbarReplaced = false;
  #linkToolbar;
  #linkState;

  #view;

  #utils;
  #getContext;

  constructor({ utils, getContext }) {
    this.#utils = utils;
    this.#getContext = getContext;
  }

  /**
   * ProseMirror view update handler
   *
   * @param {import("prosemirror-view").EditorView} view
   */
  update(view) {
    this.#view = view;

    const markRange = this.#utils.getMarkRange(
      view.state.selection.$head,
      view.state.schema.marks.link
    );

    if (!markRange) {
      this.#resetToolbar();
      return;
    }

    this.#updateLinkState(markRange);
    this.#displayToolbar();
  }

  #resetToolbar() {
    this.#menuInstance?.destroy();
    this.#menuInstance = null;

    if (this.#toolbarReplaced) {
      this.#getContext().replaceToolbar(null);
      this.#toolbarReplaced = false;
    }
  }

  #updateLinkState(markRange) {
    const attrs = {
      ...markRange.mark.attrs,
      range: markRange,
      head: this.#view.state.selection.head,
    };

    if (!this.#linkToolbar) {
      this.#linkState = new TrackedObject(attrs);

      this.#linkToolbar = new LinkToolbar({
        editLink: () => this.#openLinkEditor(),
        copyLink: () => this.#copyLink(),
        unlinkText: () => this.#unlinkText(),
        canVisit: () => this.#canVisit(),
        getHref: () => this.#linkState.href,
        canUnlink: () => this.#canUnlink(),
      });

      this.#linkToolbar.rovingButtonBar = this.#rovingButtonBar.bind(this);
    } else {
      Object.assign(this.#linkState, attrs);
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
      this.#getContext().replaceToolbar(this.#linkToolbar);
      this.#toolbarReplaced = true;
    }
  }

  #openLinkEditor() {
    const { range } = this.#linkState;
    const tempTr = this.#view.state.tr.removeMark(
      range.from,
      range.to,
      this.#view.state.schema.marks.link
    );

    const currentLinkText = this.#utils.convertToMarkdown(
      this.#view.state.schema.topNodeType.create(
        null,
        this.#view.state.schema.nodes.paragraph.create(
          null,
          tempTr.doc.slice(range.from, range.to).content
        )
      )
    );

    this.#getContext().modal.show(InsertHyperlink, {
      model: {
        editing: true,
        linkText: currentLinkText,
        linkUrl: this.#linkState.href,
        toolbarEvent: {
          addText: (text) => this.#replaceText(text),
          selected: { value: this.#linkState.href },
        },
      },
    });
  }

  #replaceText(text) {
    const { content } = this.#utils.convertFromMarkdown(text);
    const { range } = this.#linkState;

    if (content.firstChild?.content.size > 0) {
      const { state, dispatch } = this.#view;
      const tr = state.tr.replaceWith(
        range.from,
        range.to,
        content.firstChild.content
      );

      const newPos = Math.min(
        this.#view.state.selection.from,
        range.from + content.firstChild.content.size
      );
      const resolvedPos = tr.doc.resolve(newPos);
      tr.setSelection(new TextSelection(resolvedPos, resolvedPos));
      dispatch(tr);
      this.#view.focus();
    }
  }

  async #copyLink() {
    await clipboardCopy(this.#linkState.href);
    this.#getContext().toasts.success({
      duration: "short",
      data: {
        message: i18n("composer.link_toolbar.link_copied"),
      },
    });
  }

  #unlinkText() {
    const range = this.#view.state.selection.empty
      ? this.#linkState.range
      : this.#view.state.selection;

    if (range) {
      const { state, dispatch } = this.#view;
      dispatch(
        state.tr.removeMark(range.from, range.to, state.schema.marks.link)
      );
      this.#view.focus();
    }
  }

  #canVisit() {
    return !!this.#utils.getLinkify().matchAtStart(this.#linkState.href);
  }

  #canUnlink() {
    return !AUTO_LINKS.includes(this.#linkState.markup);
  }

  #showFloatingToolbar() {
    const element = this.#view.domAtPos(this.#linkState.head).node;
    const trigger =
      element.nodeType === Node.TEXT_NODE ? element.parentElement : element;

    trigger.getBoundingClientRect = () => this.#getTriggerClientRect();

    if (this.#menuInstance?.expanded) {
      this.#menuInstance.trigger = trigger;
      updatePosition(
        this.#menuInstance.trigger,
        this.#menuInstance.content,
        {}
      );
      return;
    }

    this.#menuInstance?.destroy();
    this.#getContext()
      .menu.show(trigger, {
        portalOutletElement: this.#view.dom.parentElement,
        identifier: "composer-link-toolbar",
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
        data: this.#linkToolbar,
      })
      .then((instance) => {
        this.#menuInstance = instance;
      });
  }

  #getTriggerClientRect() {
    const { docView } = this.#view;
    const { head } = this.#linkState;
    const { doc } = this.#view.state;

    if (!docView || head > doc.content.size) {
      return { left: 0, top: 0, width: 0, height: 0 };
    }

    const { left, top } = this.#view.coordsAtPos(head);
    return { left, top: top + MENU_OFFSET, width: 0, height: 0 };
  }

  /**
   * ProseMirror view destroy handler
   */
  destroy() {
    this.#menuInstance?.destroy();
    this.#menuInstance = null;
    this.#linkToolbar = null;
  }
}

/** @type {RichEditorExtension} */
const extension = {
  plugins: ({ pmState: { Plugin }, utils, getContext }) => {
    return new Plugin({
      props: {
        handleKeyDown(view, event) {
          if (event.key !== "Tab" || event.shiftKey) {
            return false;
          }

          const range = utils.getMarkRange(
            view.state.selection.$head,
            view.state.schema.marks.link
          );
          if (!range) {
            return false;
          }

          const activeMenu = document.querySelector(
            '[data-identifier="composer-link-toolbar"]'
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
        return new LinkToolbarPluginView({
          utils,
          getContext,
        });
      },
    });
  },
};

export default extension;
