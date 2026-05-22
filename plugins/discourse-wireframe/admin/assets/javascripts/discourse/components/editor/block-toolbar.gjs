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
 * `inlineEdit.controller`; we read its `markState` (a tracked-on-PM-transactions
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
  @service wireframe;

  get canMoveUp() {
    return this.wireframe.canMoveSelectedUp;
  }

  get canMoveDown() {
    return this.wireframe.canMoveSelectedDown;
  }

  /**
   * `true` when this toolbar should expose the "expand for editing"
   * toggle. Shown for `wf:layout` blocks whose `autoCollapse` isn't
   * `"never"` — i.e. the layout could actually collapse at narrow
   * widths, so an override has something to override.
   *
   * @returns {boolean}
   */
  get canForceExpand() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const located = this.wireframe._findEntryAndOutletSync(this.args.blockKey);
    const entry = located?.entry;
    if (entry?.block !== "wf:layout") {
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
    return this.wireframe.isForceExpanded(this.args.blockKey);
  }

  /**
   * The active inline-edit controller, or `null` when no inline
   * session is open.
   */
  get inlineController() {
    return this.wireframe.inlineEdit.controller;
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
      !!this.inlineController &&
      this.wireframe.inlineEdit.blockKey === this.args.blockKey &&
      this.inlineController.markState !== null
    );
  }

  get markState() {
    return this.inlineController?.markState;
  }

  get linkEditMode() {
    return !!this.inlineController?.linkEditMode;
  }

  @action
  toggleForceExpand() {
    this.wireframe.toggleForceExpand(this.args.blockKey);
  }

  @action
  moveUp() {
    this.wireframe.moveBlockUp(this.args.blockKey);
  }

  @action
  moveDown() {
    this.wireframe.moveBlockDown(this.args.blockKey);
  }

  @action
  duplicate() {
    this.wireframe.duplicateBlock(this.args.blockKey);
  }

  @action
  remove() {
    this.wireframe.removeBlock(this.args.blockKey);
  }

  @action
  toggleBold() {
    this.inlineController?.toggleMark("strong");
  }

  @action
  toggleItalic() {
    this.inlineController?.toggleMark("em");
  }

  @action
  startLinkEdit() {
    this.inlineController?.enterLinkMode();
  }

  @action
  applyLink() {
    this.inlineController?.applyLink();
  }

  @action
  removeLink() {
    this.inlineController?.removeLink();
  }

  @action
  cancelLink() {
    this.inlineController?.cancelLink();
  }

  @action
  onLinkUrlInput(event) {
    if (this.inlineController) {
      this.inlineController.linkEditUrl = event.target.value;
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
    <div class="wireframe-block-toolbar" role="toolbar">
      {{#if this.linkEditMode}}
        <input
          type="url"
          class="wireframe-block-toolbar__url-input"
          placeholder="https://..."
          value={{this.inlineController.linkEditUrl}}
          {{didInsert this.focusLinkInput}}
          {{on "input" this.onLinkUrlInput}}
          {{on "keydown" this.onLinkUrlKeydown}}
        />
        <DButton
          class="btn-flat wireframe-block-toolbar__btn"
          @icon="check"
          @title="wireframe.canvas.toolbar.link_apply"
          @ariaLabel="wireframe.canvas.toolbar.link_apply"
          @action={{this.applyLink}}
          @preventFocus={{true}}
        />
        {{#if this.markState.link}}
          <DButton
            class="btn-flat wireframe-block-toolbar__btn"
            @icon="link-slash"
            @title="wireframe.canvas.toolbar.link_remove"
            @ariaLabel="wireframe.canvas.toolbar.link_remove"
            @action={{this.removeLink}}
            @preventFocus={{true}}
          />
        {{/if}}
        <DButton
          class="btn-flat wireframe-block-toolbar__btn"
          @icon="xmark"
          @title="wireframe.canvas.toolbar.link_cancel"
          @ariaLabel="wireframe.canvas.toolbar.link_cancel"
          @action={{this.cancelLink}}
          @preventFocus={{true}}
        />
      {{else}}
        <DButton
          class="btn-flat wireframe-block-toolbar__btn"
          @icon="arrow-up"
          @title="wireframe.canvas.toolbar.move_up"
          @ariaLabel="wireframe.canvas.toolbar.move_up"
          @disabled={{if this.canMoveUp false true}}
          @action={{this.moveUp}}
        />
        <DButton
          class="btn-flat wireframe-block-toolbar__btn"
          @icon="arrow-down"
          @title="wireframe.canvas.toolbar.move_down"
          @ariaLabel="wireframe.canvas.toolbar.move_down"
          @disabled={{if this.canMoveDown false true}}
          @action={{this.moveDown}}
        />
        <DButton
          class="btn-flat wireframe-block-toolbar__btn"
          @icon="copy"
          @title="wireframe.canvas.toolbar.duplicate"
          @ariaLabel="wireframe.canvas.toolbar.duplicate"
          @action={{this.duplicate}}
        />
        {{#if this.canForceExpand}}
          <DButton
            class={{if
              this.isForceExpanded
              "btn-flat wireframe-block-toolbar__btn --active"
              "btn-flat wireframe-block-toolbar__btn"
            }}
            @icon={{if
              this.isForceExpanded
              "down-left-and-up-right-to-center"
              "up-right-and-down-left-from-center"
            }}
            @title={{if
              this.isForceExpanded
              "wireframe.canvas.toolbar.collapse_for_preview"
              "wireframe.canvas.toolbar.expand_for_editing"
            }}
            @ariaLabel={{if
              this.isForceExpanded
              "wireframe.canvas.toolbar.collapse_for_preview"
              "wireframe.canvas.toolbar.expand_for_editing"
            }}
            @ariaPressed={{this.isForceExpanded}}
            @action={{this.toggleForceExpand}}
          />
        {{/if}}
        {{#if this.showInlineFormat}}
          <span
            class="wireframe-block-toolbar__separator"
            aria-hidden="true"
          ></span>
          <DButton
            class={{if
              this.markState.strong
              "btn-flat wireframe-block-toolbar__btn --active"
              "btn-flat wireframe-block-toolbar__btn"
            }}
            @icon="bold"
            @title="wireframe.canvas.toolbar.bold"
            @ariaLabel="wireframe.canvas.toolbar.bold"
            @ariaPressed={{this.markState.strong}}
            @action={{this.toggleBold}}
            @preventFocus={{true}}
          />
          <DButton
            class={{if
              this.markState.em
              "btn-flat wireframe-block-toolbar__btn --active"
              "btn-flat wireframe-block-toolbar__btn"
            }}
            @icon="italic"
            @title="wireframe.canvas.toolbar.italic"
            @ariaLabel="wireframe.canvas.toolbar.italic"
            @ariaPressed={{this.markState.em}}
            @action={{this.toggleItalic}}
            @preventFocus={{true}}
          />
          <DButton
            class={{if
              this.markState.link
              "btn-flat wireframe-block-toolbar__btn --active"
              "btn-flat wireframe-block-toolbar__btn"
            }}
            @icon="link"
            @title="wireframe.canvas.toolbar.link"
            @ariaLabel="wireframe.canvas.toolbar.link"
            @ariaPressed={{this.markState.link}}
            @action={{this.startLinkEdit}}
            @preventFocus={{true}}
          />
        {{/if}}
        <span class="toolbar-separator" aria-hidden="true"></span>
        <DButton
          class="btn-flat wireframe-block-toolbar__btn wireframe-block-toolbar__btn--danger"
          @icon="trash-can"
          @title="wireframe.canvas.toolbar.delete"
          @ariaLabel="wireframe.canvas.toolbar.delete"
          @action={{this.remove}}
        />
      {{/if}}
    </div>
  </template>
}
