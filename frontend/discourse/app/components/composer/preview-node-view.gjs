import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Node view for block nodes wrapping the source of something that can be
 * rendered, showing the rendered result with an instant toggle to the source.
 *
 * The node holds its source in a single `code_block` child, so editing it is
 * ordinary code editing — syntax highlighting, undo and redo all come from the
 * editor itself. The wrapper must be `isolating` so that editing around it
 * cannot merge neighboring text into the source.
 *
 * ```js
 * nodeSpec: { my_node: { content: "code_block", isolating: true, ... } },
 * nodeViews: {
 *   my_node: {
 *     component: PreviewNodeView,
 *     hasContent: true,
 *     options: { preview: MyPreviewComponent },
 *   },
 * }
 * ```
 *
 * The preview component is rendered with `@source` (the source text) and
 * `@node`.
 */
export default class PreviewNodeView extends Component {
  // nothing to preview yet when an empty node was just inserted
  @tracked showingSource = !this.args.node.textContent;

  constructor() {
    super(...arguments);
    this.args.dom.classList.add("composer-preview-node");
    this.args.contentDOM?.classList.add("composer-preview-node__source");
    this.#syncMode();
    this.args.onSetup?.(this);
  }

  get source() {
    return this.args.node.textContent;
  }

  get toggleLabel() {
    return this.showingSource
      ? i18n("composer.preview_node.show_preview")
      : i18n("composer.preview_node.show_source");
  }

  @action
  toggleSource(event) {
    event.preventDefault();

    this.showingSource = !this.showingSource;
    this.#syncMode();

    const pos = this.args.getPos();
    if (pos === undefined) {
      return;
    }

    const { view } = this.args;
    const { NodeSelection, TextSelection } = this.args.pluginParams.pmState;
    const tr = view.state.tr;

    // the source is hidden while previewing, so the selection cannot stay in it
    tr.setSelection(
      this.showingSource
        ? TextSelection.create(tr.doc, pos + 2 + this.source.length)
        : NodeSelection.create(tr.doc, pos)
    );

    view.dispatch(tr);
    view.focus();
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  // reaching the source with the caret — by arrowing into the node, or clicking
  // where it would be — has to reveal it, or the caret lands out of sight
  setSelection() {
    if (!this.showingSource) {
      this.showingSource = true;
      this.#syncMode();
    }
  }

  // the preview is not editable, and the source is a node of its own
  stopEvent() {
    return false;
  }

  #syncMode() {
    this.args.dom.classList.toggle("--source", this.showingSource);
  }

  <template>
    {{~! strip whitespace ~}}<button
      type="button"
      class="composer-preview-node__toggle btn-flat"
      title={{this.toggleLabel}}
      aria-label={{this.toggleLabel}}
      aria-pressed={{if this.showingSource "true" "false"}}
      contenteditable="false"
      {{on "click" this.toggleSource}}
    >{{icon (if this.showingSource "eye" "code")}}</button>{{#unless
      this.showingSource
    }}<div class="composer-preview-node__preview" contenteditable="false">{{#let
          @options.preview
          as |Preview|
        }}<Preview
            @source={{this.source}}
            @node={{@node}}
          />{{/let}}</div>{{/unless}}{{~! strip whitespace ~}}
  </template>
}
