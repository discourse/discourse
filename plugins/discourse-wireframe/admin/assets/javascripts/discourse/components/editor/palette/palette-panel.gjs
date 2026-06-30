// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { getBlockDisplayMetadata } from "discourse/lib/blocks/-internals/display-metadata";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import PaletteEntry from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/palette-entry";

const NAMESPACE_LABEL_KEYS = {
  core: "wireframe.palette.category_core",
  plugin: "wireframe.palette.category_plugin",
  theme: "wireframe.palette.category_theme",
};

/**
 * Decorated palette entry — the raw `{name, component, metadata}` from
 * `services.blocks.listBlocksWithMetadata()` joined with the
 * default-filled display metadata so the template doesn't have to know
 * about fallbacks.
 *
 * @typedef {Object} PaletteRow
 * @property {string} name
 * @property {string} displayName
 * @property {string} icon
 * @property {string} category
 * @property {string} description
 * @property {string} namespaceType
 */

/**
 * Palette of registered blocks, shown in the left rail when the user
 * picks the "Palette" tab. Each row is a drag source that inserts a new
 * entry onto the canvas (Phase 6c wires up the drop side).
 *
 * Filtering is a two-stage pipeline:
 *  - Search (text input) — case-insensitive substring match against
 *    `displayName`, `name`, and `description`.
 *  - Category chips — toggled set; an empty set means "all".
 *
 * The block registry is frozen post-boot, so we read it once on
 * insertion and memoise the decorated rows via `@cached`.
 */
export default class PalettePanel extends Component {
  @service blocks;

  @tracked searchTerm = "";
  isCategoryActive = (category) => this._activeCategories.has(category);
  /**
   * Maps a category key to the user-facing label. Namespace types (core,
   * plugin, theme) go through i18n; arbitrary block-author categories
   * (e.g. "Content") render as-is since they're already authored in the
   * intended case.
   *
   * @param {string} category
   * @returns {string}
   */
  labelFor = (category) => {
    const key = NAMESPACE_LABEL_KEYS[category];
    return key ? i18n(key) : category;
  };
  @tracked _activeCategories = new Set();

  /**
   * Decorated palette rows for every registered block. Read once — the
   * block registry is immutable after boot.
   *
   * @returns {PaletteRow[]}
   */
  @cached
  get rows() {
    return this.blocks
      .listBlocksWithMetadata()
      .map(({ name, component, metadata }) => {
        const display = getBlockDisplayMetadata(component) ?? {};
        return {
          name,
          displayName: display.displayName,
          icon: display.icon,
          category: display.category,
          description: metadata?.description ?? "",
          namespaceType: metadata?.namespaceType ?? "core",
          paletteHidden: display.paletteHidden === true,
        };
      })
      .filter((row) => !row.paletteHidden)
      .sort((a, b) => a.displayName.localeCompare(b.displayName));
  }

  /**
   * The full set of categories present in the registry, sorted by a
   * canonical ordering: Core first, then Plugin, then Theme, then any
   * remaining categories alphabetically. Used to render the chip row.
   *
   * @returns {string[]}
   */
  @cached
  get categories() {
    const namespaceOrder = ["core", "plugin", "theme"];
    const seen = new Set();
    for (const row of this.rows) {
      seen.add(row.namespaceType);
      seen.add(row.category);
    }
    const ordered = [];
    for (const ns of namespaceOrder) {
      if (seen.has(ns)) {
        ordered.push(ns);
        seen.delete(ns);
      }
    }
    return [...ordered, ...[...seen].sort()];
  }

  /**
   * Rows that match the current search term + category filter.
   *
   * @returns {PaletteRow[]}
   */
  get filteredRows() {
    const term = this.searchTerm.trim().toLowerCase();
    const cats = this._activeCategories;
    return this.rows.filter((row) => {
      if (cats.size > 0) {
        if (!cats.has(row.namespaceType) && !cats.has(row.category)) {
          return false;
        }
      }
      if (!term) {
        return true;
      }
      return (
        row.displayName.toLowerCase().includes(term) ||
        row.name.toLowerCase().includes(term) ||
        row.description.toLowerCase().includes(term)
      );
    });
  }

  /**
   * Same rows as `filteredRows`, but grouped into category sections
   * for the list-with-headers view. Each section is
   * `{category, rows}`; category order follows the same Core / Plugin
   * / Theme / alphabetical convention as the chips. Within a section,
   * rows are sorted by displayName (already true via `rows` sort).
   *
   * @returns {Array<{category: string, rows: PaletteRow[]}>}
   */
  get filteredRowsByCategory() {
    const groups = new Map();
    for (const row of this.filteredRows) {
      const key = row.category || "Misc";
      const bucket = groups.get(key) ?? [];
      bucket.push(row);
      groups.set(key, bucket);
    }
    const order = ["Content", "Layout", "Navigation", "Data"];
    const sorted = [];
    for (const cat of order) {
      if (groups.has(cat)) {
        sorted.push({ category: cat, rows: groups.get(cat) });
        groups.delete(cat);
      }
    }
    for (const [category, rows] of [...groups.entries()].sort()) {
      sorted.push({ category, rows });
    }
    return sorted;
  }

  @action
  updateSearchTerm(event) {
    this.searchTerm = event.target.value;
  }

  @action
  toggleCategory(category) {
    const next = new Set(this._activeCategories);
    if (next.has(category)) {
      next.delete(category);
    } else {
      next.add(category);
    }
    this._activeCategories = next;
  }

  <template>
    <div class="wireframe-palette">
      <input
        type="search"
        class="wireframe-palette__search"
        placeholder={{i18n "wireframe.palette.search_placeholder"}}
        value={{this.searchTerm}}
        {{on "input" this.updateSearchTerm}}
      />

      <div class="wireframe-palette__chips">
        {{#each this.categories as |category|}}
          <DButton
            class={{dConcatClass
              "wireframe-palette__chip"
              (if (this.isCategoryActive category) "--active")
            }}
            @translatedLabel={{this.labelFor category}}
            @action={{fn this.toggleCategory category}}
          />
        {{/each}}
      </div>

      <div class="wireframe-palette__list">
        {{#each this.filteredRowsByCategory as |section|}}
          <div class="wireframe-palette__section">
            <div class="wireframe-palette__section-header">
              {{section.category}}
            </div>
            {{#each section.rows as |row|}}
              <PaletteEntry @entry={{row}} />
            {{/each}}
          </div>
        {{else}}
          <div class="panel-empty">
            {{i18n "wireframe.palette.empty"}}
          </div>
        {{/each}}
      </div>
    </div>
  </template>
}
