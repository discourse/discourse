// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { VALID_BLOCK_ID_PATTERN } from "discourse/lib/blocks/-internals/patterns";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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
  @service wireframeEntryConfig;
  @service wireframeSelection;

  /**
   * Section starts open when the selected entry already has an `id` —
   * the author probably wants to see / edit it. Otherwise stays
   * collapsed so the metadata row doesn't compete with the args form
   * for vertical space.
   */
  @tracked expanded = !!this.wireframeSelection.selectedBlockData?.id;

  @tracked error = null;

  get currentId() {
    return this.wireframeSelection.selectedBlockData?.id ?? "";
  }

  /**
   * Whether the metadata fields render read-only. True for unregistered
   * blocks: the editor doesn't know the block's schema, so its entry-level
   * properties (id, and later classNames) aren't editable from the
   * inspector either.
   *
   * @returns {boolean}
   */
  get disabled() {
    return this.wireframeSelection.selectedBlockData?.isRegistered === false;
  }

  get helpText() {
    return i18n("wireframe.inspector.metadata.id_help");
  }

  @action
  toggle() {
    this.expanded = !this.expanded;
  }

  @action
  onIdInput(event) {
    const value = event.target.value.trim();
    if (value && !VALID_BLOCK_ID_PATTERN.test(value)) {
      this.error = i18n("wireframe.inspector.metadata.id_invalid_format");
      return;
    }
    this.error = null;
    const result = this.wireframeEntryConfig.updateSelectedEntryId(value);
    if (!result.ok && result.error === "invalid-format") {
      this.error = i18n("wireframe.inspector.metadata.id_invalid_format");
    }
  }

  <template>
    <div
      class={{dConcatClass
        "wireframe-inspector-metadata"
        (if this.expanded "--expanded")
      }}
    >
      <DButton
        class="wireframe-inspector-metadata__summary"
        @ariaExpanded={{this.expanded}}
        @icon={{if this.expanded "chevron-down" "chevron-right"}}
        @label="wireframe.inspector.metadata.section_title"
        @action={{this.toggle}}
      />

      {{#if this.expanded}}
        <div class="wireframe-inspector-metadata__body">
          <div class="wireframe-inspector-metadata__field">
            <span class="wireframe-inspector-metadata__label">
              {{i18n "wireframe.inspector.metadata.id_label"}}
            </span>
            <input
              type="text"
              class="wireframe-inspector-metadata__input"
              value={{this.currentId}}
              placeholder="hero"
              spellcheck="false"
              autocomplete="off"
              disabled={{this.disabled}}
              aria-label={{i18n "wireframe.inspector.metadata.id_label"}}
              {{on "input" this.onIdInput}}
            />
            {{#if this.error}}
              <span class="wireframe-inspector-metadata__error" role="alert">
                {{this.error}}
              </span>
            {{else}}
              <span class="wireframe-inspector-metadata__help">
                {{this.helpText}}
              </span>
            {{/if}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
