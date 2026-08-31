import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import {
  registerPreviewNodeView,
  TOOLBAR_IDENTIFIER,
} from "discourse/lib/composer/preview-block";

/**
 * Node view for block nodes wrapping the source of something that can be
 * rendered, showing the rendered result in its place.
 *
 * The node holds its source in a single `preview_source` child, so editing it
 * is ordinary code editing — highlighting, undo and redo all come from the
 * editor itself. The wrapper must be an `atom`, so the editor moves over it as
 * a unit rather than stepping into source it is not showing, and `isolating`,
 * so editing around it cannot merge neighboring text into the source.
 *
 * ```js
 * nodeSpec: {
 *   my_node: {
 *     content: "preview_source",
 *     atom: true,
 *     isolating: true,
 *     previewControls: [{ id, icon, title, className, action }],
 *     ...
 *   },
 * },
 * nodeViews: {
 *   my_node: {
 *     component: PreviewNodeView,
 *     hasContent: true,
 *     options: { preview: MyPreviewComponent },
 *   },
 * }
 * ```
 *
 * The preview component is rendered with `@source` and `@node`. Controls a
 * feature declares join the source toggle in the toolbar shown for the block,
 * and are called with `{ node, view, getPos, context }`.
 */
export default class PreviewNodeView extends Component {
  @tracked showingSource;

  // The node the preview last rendered. Everything the feature reads comes from
  // this rather than from the live node, so the preview holds still while the
  // source is being edited, and swapping faces over an untouched source does
  // not make the feature lay the same thing out again.
  @tracked renderedNode;

  constructor() {
    super(...arguments);

    this.renderedNode = this.args.node;
    // nothing to preview yet when an empty node was just inserted
    this.showingSource = !this.source;

    this.args.dom.classList.add("composer-preview-node");
    this.args.contentDOM?.classList.add("composer-preview-node__source");
    this.#syncMode();

    registerPreviewNodeView(this.args.dom, this);
    this.args.onSetup?.(this);
  }

  // the editor's own position closure: it maps through later transactions and
  // reports undefined once the block is gone
  getPos() {
    return this.args.getPos();
  }

  get source() {
    return this.args.node.textContent;
  }

  get renderedSource() {
    return this.renderedNode.textContent;
  }

  @action
  toggleSource() {
    this.showingSource = !this.showingSource;
    this.#syncMode();
    this.#syncRendered();

    const pos = this.args.getPos();
    if (pos === undefined) {
      return;
    }

    const { view } = this.args;
    const { NodeSelection, TextSelection } = this.args.pluginParams.pmState;
    const tr = view.state.tr;

    tr.setSelection(
      this.showingSource
        ? TextSelection.create(tr.doc, pos + 2 + this.source.length)
        : NodeSelection.create(tr.doc, pos)
    );

    view.dispatch(tr);
    view.focus();
  }

  // the source can still change under a shown preview, through undo or a
  // transaction the editor applies on its own
  update() {
    this.#syncRendered();
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  // the toolbar is portaled into this node view, so the editor should not treat
  // clicking it as clicking into the document
  stopEvent(event) {
    return (
      event.target instanceof Node &&
      !!event.target.closest?.(`[data-identifier="${TOOLBAR_IDENTIFIER}"]`)
    );
  }

  #syncMode() {
    this.args.dom.classList.toggle("--source", this.showingSource);
  }

  #syncRendered() {
    if (!this.showingSource && this.renderedNode !== this.args.node) {
      this.renderedNode = this.args.node;
    }
  }

  <template>
    {{~! strip whitespace ~}}<div
      class="composer-preview-node__preview"
      contenteditable="false"
      aria-hidden={{if this.showingSource "true" "false"}}
    >{{#let @options.preview as |Preview|}}<Preview
          @source={{this.renderedSource}}
          @node={{this.renderedNode}}
        />{{/let}}</div>{{~! strip whitespace ~}}
  </template>
}
