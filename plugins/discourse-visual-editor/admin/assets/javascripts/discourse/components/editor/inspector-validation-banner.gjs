import Component from "@glimmer/component";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Surfaces the selected block's outlet validation warnings inline at
 * the top of the inspector, so authors don't have to leave the
 * inspector and check the editor toolbar to find out why a block
 * isn't rendering.
 *
 * Filters `visualEditor.validationWarnings` (the flat, cross-outlet
 * list captured by the permissive session-draft layer — see
 * `frontend/discourse/app/blocks/block-outlet.gjs:551`) down to the
 * outlet the selected block lives in. Per-arg attribution doesn't
 * exist today, so we show every warning for the outlet and let the
 * user scan; the toolbar tally agrees with this list.
 *
 * Renders nothing when the selection is healthy.
 */
export default class InspectorValidationBanner extends Component {
  @service visualEditor;

  get warnings() {
    // Reactive on structural mutations; same dep `validationWarnings`
    // already opens upstream.
    const all = this.visualEditor.validationWarnings;
    if (!all.length) {
      return [];
    }
    const key = this.visualEditor.selectedBlockKey;
    if (!key) {
      return [];
    }
    const located = this.visualEditor._findEntryAndOutletSync(key);
    const outletName = located?.outletName;
    if (!outletName) {
      return [];
    }
    return all.filter((w) => w.outletName === outletName);
  }

  <template>
    {{#if this.warnings.length}}
      <div
        class="visual-editor-inspector-validation-banner"
        role="alert"
        aria-live="polite"
      >
        <div class="visual-editor-inspector-validation-banner__header">
          {{dIcon "triangle-exclamation"}}
          <span>{{i18n
              "visual_editor.inspector.validation.banner_title"
            }}</span>
        </div>
        <ul class="visual-editor-inspector-validation-banner__list">
          {{#each this.warnings as |warning|}}
            <li>{{warning.message}}</li>
          {{/each}}
        </ul>
      </div>
    {{/if}}
  </template>
}
