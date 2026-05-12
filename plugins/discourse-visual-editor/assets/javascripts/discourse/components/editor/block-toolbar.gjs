// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Floating contextual toolbar shown above the currently-selected block.
 * Modelled on Gutenberg / Webflow / Puck's block-toolbar pattern: quick
 * actions (move up / move down / duplicate / delete) anchored to the
 * selected block, plus a `⋯` overflow menu reserved for less-common
 * affordances added in later sub-phases (wrap, convert, edit JSON).
 *
 * Mounted only when the chrome is selected. Positioning is via CSS
 * (`top: -32px; left: 0` against the chrome) — anchoring via
 * JavaScript would require popper/floating-ui, and our toolbar is
 * always relative to its host chrome anyway.
 *
 * Click handlers stop propagation so they don't bubble up to the
 * chrome's selection handler.
 */
export default class BlockToolbar extends Component {
  @service visualEditor;

  get canMoveUp() {
    return this.visualEditor.canMoveSelectedUp;
  }

  get canMoveDown() {
    return this.visualEditor.canMoveSelectedDown;
  }

  @action
  moveUp(event) {
    event.preventDefault();
    event.stopPropagation();
    this.visualEditor.moveBlockUp(this.args.blockKey);
  }

  @action
  moveDown(event) {
    event.preventDefault();
    event.stopPropagation();
    this.visualEditor.moveBlockDown(this.args.blockKey);
  }

  @action
  duplicate(event) {
    event.preventDefault();
    event.stopPropagation();
    this.visualEditor.duplicateBlock(this.args.blockKey);
  }

  @action
  remove(event) {
    event.preventDefault();
    event.stopPropagation();
    this.visualEditor.removeBlock(this.args.blockKey);
  }

  <template>
    <div class="visual-editor-block-toolbar" role="toolbar">
      <button
        type="button"
        class="btn btn-flat visual-editor-block-toolbar__btn"
        title={{i18n "visual_editor.canvas.toolbar.move_up"}}
        aria-label={{i18n "visual_editor.canvas.toolbar.move_up"}}
        disabled={{if this.canMoveUp false true}}
        {{on "click" this.moveUp}}
      >
        {{dIcon "arrow-up"}}
      </button>
      <button
        type="button"
        class="btn btn-flat visual-editor-block-toolbar__btn"
        title={{i18n "visual_editor.canvas.toolbar.move_down"}}
        aria-label={{i18n "visual_editor.canvas.toolbar.move_down"}}
        disabled={{if this.canMoveDown false true}}
        {{on "click" this.moveDown}}
      >
        {{dIcon "arrow-down"}}
      </button>
      <button
        type="button"
        class="btn btn-flat visual-editor-block-toolbar__btn"
        title={{i18n "visual_editor.canvas.toolbar.duplicate"}}
        aria-label={{i18n "visual_editor.canvas.toolbar.duplicate"}}
        {{on "click" this.duplicate}}
      >
        {{dIcon "copy"}}
      </button>
      <button
        type="button"
        class="btn btn-flat visual-editor-block-toolbar__btn visual-editor-block-toolbar__btn--danger"
        title={{i18n "visual_editor.canvas.toolbar.delete"}}
        aria-label={{i18n "visual_editor.canvas.toolbar.delete"}}
        {{on "click" this.remove}}
      >
        {{dIcon "trash-can"}}
      </button>
    </div>
  </template>
}
