import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";

/**
 * @typedef {Object} GlimmerNodeViewArgs
 * @property {import("prosemirror-model").Node} node
 * @property {import("prosemirror-view").EditorView} view
 * @property {() => number} getPos
 * @property {import("discourse/lib/composer/rich-editor-extensions").PluginParams} pluginParams
 * @property {any} component
 * @property {string} name
 * @property {boolean} [hasContent]
 * @property {string} [tag]
 * @property {string} [contentTag]
 * @property {(node: import("prosemirror-model").Node) => Record<string, string>} [attrs]
 */
export default class GlimmerNodeView {
  @tracked node;

  #componentInstance;
  #attrs;

  /**
   * @param {GlimmerNodeViewArgs} args
   */
  constructor({
    node,
    view,
    getPos,
    pluginParams,
    getContext,
    component,
    name,
    hasContent = false,
    tag,
    contentTag,
    attrs,
  }) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;
    this.pluginParams = pluginParams ?? { getContext };
    this.component = component;
    this.#attrs = attrs;

    this.pluginParams.getContext().addGlimmerNodeView(this);

    this.dom = document.createElement(tag ?? (node.isInline ? "span" : "div"));

    const attrValues = attrs?.(node);
    this.dom.className = attrValues?.class ?? `composer-${name}-node`;
    this.#applyAttrs(attrValues);

    // attached up front so the editor can render and place a selection in it
    // before the component renders; yielding it only moves it into position
    if (contentTag || hasContent) {
      this.contentDOM = document.createElement(
        contentTag ?? (node.isInline ? "span" : "div")
      );
      this.dom.appendChild(this.contentDOM);
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
    if (node.type !== this.node.type) {
      return false;
    }

    this.node = node;
    this.#applyAttrs();

    return true;
  }

  selectNode() {
    next(() => {
      if (this.#componentInstance?.selectNode) {
        this.#componentInstance.selectNode();
      } else {
        this.dom.classList.add("ProseMirror-selectednode");
      }
    });
  }

  deselectNode() {
    next(() => {
      if (this.#componentInstance?.deselectNode) {
        this.#componentInstance.deselectNode();
      } else {
        this.dom.classList.remove("ProseMirror-selectednode");
      }
    });
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

    this.pluginParams.getContext().removeGlimmerNodeView(this);
  }

  #applyAttrs(attrValues = this.#attrs?.(this.node)) {
    if (!attrValues) {
      return;
    }

    for (const [name, value] of Object.entries(attrValues)) {
      // class is set once, as the editor also manages classes on this element
      if (name === "class") {
        continue;
      }

      if (value == null) {
        this.dom.removeAttribute(name);
      } else {
        this.dom.setAttribute(name, value);
      }
    }
  }
}
