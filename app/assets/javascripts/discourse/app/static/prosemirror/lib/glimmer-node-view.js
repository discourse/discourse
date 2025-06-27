import { TrackedObject } from "@ember-compat/tracked-built-ins";

/**
 * NodeView that bridges ProseMirror to Glimmer components
 *
 * Handles all ProseMirror ↔ Glimmer coordination automatically so developers
 * can create pure Glimmer components without ProseMirror knowledge.
 *
 * Usage:
 * ```js
 * // Simple factory approach
 * GlimmerNodeView.create(MyGlimmerComponent, "my-node")
 *
 * // Or extend for custom behavior
 * class extends GlimmerNodeView {
 *   static componentClass = MyGlimmerComponent;
 *   static nodeType = "my-node";
 * }
 * ```
 */
export default class GlimmerNodeView {
  /**
   * Factory method to create a NodeView class for a Glimmer component
   * @param {Component} componentClass - The Glimmer component class
   * @param {string} nodeType - The node type name (e.g., "image", "video")
   * @param {Function} getContext - Function to get the context (injected automatically)
   * @returns {Function} NodeView constructor
   */
  static create(componentClass, nodeType, getContext) {
    return class extends GlimmerNodeView {
      static componentClass = componentClass;
      static nodeType = nodeType;

      constructor(node, view, getPos) {
        super(node, view, getPos, getContext());
      }
    };
  }

  constructor(node, view, getPos, context) {
    Object.assign(this, {
      node,
      view,
      getPos,
      context,
    });

    const nodeType = this.constructor.nodeType || "node";
    this.dom = document.createElement("div");
    this.dom.classList.add(`composer-${nodeType}-node`);

    if (context?.addGlimmerNodeView) {
      this.componentData = new TrackedObject({
        node,
        view,
        getPos,
        nodeView: this,
        // Add a way for the component to register itself
        setComponentInstance: (instance) => {
          this.componentInstance = instance;
        },
      });
      context.addGlimmerNodeView({
        element: this.dom,
        component: this.constructor.componentClass,
        data: this.componentData,
      });
    }
  }

  #updateComponentData() {
    Object.assign(this.componentData, {
      node: this.node,
      view: this.view,
      getPos: this.getPos,
    });
  }

  update(node) {
    this.node = node;

    this.#updateComponentData();

    return true;
  }

  selectNode() {
    this.componentInstance?.selectNode?.();
  }

  deselectNode() {
    this.componentInstance?.deselectNode?.();
  }

  stopEvent(event) {
    return this.componentInstance?.stopEvent?.(event);
  }

  destroy() {
    this.componentInstance?.destroy?.();
  }
}
