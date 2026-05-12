// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { walkAllOutlets } from "../../lib/walk-layout";

/**
 * Per-outlet inventory for the left rail. Joins
 * `blocks.listOutletsWithMetadata()` (every registered outlet on the
 * site) with `walkAllOutlets()` (the outlets actually rendered on the
 * current page), then groups by `namespaceType` so the panel reads as
 * "Core / Plugin / Theme" sections.
 *
 * Clicking a row scrolls the page to the matching `<BlockOutlet>`
 * boundary's `data-outlet-name` element. Outlets the current page
 * doesn't render are shown muted (the metadata is there, the boundary
 * isn't).
 */
export default class OutletsPanel extends Component {
  @service blocks;
  @service visualEditor;

  countFor = (outletName) => this._counts.get(outletName) ?? 0;
  hasLayoutFor = (outletName) => this._counts.has(outletName);
  /**
   * Maps a namespace-type key to its translated section header. Falls
   * back to the raw key (Title Case) for unfamiliar types.
   *
   * @param {string} ns
   */
  groupLabel = (ns) => {
    const key = `visual_editor.outlets.group_${ns}`;
    const translated = i18n(key);
    if (translated.startsWith("[")) {
      return ns.charAt(0).toUpperCase() + ns.slice(1);
    }
    return translated;
  };
  /**
   * Block counts keyed by outlet name. Refreshed by `walkAllOutlets`
   * whenever the editor reports a structural change.
   *
   * @type {Map<string, number>}
   */
  @tracked _counts = new Map();

  /**
   * Re-walks the outlets whenever a structural mutation lands so the
   * per-outlet block counts stay accurate. Reads `structuralVersion`
   * to subscribe to the editor's bump signal.
   */
  get structuralVersion() {
    return this.visualEditor.structuralVersion;
  }

  @action
  async refresh() {
    const walked = await walkAllOutlets({ blocksService: this.blocks });
    const counts = new Map();
    for (const group of walked) {
      counts.set(group.outletName, group.rows.length);
    }
    this._counts = counts;
  }

  /**
   * All registered outlets grouped by namespaceType. Outlet listings
   * read from `listOutletsWithMetadata()`, which is frozen post-boot,
   * so the grouping itself is memoised; per-outlet block counts come
   * from the tracked `_counts` map so they re-render on every walk.
   *
   * @returns {Array<{ namespaceType: string, outlets: Array<Object> }>}
   */
  @cached
  get groupedOutlets() {
    const all = this.blocks.listOutletsWithMetadata();
    const groups = new Map();
    for (const entry of all) {
      const group = groups.get(entry.namespaceType) ?? [];
      group.push(entry);
      groups.set(entry.namespaceType, group);
    }
    const order = ["core", "plugin", "theme"];
    const sorted = [];
    for (const ns of order) {
      if (groups.has(ns)) {
        sorted.push({
          namespaceType: ns,
          outlets: groups
            .get(ns)
            .slice()
            .sort((a, b) => a.displayName.localeCompare(b.displayName)),
        });
        groups.delete(ns);
      }
    }
    for (const [ns, entries] of groups) {
      sorted.push({
        namespaceType: ns,
        outlets: entries
          .slice()
          .sort((a, b) => a.displayName.localeCompare(b.displayName)),
      });
    }
    return sorted;
  }

  /**
   * Scrolls the page to the matching outlet boundary. Outlets that
   * aren't rendered on the current page are no-ops (no boundary to
   * scroll to); the UI surfaces this by muting the row.
   *
   * @param {string} outletName
   */
  @action
  jumpTo(outletName) {
    const el = document.querySelector(
      `.visual-editor-outlet-boundary[data-outlet-name="${outletName}"]`
    );
    if (!el) {
      return;
    }
    el.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  <template>
    <div
      class="visual-editor-outlets"
      {{didInsert this.refresh}}
      {{didUpdate this.refresh this.structuralVersion}}
    >
      {{#each this.groupedOutlets as |group|}}
        <div class="visual-editor-outlets__group">
          <div class="visual-editor-outlets__group-label">
            {{this.groupLabel group.namespaceType}}
          </div>
          {{#each group.outlets as |entry|}}
            <button
              type="button"
              class="visual-editor-outlets__row
                {{if (this.hasLayoutFor entry.name) '--mounted' '--unmounted'}}"
              title={{entry.description}}
              {{on "click" (fn this.jumpTo entry.name)}}
            >
              <span class="visual-editor-outlets__row-name">
                {{dIcon "cubes"}}
                <span>{{entry.displayName}}</span>
              </span>
              <span class="visual-editor-outlets__row-meta">
                {{entry.name}}
                {{#if (this.hasLayoutFor entry.name)}}
                  ·
                  {{i18n
                    "visual_editor.outlets.block_count"
                    count=(this.countFor entry.name)
                  }}
                {{/if}}
              </span>
            </button>
          {{/each}}
        </div>
      {{else}}
        <div class="panel-empty">
          {{i18n "visual_editor.outlets.empty"}}
        </div>
      {{/each}}
    </div>
  </template>
}
