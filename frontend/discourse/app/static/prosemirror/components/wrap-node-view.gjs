import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { NodeSelection } from "prosemirror-state";
import { parseAttributesString, serializeAttributes } from "../lib/wrap-utils";
import WrapAttributesModal from "./wrap-attributes-modal";

export default class WrapNodeView extends Component {
  @service modal;

  constructor() {
    super(...arguments);
    this.args.onSetup?.(this);
  }

  get isInline() {
    return this.args.node.type.name === "wrap_inline";
  }

  get wrapAttributes() {
    return this.args.node.attrs.data || {};
  }

  get attributesDisplay() {
    const attrs = this.wrapAttributes;
    if (!attrs || Object.keys(attrs).length === 0) {
      return "[wrap]";
    }

    // Display only the wrap name if it exists, otherwise show [wrap]
    if (attrs.wrap) {
      return `[wrap=${attrs.wrap}]`;
    }

    return "[wrap]";
  }

  @action
  editAttributes() {
    const attrsString = serializeAttributes(this.wrapAttributes);

    this.modal.show(WrapAttributesModal, {
      model: {
        initialAttributes: attrsString,
        onApply: this.#updateAttributes.bind(this),
        onRemove: this.removeWrap.bind(this),
      },
    });
  }

  @action
  removeWrap() {
    const pos = this.args.getPos();
    const node = this.args.node;

    if (node.content.size === 0) {
      // Empty wrap, just delete it
      this.args.view.dispatch(
        this.args.view.state.tr.delete(pos, pos + node.nodeSize)
      );
    } else {
      // Replace wrap with its content
      const tr = this.args.view.state.tr;
      tr.replaceWith(pos, pos + node.nodeSize, node.content);
      this.args.view.dispatch(tr);
    }
  }

  #updateAttributes(attrsString) {
    const pos = this.args.getPos();
    const attrs = parseAttributesString(attrsString);
    const tr = this.args.view.state.tr;

    tr.setNodeMarkup(pos, null, { data: attrs });
    tr.setSelection(NodeSelection.create(tr.doc, pos));
    this.args.view.dispatch(tr);
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  <template>
    {{~! strip whitespace ~}}<button
      type="button"
      class="d-wrap-indicator btn-flat
        {{if this.isInline '--inline' '--block'}}"
      contenteditable="false"
      {{on "click" this.editAttributes}}
    >{{~this.attributesDisplay~}}</button>
    {{~yield~}}{{~! strip whitespace ~}}
  </template>
}
