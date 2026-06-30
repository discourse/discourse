// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedAsyncData } from "ember-async-data";
import { i18n } from "discourse-i18n";
import { walkAllOutlets } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/walk-layout";

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
  @service wireframeLayoutSignal;

  /**
   * Async walk wrapped in `TrackedAsyncData` so the options list
   * recomputes purely from tracked deps — no `didUpdate` / refresh
   * round-trip. Re-runs on `wireframeLayoutSignal.version` bumps and (via the
   * sync stamp-touch prefix inside `walkAllOutlets`) on any per-entry
   * soft-failure stamp change.
   */
  @cached
  get walkData() {
    void this.wireframeLayoutSignal.version;
    return new TrackedAsyncData(walkAllOutlets({ blocksService: this.blocks }));
  }

  /** @type {Array<{name: string, displayName: string}>} */
  get options() {
    // `TrackedAsyncData#value` throws unless `.isResolved` — guard
    // so the first render returns an empty list while the underlying
    // walk promise is still pending.
    const walked = this.walkData.isResolved ? this.walkData.value : [];
    // walkAllOutlets already filters to outlets mounted on the current
    // page; further filter to outlets that have at least one block
    // (a zero-block outlet shows only its boundary badge, and jumping
    // to it lands the user on an empty strip that reads as a no-op).
    // Empty outlets are reachable through the outline tab instead.
    const populated = new Set(
      walked.filter((g) => g.rows.length > 0).map((g) => g.outletName)
    );
    return this.blocks
      .listOutletsWithMetadata()
      .filter((entry) => populated.has(entry.name))
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
      `.wireframe-outlet-boundary[data-outlet-name="${name}"]`
    );
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "start" });
    }
    // Reset to the placeholder so the next pick is also a "change" event.
    target.value = "";
  }

  <template>
    {{#if this.options.length}}
      <select
        class="wireframe-outlet-jump"
        aria-label={{i18n "wireframe.chrome.outlet_jump_label"}}
        {{on "change" this.handleChange}}
      >
        <option value="">
          {{i18n "wireframe.chrome.outlet_jump_placeholder"}}
        </option>
        {{#each this.options as |entry|}}
          <option value={{entry.name}}>{{entry.displayName}}</option>
        {{/each}}
      </select>
    {{else}}
      <select class="wireframe-outlet-jump"></select>
    {{/if}}
  </template>
}
