import { tracked } from "@glimmer/tracking";
import { TrackedObject } from "@ember-compat/tracked-built-ins";

/**
 * NodeView that bridges ProseMirror to Glimmer components
 *
 * Creates a DOM element for rendering a Glimmer component
 * and passes the necessary data to the component.
 */
export default class GlimmerNodeView {
  @tracked node;
  @tracked view;
  @tracked getPos;
  @tracked dom;

  data = new TrackedObject({});

  #componentInstance = null;

  constructor(node, view, getPos) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;

    const nodeType = this.constructor.nodeType || "node";
    this.dom = document.createElement("div");
    this.dom.classList.add(`composer-${nodeType}-node`);

    Object.assign(this.data, {
      node,
      view,
      getPos,
      dom: this.dom,
      nodeView: this,
    });
  }

  #updateData() {
    Object.assign(this.data, {
      node: this.node,
      view: this.view,
      getPos: this.getPos,
    });
  }

  update(node) {
    this.node = node;
    this.#updateData();
    return true;
  }

  setComponentInstance(instance) {
    this.#componentInstance = instance;
  }

  // These methods delegate to the component if it exists
  selectNode() {
    this.#componentInstance?.selectNode?.();
  }

  deselectNode() {
    this.#componentInstance?.deselectNode?.();
  }

  stopEvent(event) {
    return this.#componentInstance?.stopEvent?.(event) || false;
  }

  destroy() {
    this.#componentInstance?.destroy?.();
    this.#componentInstance = null;
  }
}

/**
 * Creates a GlimmerNodeView class for a given component class
 *
 * This helper simplifies the creation of GlimmerNodeView extensions
 * by handling the common pattern of registering and unregistering
 * with the context.
 *
 * @param {string} nodeType - The type of node (used for CSS class names)
 * @param {object} componentClass - The Glimmer component class to render
 * @returns {Function} A function that creates a GlimmerNodeView extension
 */
export function createGlimmerNodeView(nodeType, componentClass) {
  return ({ getContext }) =>
    class extends GlimmerNodeView {
      static nodeType = nodeType;
      static componentClass = componentClass;

      constructor(node, view, getPos) {
        super(node, view, getPos);
        getContext().addGlimmerNodeView(this);
      }

      destroy() {
        getContext().removeGlimmerNodeView(this);
        super.destroy();
      }
    };
}
