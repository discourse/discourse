// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";

/**
 * Floating contextual toolbar shown above the currently-selected block.
 * Modelled on Gutenberg / Webflow / Puck's block-toolbar pattern: quick
 * actions (move up / move down / duplicate / delete) anchored to the
 * selected block, plus a `⋯` overflow menu reserved for less-common
 * affordances added in later sub-phases (wrap, convert, edit JSON).
 *
 * Mounted only when the chrome is selected. Positioning is via CSS
 * (`top: -34px; left: 0` against the chrome) — anchoring via
 * JavaScript would require popper/floating-ui, and our toolbar is
 * always relative to its host chrome anyway.
 *
 * Inline-format buttons (bold / italic / link) appear in this same
 * toolbar when the user has entered an inline-edit session on the
 * block AND has a non-empty text selection inside it. The controller
 * (`InlineEditController`) registers itself with the service as
 * `inlineEditor`; we read its `markState` (a tracked-on-PM-transactions
 * getter) and call its commands. Co-locating the inline formatters
 * with the block actions avoids the focus / scroll-tracking problems
 * a separately-floating bubble menu had.
 *
 * Inline-format buttons use `@preventFocus={{true}}` on `DButton` so
 * the mousedown's default focus shift is suppressed — ProseMirror
 * keeps focus and the selection highlight stays visible while the
 * mark applies. The block-action buttons (move/duplicate/delete) don't
 * need this because they have no PM selection to preserve.
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
   *
   * @returns {boolean}
   */
  get isForceExpanded() {
    return this.visualEditor.isForceExpanded(this.args.blockKey);
  }

  /**
   * The active inline-edit controller, or `null` when no inline
   * session is open.
   */
  get inlineEditor() {
    return this.visualEditor.inlineEditor;
  }

  /**
   * Whether the inline-format buttons should be visible. Requires:
   *   - an active inline-edit session on THIS block,
   *   - a non-empty PM selection that the schema marks can apply to.
   *
   * @returns {boolean}
   */
  get showInlineFormat() {
    return (
      !!this.inlineEditor &&
      this.visualEditor.editingBlockKey === this.args.blockKey &&
      this.inlineEditor.markState !== null
    );
  }

  get markState() {
    return this.inlineEditor?.markState;
  }

  get linkEditMode() {
    return !!this.inlineEditor?.linkEditMode;
  }

  @action
  toggleForceExpand() {
    this.visualEditor.toggleForceExpand(this.args.blockKey);
  }

  @action
  moveUp() {
    this.visualEditor.moveBlockUp(this.args.blockKey);
  }

  @action
  moveDown() {
    this.visualEditor.moveBlockDown(this.args.blockKey);
  }

  @action
  duplicate() {
    this.visualEditor.duplicateBlock(this.args.blockKey);
  }

  @action
  remove() {
    this.visualEditor.removeBlock(this.args.blockKey);
  }

  @action
  toggleBold() {
    this.inlineEditor?.toggleMark("strong");
  }

  @action
  toggleItalic() {
    this.inlineEditor?.toggleMark("em");
  }

  @action
  startLinkEdit() {
    this.inlineEditor?.enterLinkMode();
  }

  @action
  applyLink() {
    this.inlineEditor?.applyLink();
  }

  @action
  removeLink() {
    this.inlineEditor?.removeLink();
  }

  @action
  cancelLink() {
    this.inlineEditor?.cancelLink();
  }

  @action
  onLinkUrlInput(event) {
    if (this.inlineEditor) {
      this.inlineEditor.linkEditUrl = event.target.value;
    }
  }

  @action
  onLinkUrlKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.applyLink();
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.cancelLink();
    }
  }

  @action
  focusLinkInput(element) {
    element.focus();
    element.select();
  }

  <template>
    <div class="visual-editor-block-toolbar" role="toolbar">
      {{#if this.linkEditMode}}
        <input
          type="url"
          class="visual-editor-block-toolbar__url-input"
          placeholder="https://..."
          value={{this.inlineEditor.linkEditUrl}}
          {{didInsert this.focusLinkInput}}
          {{on "input" this.onLinkUrlInput}}
          {{on "keydown" this.onLinkUrlKeydown}}
        />
        <DButton
          class="btn-flat visual-editor-block-toolbar__btn"
          @icon="check"
          @title="visual_editor.canvas.toolbar.link_apply"
          @ariaLabel="visual_editor.canvas.toolbar.link_apply"
          @action={{this.applyLink}}
          @preventFocus={{true}}
        />
        {{#if this.markState.link}}
          <DButton
            class="btn-flat visual-editor-block-toolbar__btn"
            @icon="link-slash"
            @title="visual_editor.canvas.toolbar.link_remove"
            @ariaLabel="visual_editor.canvas.toolbar.link_remove"
            @action={{this.removeLink}}
            @preventFocus={{true}}
          />
        {{/if}}
        <DButton
          class="btn-flat visual-editor-block-toolbar__btn"
          @icon="xmark"
          @title="visual_editor.canvas.toolbar.link_cancel"
          @ariaLabel="visual_editor.canvas.toolbar.link_cancel"
          @action={{this.cancelLink}}
          @preventFocus={{true}}
        />
      {{else}}
        <DButton
          class="btn-flat visual-editor-block-toolbar__btn"
          @icon="arrow-up"
          @title="visual_editor.canvas.toolbar.move_up"
          @ariaLabel="visual_editor.canvas.toolbar.move_up"
          @disabled={{if this.canMoveUp false true}}
          @action={{this.moveUp}}
        />
        <DButton
          class="btn-flat visual-editor-block-toolbar__btn"
          @icon="arrow-down"
          @title="visual_editor.canvas.toolbar.move_down"
          @ariaLabel="visual_editor.canvas.toolbar.move_down"
          @disabled={{if this.canMoveDown false true}}
          @action={{this.moveDown}}
        />
        <DButton
          class="btn-flat visual-editor-block-toolbar__btn"
          @icon="copy"
          @title="visual_editor.canvas.toolbar.duplicate"
          @ariaLabel="visual_editor.canvas.toolbar.duplicate"
          @action={{this.duplicate}}
        />
        {{#if this.canForceExpand}}
          <DButton
            class={{if
              this.isForceExpanded
              "btn-flat visual-editor-block-toolbar__btn --active"
              "btn-flat visual-editor-block-toolbar__btn"
            }}
            @icon={{if
              this.isForceExpanded
              "down-left-and-up-right-to-center"
              "up-right-and-down-left-from-center"
            }}
            @title={{if
              this.isForceExpanded
              "visual_editor.canvas.toolbar.collapse_for_preview"
              "visual_editor.canvas.toolbar.expand_for_editing"
            }}
            @ariaLabel={{if
              this.isForceExpanded
              "visual_editor.canvas.toolbar.collapse_for_preview"
              "visual_editor.canvas.toolbar.expand_for_editing"
            }}
            @ariaPressed={{this.isForceExpanded}}
            @action={{this.toggleForceExpand}}
          />
        {{/if}}
        {{#if this.showInlineFormat}}
          <span
            class="visual-editor-block-toolbar__separator"
            aria-hidden="true"
          ></span>
          <DButton
            class={{if
              this.markState.strong
              "btn-flat visual-editor-block-toolbar__btn --active"
              "btn-flat visual-editor-block-toolbar__btn"
            }}
            @icon="bold"
            @title="visual_editor.canvas.toolbar.bold"
            @ariaLabel="visual_editor.canvas.toolbar.bold"
            @ariaPressed={{this.markState.strong}}
            @action={{this.toggleBold}}
            @preventFocus={{true}}
          />
          <DButton
            class={{if
              this.markState.em
              "btn-flat visual-editor-block-toolbar__btn --active"
              "btn-flat visual-editor-block-toolbar__btn"
            }}
            @icon="italic"
            @title="visual_editor.canvas.toolbar.italic"
            @ariaLabel="visual_editor.canvas.toolbar.italic"
            @ariaPressed={{this.markState.em}}
            @action={{this.toggleItalic}}
            @preventFocus={{true}}
          />
          <DButton
            class={{if
              this.markState.link
              "btn-flat visual-editor-block-toolbar__btn --active"
              "btn-flat visual-editor-block-toolbar__btn"
            }}
            @icon="link"
            @title="visual_editor.canvas.toolbar.link"
            @ariaLabel="visual_editor.canvas.toolbar.link"
            @ariaPressed={{this.markState.link}}
            @action={{this.startLinkEdit}}
            @preventFocus={{true}}
          />
        {{/if}}
        <span class="toolbar-separator" aria-hidden="true"></span>
        <DButton
          class="btn-flat visual-editor-block-toolbar__btn visual-editor-block-toolbar__btn--danger"
          @icon="trash-can"
          @title="visual_editor.canvas.toolbar.delete"
          @ariaLabel="visual_editor.canvas.toolbar.delete"
          @action={{this.remove}}
        />
      {{/if}}
    </div>
  </template>
}
