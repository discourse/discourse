import Component from "@glimmer/component";
import { action } from "@ember/object";
import {
  registerPreviewNodeView,
  TOOLBAR_IDENTIFIER,
} from "discourse/components/composer/preview-node-view";

/**
 * Renders a registered preview component in place of a `code_block`'s code.
 *
 * Unlike `composer/preview-node-view`, the block has no separate source node:
 * the code IS the node's content, so while the preview shows, the node view
 * exposes no contentDOM and the block behaves as an atom. Showing the source
 * swaps back to the regular code block node view.
 *
 * The preview gets `@source` and `@node`.
 */
export default class CodeBlockPreview extends Component {
  constructor() {
    super(...arguments);

    this.args.dom.classList.add("composer-preview-node");
    // without a contentDOM the browser must never place a caret inside
    this.args.dom.contentEditable = "false";

    registerPreviewNodeView(this.args.dom, this);
    this.args.onSetup?.(this);
  }

  get showingSource() {
    return false;
  }

  @action
  toggleSource() {
    this.args.options.onToggle(this.args.view, this.args.getPos());
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  // the toolbar is portaled into this node view, so its clicks are not document clicks
  stopEvent(event) {
    return (
      event.target instanceof Node &&
      !!event.target.closest?.(`[data-identifier="${TOOLBAR_IDENTIFIER}"]`)
    );
  }

  <template>
    {{~! strip whitespace ~}}<div class="composer-preview-node__preview">{{#let
        @options.preview
        as |Preview|
      }}<Preview
          @source={{@node.textContent}}
          @node={{@node}}
        />{{/let}}</div>{{~! strip whitespace ~}}
  </template>
}
