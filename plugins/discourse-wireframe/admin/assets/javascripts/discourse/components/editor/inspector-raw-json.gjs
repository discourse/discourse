// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Read/edit the selected entry's serialised JSON form. Lets advanced
 * authors poke at fields the form-based inspector doesn't expose
 * (custom `containerArgs`, raw `classNames`, edge-case condition
 * trees) without leaving the editor.
 *
 * Edit model:
 *   - The textarea seeds from `wireframe.selectedBlockRawEntry`
 *     pretty-printed.
 *   - Local `@tracked draft` tracks unsaved keystrokes.
 *   - Apply button parses the draft. Invalid JSON → inline error
 *     banner, draft preserved so the author can fix the typo. Valid
 *     JSON → routes through `replaceSelectedEntryRaw` (which lands
 *     as a structural change so the canvas re-renders).
 *
 * Defending against accidental edits: edits are NOT committed on
 * keystroke — only on the Apply button. This matches user expectation
 * from `<pre>` JSON editors elsewhere in Discourse.
 */
export default class InspectorRawJson extends Component {
  @service wireframe;

  @tracked draft = "";
  @tracked error = null;

  /**
   * The pretty-printed JSON form of the currently-selected entry.
   * Read fresh on every getter call from the service — but writing
   * back to `draft` happens via the `didInsert` / `didUpdate`
   * modifiers, not from inside the getter (those run as side effects
   * in render, which ember/no-side-effects rejects).
   */
  get serialised() {
    const entry = this.wireframe.selectedBlockRawEntry;
    if (!entry) {
      return "";
    }
    return JSON.stringify(entry, null, 2);
  }

  /**
   * Reset signal for the textarea — observes the selected block's key.
   * Each time it changes, the `didUpdate` modifier on the textarea
   * fires and seeds `draft` with the new entry's serialised form.
   */
  get selectionKey() {
    return this.wireframe.selectedBlockKey;
  }

  @action
  seedDraft() {
    this.draft = this.serialised;
    this.error = null;
  }

  @action
  handleInput(event) {
    this.draft = event.target.value;
    this.error = null;
  }

  @action
  apply() {
    let parsed;
    try {
      parsed = JSON.parse(this.draft);
    } catch (e) {
      this.error = e.message;
      return;
    }
    const ok = this.wireframe.replaceSelectedEntryRaw(parsed);
    if (!ok) {
      this.error = i18n("wireframe.inspector.raw_json.apply_failed");
      return;
    }
    // Re-seed the draft from the post-publish state so any
    // normalisation the service applied (default args, etc.) shows up.
    this.seedDraft();
  }

  @action
  async copy() {
    try {
      await navigator.clipboard.writeText(this.serialised);
    } catch {
      // Clipboard write can fail in browsers without permission. Swallow
      // — the button is best-effort and a button-click that does
      // nothing is better than an alert. Users see no feedback;
      // future polish could surface a toast.
    }
  }

  @action
  reset() {
    this.seedDraft();
  }

  get isDirty() {
    return this.draft !== this.serialised;
  }

  <template>
    <div class="wireframe-inspector-raw-json">
      <textarea
        class="wireframe-inspector-raw-json__textarea"
        spellcheck="false"
        aria-label={{i18n "wireframe.inspector.raw_json.aria_label"}}
        {{didInsert this.seedDraft}}
        {{didUpdate this.seedDraft this.selectionKey}}
        {{on "input" this.handleInput}}
      >{{this.draft}}</textarea>

      {{#if this.error}}
        <div class="wireframe-inspector-raw-json__error" role="alert">
          {{dIcon "triangle-exclamation"}}
          <span>{{this.error}}</span>
        </div>
      {{/if}}

      <div class="wireframe-inspector-raw-json__actions">
        <DButton
          class="btn-primary btn-small"
          @label="wireframe.inspector.raw_json.apply"
          @disabled={{if this.isDirty false true}}
          @action={{this.apply}}
        />
        <DButton
          class="btn-flat btn-small"
          @label="wireframe.inspector.raw_json.reset"
          @disabled={{if this.isDirty false true}}
          @action={{this.reset}}
        />
        <DButton
          class="btn-flat btn-small"
          @icon="copy"
          @label="wireframe.inspector.raw_json.copy"
          @action={{this.copy}}
        />
      </div>
    </div>
  </template>
}
