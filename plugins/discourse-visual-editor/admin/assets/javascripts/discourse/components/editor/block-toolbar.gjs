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

  /**
   * `true` when this toolbar should expose the "expand for editing"
   * toggle. Shown for `ve:layout` blocks whose `autoCollapse` isn't
   * `"never"` — i.e. the layout could actually collapse at narrow
   * widths, so an override has something to override.
   *
   * Reads the live entry's `args.mode` / `args.autoCollapse` rather
   * than the curry snapshot so the button hides instantly when the
   * author flips `autoCollapse` to `"never"` from the inspector.
   *
   * @returns {boolean}
   */
  get canForceExpand() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.visualEditor.structuralVersion;
    const located = this.visualEditor._findEntryAndOutletSync(
      this.args.blockKey
    );
    const entry = located?.entry;
    if (entry?.block !== "ve:layout") {
      return false;
    }
    return (entry.args?.autoCollapse ?? "default") !== "never";
  }

  /**
   * Mirrors the editor service's force-expand state for this block.
   * Drives the button's pressed/unpressed visual state.
   *
   * @returns {boolean}
   */
  get isForceExpanded() {
    return this.visualEditor.isForceExpanded(this.args.blockKey);
  }

  @action
  toggleForceExpand(event) {
    event.preventDefault();
    event.stopPropagation();
    this.visualEditor.toggleForceExpand(this.args.blockKey);
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
      {{#if this.canForceExpand}}
        <button
          type="button"
          class={{if
            this.isForceExpanded
            "btn btn-flat visual-editor-block-toolbar__btn --active"
            "btn btn-flat visual-editor-block-toolbar__btn"
          }}
          title={{if
            this.isForceExpanded
            (i18n "visual_editor.canvas.toolbar.collapse_for_preview")
            (i18n "visual_editor.canvas.toolbar.expand_for_editing")
          }}
          aria-label={{if
            this.isForceExpanded
            (i18n "visual_editor.canvas.toolbar.collapse_for_preview")
            (i18n "visual_editor.canvas.toolbar.expand_for_editing")
          }}
          aria-pressed={{if this.isForceExpanded "true" "false"}}
          {{on "click" this.toggleForceExpand}}
        >
          {{dIcon
            (if
              this.isForceExpanded
              "down-left-and-up-right-to-center"
              "up-right-and-down-left-from-center"
            )
          }}
        </button>
      {{/if}}
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
