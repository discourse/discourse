import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * Node view for block nodes wrapping the source of something that can be
 * rendered, showing the rendered result with a control to show the source.
 *
 * The node holds its source in a single `preview_source` child, so editing it
 * is ordinary code editing — highlighting, undo and redo all come from the
 * editor itself. The wrapper must be an `atom`, so the editor moves over it as
 * a unit rather than stepping into source it is not showing, and `isolating`,
 * so editing around it cannot merge neighboring text into the source.
 *
 * ```js
 * nodeSpec: { my_node: { content: "preview_source", atom: true, isolating: true, ... } },
 * nodeViews: {
 *   my_node: {
 *     component: PreviewNodeView,
 *     hasContent: true,
 *     options: {
 *       preview: MyPreviewComponent,
 *       controls: [{ icon, label, action }],
 *     },
 *   },
 * }
 * ```
 *
 * The preview component is rendered with `@source` and `@node`. Controls a
 * feature contributes join the one the editor provides, and are called with
 * `{ node, view, getPos, context }`.
 */
export default class PreviewNodeView extends Component {
  @tracked showingSource;

  // the source as it was last rendered: while it is being edited the preview
  // keeps showing this, so it neither re-renders on every keystroke nor
  // rebuilds itself for a half-typed source
  @tracked renderedSource;

  constructor() {
    super(...arguments);

    this.renderedSource = this.args.node.textContent;
    // nothing to preview yet when an empty node was just inserted
    this.showingSource = !this.renderedSource;

    this.args.dom.classList.add("composer-preview-node");
    this.args.contentDOM?.classList.add("composer-preview-node__source");
    this.#syncMode();
    this.args.onSetup?.(this);
  }

  get source() {
    return this.args.node.textContent;
  }

  // the preview follows the source, except while it is being edited: there it
  // holds still, so it neither re-renders on every keystroke nor rebuilds
  // itself for a half-typed source
  get previewSource() {
    return this.showingSource ? this.renderedSource : this.source;
  }

  get toggleLabel() {
    return this.showingSource
      ? i18n("composer.preview_node.show_preview")
      : i18n("composer.preview_node.show_source");
  }

  @action
  toggleSource() {
    if (!this.showingSource) {
      // freeze what the preview shows for as long as the source is being edited
      this.renderedSource = this.source;
    }

    this.showingSource = !this.showingSource;
    this.#syncMode();

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

  @action
  runControl(control) {
    control.action({
      node: this.args.node,
      view: this.args.view,
      getPos: this.args.getPos,
      context: this.args.pluginParams.getContext(),
    });
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  // the controls are the node view's own, so the editor should not treat
  // clicking them as clicking into the document
  stopEvent(event) {
    return (
      event.target instanceof Node &&
      !!event.target.closest?.(".composer-preview-node__controls")
    );
  }

  #syncMode() {
    this.args.dom.classList.toggle("--source", this.showingSource);
  }

  <template>
    {{~! strip whitespace ~}}<div
      class="composer-preview-node__preview"
      contenteditable="false"
      aria-hidden={{if this.showingSource "true" "false"}}
    >{{#let @options.preview as |Preview|}}<Preview
          @source={{this.previewSource}}
          @node={{@node}}
        />{{/let}}</div><div
      class="composer-preview-node__controls"
      contenteditable="false"
      role="group"
    >{{#each @options.controls as |control|}}<DButton
          @icon={{control.icon}}
          @translatedTitle={{control.label}}
          @action={{fn this.runControl control}}
          class="btn-flat composer-preview-node__control"
        />{{/each}}<DButton
        @icon={{if this.showingSource "eye" "code"}}
        @translatedTitle={{this.toggleLabel}}
        @action={{this.toggleSource}}
        aria-pressed={{if this.showingSource "true" "false"}}
        class="btn-flat composer-preview-node__control composer-preview-node__toggle"
      /></div>{{~! strip whitespace ~}}
  </template>
}
