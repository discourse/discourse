import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

/** Identifier of the menu the toolbar for a preview block is shown in. */
export const TOOLBAR_IDENTIFIER = "composer-preview-toolbar";

const nodeViews = new WeakMap();

/**
 * The view rendering the block at `dom`, whatever its class: the toolbar uses
 * it only through the `toggleSource()`/`showingSource` seam.
 */
export function previewNodeViewFor(dom) {
  return nodeViews.get(dom);
}

/**
 * Registers a view under its block's `dom`, so the preview toolbar can reach
 * its `toggleSource()`/`showingSource` seam.
 */
export function registerPreviewNodeView(dom, nodeView) {
  nodeViews.set(dom, nodeView);
}

/**
 * Renders a block's `preview_source` child in place of the source itself.
 *
 * The wrapper must be `atom` and `isolating`, or the editor will step into
 * source it is not showing and merge neighboring text into it.
 *
 * ```js
 * nodeSpec: {
 *   my_node: { content: "preview_source", atom: true, isolating: true, previewControls: [...] },
 * },
 * nodeViews: {
 *   my_node: { component: PreviewNodeView, hasContent: true, options: { preview: MyPreview } },
 * }
 * ```
 *
 * The preview gets `@source` and `@node`; controls get `{ node, view, context }`.
 *
 * @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension}
 */
export default class PreviewNodeView extends Component {
  @tracked showingSource;

  // the node the preview last rendered, so it holds still while the source is
  // edited and is not laid out again over a source that has not changed
  @tracked renderedNode;

  constructor() {
    super(...arguments);

    this.renderedNode = this.args.node;
    this.showingSource = !this.source;

    this.args.dom.classList.add("composer-preview-node");
    this.args.contentDOM?.classList.add("composer-preview-node__source");
    this.#syncMode();

    registerPreviewNodeView(this.args.dom, this);
    this.args.onSetup?.(this);
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
        ? // just inside the source, past the wrapper and the source's own start
          TextSelection.create(tr.doc, pos + 2 + this.source.length)
        : NodeSelection.create(tr.doc, pos)
    );

    view.dispatch(tr);
    view.focus();
  }

  update() {
    this.#syncRendered();
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
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
