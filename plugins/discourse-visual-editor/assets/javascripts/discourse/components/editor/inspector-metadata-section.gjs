// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { VALID_BLOCK_ID_PATTERN } from "discourse/lib/blocks/-internals/patterns";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Collapsible "Metadata" section above the inspector tab strip. Holds
 * entry-level properties that aren't `args` — currently the block `id`,
 * with room for `classNames` and other entry props later.
 *
 * Validates the id input live against `VALID_BLOCK_ID_PATTERN` (the
 * same regex core uses at validation time) and shows an inline error
 * when the value is malformed. Commits via the service action so the
 * edit rides the regular structural-undo stack.
 */
export default class InspectorMetadataSection extends Component {
  @service visualEditor;

  /**
   * Section starts open when the selected entry already has an `id` —
   * the author probably wants to see / edit it. Otherwise stays
   * collapsed so the metadata row doesn't compete with the args form
   * for vertical space.
   */
  @tracked expanded = !!this.visualEditor.selectedBlockData?.id;

  @tracked error = null;

  get currentId() {
    return this.visualEditor.selectedBlockData?.id ?? "";
  }

  get helpText() {
    return i18n("visual_editor.inspector.metadata.id_help");
  }

  @action
  toggle() {
    this.expanded = !this.expanded;
  }

  @action
  onIdInput(event) {
    const value = event.target.value.trim();
    if (value && !VALID_BLOCK_ID_PATTERN.test(value)) {
      this.error = i18n("visual_editor.inspector.metadata.id_invalid_format");
      return;
    }
    this.error = null;
    const result = this.visualEditor.updateSelectedEntryId(value);
    if (!result.ok && result.error === "invalid-format") {
      this.error = i18n("visual_editor.inspector.metadata.id_invalid_format");
    }
  }

  <template>
    <div
      class={{dConcatClass
        "visual-editor-inspector-metadata"
        (if this.expanded "--expanded")
      }}
    >
      <button
        type="button"
        class="visual-editor-inspector-metadata__summary"
        aria-expanded={{this.expanded}}
        {{on "click" this.toggle}}
      >
        {{dIcon (if this.expanded "chevron-down" "chevron-right")}}
        <span>{{i18n "visual_editor.inspector.metadata.section_title"}}</span>
      </button>

      {{#if this.expanded}}
        <div class="visual-editor-inspector-metadata__body">
          <div class="visual-editor-inspector-metadata__field">
            <span class="visual-editor-inspector-metadata__label">
              {{i18n "visual_editor.inspector.metadata.id_label"}}
            </span>
            <input
              type="text"
              class="visual-editor-inspector-metadata__input"
              value={{this.currentId}}
              placeholder="hero"
              spellcheck="false"
              autocomplete="off"
              aria-label={{i18n "visual_editor.inspector.metadata.id_label"}}
              {{on "input" this.onIdInput}}
            />
            {{#if this.error}}
              <span
                class="visual-editor-inspector-metadata__error"
                role="alert"
              >
                {{this.error}}
              </span>
            {{else}}
              <span class="visual-editor-inspector-metadata__help">
                {{this.helpText}}
              </span>
            {{/if}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
