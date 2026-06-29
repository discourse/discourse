// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Anchored URL editor for inline-editable links on the canvas. Shown
 * via FloatKit when the author hovers a link rendered from a block's
 * `data-block-arg`.
 *
 * Two modes:
 *   - chip mode (default): a small "Edit URL" pill. Clicking switches
 *     into editing mode by opening a `linkEdit` session on the service.
 *   - editing mode: URL input + apply / remove / cancel. FloatKit's
 *     focus-lock (engaged via the `hoverGracePeriod` machinery in
 *     `d-float-body`) keeps the popover open while the input is
 *     focused, so the author can move the mouse away without the
 *     popover dismissing under them.
 *
 * Which mode is shown is derived from the service's `linkEdit` state
 * rather than tracked locally. That makes the popover responsive to
 * any path that opens a session — both the chip's own click and the
 * chrome's "click a URL arg of an already-selected block" gesture
 * (which programmatically opens this same popover) end up in the
 * same `editing` state through one source of truth.
 *
 * The popover owns its UI directly; it does NOT route through the
 * block-toolbar's `fieldEditor` slot. The toolbar's URL-edit surface
 * remains the right home for the inline rich-text link mark (which
 * has no DOM element to anchor a popover to), but block-arg URLs are
 * edited where they live.
 */
export default class LinkEditPopover extends Component {
  @service wireframeLayoutQuery;
  @service wireframeLinkEdit;

  /**
   * Live working copy of the URL while editing. Seeded from the
   * current arg value when the input mounts (`seedInputValue`).
   */
  @tracked value = "";

  /**
   * `true` when the service has an active `linkEdit` session for THIS
   * popover's `(blockKey, argName)`. Derived rather than tracked
   * locally so external entry points (e.g. the chrome's click-arg
   * handler) can drive this popover into edit mode by calling
   * `linkEdit.start` directly.
   *
   * @returns {boolean}
   */
  get editing() {
    const { blockKey, argName } = this.args.data ?? {};
    if (!blockKey || !argName) {
      return false;
    }
    return (
      this.wireframeLinkEdit.blockKey === blockKey &&
      this.wireframeLinkEdit.argName === argName
    );
  }

  /**
   * The live arg value for this link, read from the entry on every
   * access so the chip's "remove" affordance reflects whether the
   * link currently has a target.
   *
   * @returns {string}
   */
  get currentValue() {
    const { blockKey, argName } = this.args.data ?? {};
    if (!blockKey || !argName) {
      return "";
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    return located?.entry?.args?.[argName] ?? "";
  }

  @action
  startEdit(event) {
    event.preventDefault();
    event.stopPropagation();

    const { blockKey, argName } = this.args.data ?? {};
    if (!blockKey || !argName) {
      return;
    }
    this.wireframeLinkEdit.start({ blockKey, argName });
  }

  @action
  applyEdit() {
    this.wireframeLinkEdit.applyChange(this.value || null);
    this.value = "";
  }

  @action
  removeEdit() {
    this.wireframeLinkEdit.applyChange(null);
    this.value = "";
  }

  @action
  cancelEdit() {
    this.wireframeLinkEdit.stop();
    this.value = "";
  }

  @action
  onInput(event) {
    this.value = event.target.value;
  }

  @action
  onKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.applyEdit();
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.cancelEdit();
    }
  }

  /**
   * Seeds the working value from the live arg and focuses the input
   * when it mounts. Auto-select so the author can immediately type
   * over the current URL.
   */
  @action
  seedInputValue(element) {
    this.value = this.currentValue;
    element.focus();
    element.select();
  }

  /**
   * If the popover unmounts mid-edit (e.g. FloatKit closed the tooltip
   * because the user clicked outside while typing), drop the in-flight
   * session so the service doesn't carry stale `linkEdit.blockKey`
   * state into the next interaction.
   */
  @action
  onTeardown() {
    if (this.editing) {
      this.wireframeLinkEdit.stop();
    }
  }

  <template>
    <div class="wf-link-edit-popover" {{willDestroy this.onTeardown}}>
      {{#if this.editing}}
        <input
          type="url"
          class="wf-link-edit-popover__input"
          placeholder="https://..."
          value={{this.value}}
          {{didInsert this.seedInputValue}}
          {{on "input" this.onInput}}
          {{on "keydown" this.onKeydown}}
        />
        <DButton
          class="btn-flat wf-link-edit-popover__btn"
          @icon="check"
          @title="wireframe.canvas.toolbar.link_apply"
          @ariaLabel="wireframe.canvas.toolbar.link_apply"
          @action={{this.applyEdit}}
          @preventFocus={{true}}
        />
        {{#if this.currentValue}}
          <DButton
            class="btn-flat wf-link-edit-popover__btn"
            @icon="link-slash"
            @title="wireframe.canvas.toolbar.link_remove"
            @ariaLabel="wireframe.canvas.toolbar.link_remove"
            @action={{this.removeEdit}}
            @preventFocus={{true}}
          />
        {{/if}}
        <DButton
          class="btn-flat wf-link-edit-popover__btn"
          @icon="xmark"
          @title="wireframe.canvas.toolbar.link_cancel"
          @ariaLabel="wireframe.canvas.toolbar.link_cancel"
          @action={{this.cancelEdit}}
          @preventFocus={{true}}
        />
      {{else}}
        <button
          type="button"
          class="wf-link-edit-popover__chip"
          {{on "click" this.startEdit}}
        >
          {{dIcon "link"}}
          <span>{{i18n "wireframe.canvas.edit_url"}}</span>
        </button>
      {{/if}}
    </div>
  </template>
}
