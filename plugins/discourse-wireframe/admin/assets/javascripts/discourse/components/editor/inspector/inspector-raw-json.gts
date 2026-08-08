import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import type { LayoutEntry } from "discourse/blocks/types";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import type WireframeEntryConfigService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-entry-config";
import type WireframeSelectionService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

/**
 * Read/edit the selected entry's serialised JSON form. Lets advanced
 * authors poke at fields the form-based inspector doesn't expose
 * (custom `containerArgs`, raw `classNames`, edge-case condition
 * trees) without leaving the editor.
 *
 * Edit model:
 *   - The textarea seeds from `wireframeSelection.selectedBlockRawEntry`
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
  /** Applies validated raw-entry replacements. */
  @service declare wireframeEntryConfig: WireframeEntryConfigService;
  /** Exposes the selected entry and its stable key. */
  @service declare wireframeSelection: WireframeSelectionService;

  /** Editable JSON text. */
  @tracked draft = "";
  /** Current parse or validation error. */
  @tracked error: string | null = null;

  /**
   * The pretty-printed JSON form of the currently-selected entry.
   * Read fresh on every getter call from the service — but writing
   * back to `draft` happens via the `didInsert` / `didUpdate`
   * modifiers, not from inside the getter (those run as side effects
   * in render, which ember/no-side-effects rejects).
   */
  get serialised(): string {
    const entry = this.wireframeSelection.selectedBlockRawEntry;
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
  get selectionKey(): string | null {
    return this.wireframeSelection.selectedBlockKey;
  }

  /** Whether the draft differs from the selected entry. */
  get isDirty(): boolean {
    return this.draft !== this.serialised;
  }

  /**
   * Whether the JSON is shown read-only. True for unregistered blocks: the
   * editor doesn't know the block's schema, so the entry can't be edited
   * here either. The JSON stays visible (and copyable) so authors can still
   * inspect or export it.
   */
  get readonly(): boolean {
    return this.wireframeSelection.selectedBlockData?.isRegistered === false;
  }

  /**
   * Whether the Apply / Reset buttons are disabled. Disabled when there's
   * nothing to apply (draft matches the serialised entry) or when the entry
   * is read-only because its block is unregistered.
   */
  get editDisabled(): boolean {
    return this.readonly || !this.isDirty;
  }

  /** Resets the draft to the selected entry's serialized value. */
  @action
  seedDraft(): void {
    this.draft = this.serialised;
    this.error = null;
  }

  /**
   * Updates the raw JSON draft.
   *
   * @param event - Textarea input event.
   */
  @action
  handleInput(
    event: Event & {
      /** Textarea that emitted the input event. */
      currentTarget: Element;
    }
  ): void {
    if (!(event.currentTarget instanceof HTMLTextAreaElement)) {
      return;
    }
    this.draft = event.currentTarget.value;
    this.error = null;
  }

  /** Parses, validates, and applies the current draft. */
  @action
  apply(): void {
    let parsed: unknown;
    try {
      parsed = JSON.parse(this.draft);
    } catch (error) {
      this.error = error instanceof Error ? error.message : String(error);
      return;
    }
    // TODO(devxp-typescript-pending): only JSON syntax is checked here; the
    // successfully-parsed draft is forwarded as-authored, so the cast stands
    // in for a shape guard we intentionally do not apply at this boundary.
    const ok = this.wireframeEntryConfig.replaceSelectedEntryRaw(
      parsed as LayoutEntry
    );
    if (!ok) {
      this.error = i18n("wireframe.inspector.raw_json.apply_failed");
      return;
    }
    // Re-seed the draft from the post-publish state so any
    // normalisation the service applied (default args, etc.) shows up.
    this.seedDraft();
  }

  /** Copies the serialized selected entry to the clipboard. */
  @action
  async copy(): Promise<void> {
    try {
      await navigator.clipboard.writeText(this.serialised);
    } catch {
      // Clipboard write can fail in browsers without permission. Swallow
      // — the button is best-effort and a button-click that does
      // nothing is better than an alert. Users see no feedback;
      // future polish could surface a toast.
    }
  }

  /** Discards the current draft changes. */
  @action
  reset(): void {
    this.seedDraft();
  }

  <template>
    <div class="wireframe-inspector-raw-json">
      <textarea
        class="wireframe-inspector-raw-json__textarea"
        spellcheck="false"
        disabled={{this.readonly}}
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
          @disabled={{this.editDisabled}}
          @action={{this.apply}}
        />
        <DButton
          class="btn-flat btn-small"
          @label="wireframe.inspector.raw_json.reset"
          @disabled={{this.editDisabled}}
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
