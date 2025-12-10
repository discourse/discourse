import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";

/**
 * @typedef {Object} GlimmerNodeViewArgs
 * @property {import("prosemirror-model").Node} node
 * @property {import("prosemirror-view").EditorView} view
 * @property {() => number} getPos
 * @property {() => import("discourse/lib/composer/rich-editor-extensions").PluginContext} getContext
 * @property {any} component
 * @property {string} name
 */
export default class GlimmerNodeView {
  @tracked node;

  #componentInstance;

  /**
   * @param {GlimmerNodeViewArgs} args
   */
  constructor({
    node,
    view,
    getPos,
    getContext,
    component,
    name,
    hasContent = false,
  }) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;
    this.getContext = getContext;
    this.component = component;

    getContext().addGlimmerNodeView(this);

    this.dom = document.createElement(node.isInline ? "span" : "div");
    this.dom.classList.add(`composer-${name}-node`);
    if (hasContent) {
      this.contentDOM = document.createElement(node.isInline ? "span" : "div");
    }
  }

  @action
  setComponentInstance(instance) {
    this.#componentInstance = instance;

    if (this.#componentInstance?.setSelection) {
      this.setSelection = this.#componentInstance.setSelection.bind(
        this.#componentInstance
      );
    } else {
      this.setSelection = undefined;
    }
  }

  update(node) {
    this.node = node;

    return true;
  }

  selectNode() {
    next(() => this.#componentInstance?.selectNode?.());
  }

  deselectNode() {
    next(() => this.#componentInstance?.deselectNode?.());
  }

  stopEvent(event) {
    return this.#componentInstance?.stopEvent?.(event) ?? false;
  }

  ignoreMutation(mutation) {
    return this.#componentInstance?.ignoreMutation?.(mutation) ?? true;
  }

  destroy() {
    this.#componentInstance?.destroy?.();
    this.#componentInstance = null;

    this.getContext().removeGlimmerNodeView(this);
  }
}
