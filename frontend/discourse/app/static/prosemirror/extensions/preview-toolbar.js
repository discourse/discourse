import { NodeSelection } from "prosemirror-state";
import {
  previewNodeViewFor,
  TOOLBAR_IDENTIFIER,
} from "discourse/components/composer/preview-node-view";
import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import { ToolbarBase } from "discourse/lib/composer/toolbar";
import { rovingButtonBar } from "discourse/lib/roving-button-bar";
import { codeBlockPreviewComponent } from "./code-block";

const MENU_PADDING = 8;

function isPreviewBlock(node, schema) {
  const previewSource = schema.nodes.preview_source;

  return (
    (!!previewSource && node.firstChild?.type === previewSource) ||
    !!codeBlockPreviewComponent(node)
  );
}

/**
 * Finds the preview block a selection acts on: one selected as a node, or the
 * one whose source the caret is in.
 *
 * @returns {{ node: import("prosemirror-model").Node, pos: number }|null}
 */
export function activePreviewBlock({ selection, schema }) {
  if (
    selection instanceof NodeSelection &&
    isPreviewBlock(selection.node, schema)
  ) {
    return { node: selection.node, pos: selection.from };
  }

  const { $head } = selection;

  for (let depth = $head.depth; depth > 0; depth--) {
    const node = $head.node(depth);

    if (isPreviewBlock(node, schema)) {
      return { node, pos: $head.before(depth) };
    }
  }

  return null;
}

class PreviewToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    opts.controls.forEach((control) => {
      this.addButton({
        ...control,
        action: () => opts.runControl(control),
      });
    });

    this.addButton({
      id: "preview-show-source",
      icon: "code",
      title: "composer.preview_node.show_source",
      className: "composer-preview-toolbar__show-source",
      condition: () => !opts.isShowingSource(),
      action: opts.toggleSource,
    });

    this.addButton({
      id: "preview-show-preview",
      icon: "eye",
      title: "composer.preview_node.show_preview",
      className: "composer-preview-toolbar__show-preview",
      condition: () => opts.isShowingSource(),
      action: opts.toggleSource,
    });
  }
}

class PreviewToolbarPluginView {
  #destroyed = false;
  #menuInstance;
  #menuTrigger;
  #replacedToolbar;
  #toolbars = new Map();
  #toolbar;
  #pos;

  #view;
  #getContext;

  constructor({ getContext }) {
    this.#getContext = getContext;
  }

  update(view) {
    this.#view = view;

    const active = activePreviewBlock(view.state);

    if (!active) {
      // Don't tear down while a toolbar button is focused.
      if (!this.#menuInstance?.content?.contains(document.activeElement)) {
        this.#resetToolbar();
      }
      return;
    }

    this.#updateState(active);
    this.#displayToolbar();
  }

  #resetToolbar() {
    this.#menuInstance?.destroy();
    this.#menuInstance = null;
    this.#menuTrigger = null;

    if (this.#replacedToolbar) {
      this.#getContext().replaceToolbar(null, this.#replacedToolbar);
      this.#replacedToolbar = null;
    }
  }

  #updateState({ node, pos }) {
    this.#pos = pos;
    this.#toolbar = this.#toolbarFor(node.type);
  }

  // one toolbar per node type: its buttons are fixed and resolve their target
  // from the selection when they run
  #toolbarFor(type) {
    let toolbar = this.#toolbars.get(type.name);

    if (!toolbar) {
      toolbar = new PreviewToolbar({
        controls: type.spec.previewControls ?? [],
        runControl: (control) => this.#runControl(control),
        toggleSource: () => this.#nodeView()?.toggleSource(),
        isShowingSource: () => !!this.#nodeView()?.showingSource,
      });

      toolbar.rovingButtonBar = this.#rovingButtonBar.bind(this);
      this.#toolbars.set(type.name, toolbar);
    }

    return toolbar;
  }

  #nodeView() {
    const dom = this.#view.nodeDOM(this.#pos);

    return dom instanceof HTMLElement ? previewNodeViewFor(dom) : undefined;
  }

  #runControl(control) {
    const active = activePreviewBlock(this.#view.state);

    if (!active) {
      return;
    }

    control.action({
      node: active.node,
      view: this.#view,
      context: this.#getContext(),
    });
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
    } else if (this.#replacedToolbar !== this.#toolbar) {
      // replacing again on every transaction would re-render the whole bar for
      // each keystroke typed into the source
      this.#getContext().replaceToolbar(this.#toolbar);
      this.#replacedToolbar = this.#toolbar;
    }
  }

  async #showFloatingToolbar() {
    const trigger = this.#view.nodeDOM(this.#pos);

    if (!(trigger instanceof HTMLElement)) {
      return;
    }

    // claimed before the await: two updates in one microtask would orphan an instance
    if (this.#menuTrigger === trigger) {
      return;
    }

    this.#menuInstance?.destroy();
    this.#menuTrigger = trigger;

    this.#menuInstance = await this.#getContext().menu.newInstance(trigger, {
      identifier: TOOLBAR_IDENTIFIER,
      component: ToolbarButtons,
      placement: "top-end",
      fallbackPlacements: ["top-end"],
      padding: MENU_PADDING,
      data: this.#toolbar,
      // outside the editor DOM, so mounting it can never affect the block's
      // layout or be read back by the editor as a document change
      portalOutletElement: this.#view.dom.parentElement,
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
      limitShift: {
        offset: ({ rects }) => ({
          crossAxis: Math.min(
            rects.floating.height + 2 * MENU_PADDING,
            rects.reference.height - MENU_PADDING
          ),
        }),
      },
    });

    // destroyed while the instance was being created
    if (this.#destroyed) {
      this.#menuInstance?.destroy();
      this.#menuInstance = null;
      return;
    }

    await this.#menuInstance.show();
  }

  focusToolbar() {
    const focusable = this.#menuInstance?.content?.querySelector(
      'button, a, [tabindex]:not([tabindex="-1"])'
    );

    if (!focusable) {
      return false;
    }

    focusable.focus();

    return true;
  }

  destroy() {
    this.#destroyed = true;
    this.#resetToolbar();
    this.#toolbars.clear();
    this.#toolbar = null;
  }
}

/**
 * Toolbar for the block a `preview_source` belongs to.
 *
 * @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension}
 */
const extension = {
  plugins: ({ pmState: { Plugin }, getContext }) => {
    let pluginView;

    return new Plugin({
      props: {
        handleKeyDown(view, event) {
          if (event.key !== "Tab" || event.shiftKey) {
            return false;
          }

          const { selection, schema } = view.state;

          // only from the selected block: inside the source, Tab is typing
          if (
            !(selection instanceof NodeSelection) ||
            !isPreviewBlock(selection.node, schema)
          ) {
            return false;
          }

          // this editor's own toolbar, so a second editor cannot take the focus
          if (!pluginView?.focusToolbar()) {
            return false;
          }

          event.preventDefault();

          return true;
        },
      },

      view() {
        pluginView = new PreviewToolbarPluginView({ getContext });
        return pluginView;
      },
    });
  },
};

export default extension;
