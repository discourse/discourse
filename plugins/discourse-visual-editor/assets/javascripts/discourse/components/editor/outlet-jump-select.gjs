// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import { walkAllOutlets } from "../../lib/walk-layout";

/**
 * Compact outlet picker for the editor toolbar. Mirrors the Outlets
 * tab but as a single dropdown for fast keyboard / single-click jumps
 * without opening the panel.
 *
 * Only shows outlets that are *actually rendered on the current page*
 * — we read the layout map via `walkAllOutlets()` and join with
 * `listOutletsWithMetadata()` for display names. Outlets that exist in
 * the registry but aren't mounted here would be no-ops, so we hide
 * them.
 */
export default class OutletJumpSelect extends Component {
  @service blocks;
  @service visualEditor;

  /** @type {Array<{name: string, displayName: string}>} */
  @tracked _options = [];

  get structuralVersion() {
    return this.visualEditor.structuralVersion;
  }

  @action
  async refresh() {
    const walked = await walkAllOutlets({ blocksService: this.blocks });
    const mounted = new Set(walked.map((g) => g.outletName));
    const all = this.blocks.listOutletsWithMetadata();
    this._options = all
      .filter((entry) => mounted.has(entry.name))
      .sort((a, b) => a.displayName.localeCompare(b.displayName));
  }

  @action
  handleChange(event) {
    const target = event.target;
    const name = target.value;
    if (!name) {
      return;
    }
    const el = document.querySelector(
      `.visual-editor-outlet-boundary[data-outlet-name="${name}"]`
    );
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "start" });
    }
    // Reset to the placeholder so the next pick is also a "change" event.
    target.value = "";
  }

  <template>
    {{#if this._options.length}}
      <select
        class="visual-editor-outlet-jump"
        aria-label={{i18n "visual_editor.chrome.outlet_jump_label"}}
        {{didInsert this.refresh}}
        {{didUpdate this.refresh this.structuralVersion}}
        {{on "change" this.handleChange}}
      >
        <option value="">
          {{i18n "visual_editor.chrome.outlet_jump_placeholder"}}
        </option>
        {{#each this._options as |entry|}}
          <option value={{entry.name}}>{{entry.displayName}}</option>
        {{/each}}
      </select>
    {{else}}
      <select
        class="visual-editor-outlet-jump"
        {{didInsert this.refresh}}
        {{didUpdate this.refresh this.structuralVersion}}
      ></select>
    {{/if}}
  </template>
}
