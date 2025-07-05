import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

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
  constructor({ node, view, getPos, getContext, component, name }) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;
    this.getContext = getContext;
    this.component = component;

    getContext().addGlimmerNodeView(this);

    this.dom = document.createElement("div");
    this.dom.classList.add(`composer-${name}-node`);
  }

  @action
  setComponentInstance(instance) {
    this.#componentInstance = instance;
  }

  update(node) {
    this.node = node;

    return true;
  }

  selectNode() {
    this.#componentInstance?.selectNode?.();
  }

  deselectNode() {
    this.#componentInstance?.deselectNode?.();
  }

  setSelection() {
    this.#componentInstance?.setSelection?.(...arguments);
  }

  stopEvent(event) {
    return this.#componentInstance?.stopEvent?.(event) ?? false;
  }

  ignoreMutation() {
    return this.#componentInstance?.ignoreMutation?.() ?? true;
  }

  destroy() {
    this.#componentInstance?.destroy?.();
    this.#componentInstance = null;

    this.getContext().removeGlimmerNodeView(this);
  }
}
