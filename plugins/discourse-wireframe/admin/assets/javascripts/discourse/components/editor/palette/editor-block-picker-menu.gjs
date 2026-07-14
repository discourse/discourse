// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";
/** @type {import("./block-tile.gjs").default} */
import BlockTile from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-tile";

/**
 * A small curated set floated to the top of the suggested grid (when the user
 * hasn't searched), so the everyday blocks are always one keystroke away.
 */
const CURATED_FIRST = ["paragraph", "heading", "image"];

/**
 * Quick-inserter shown by the FloatKit `menu` service when an empty-drop
 * placeholder is clicked: a search combobox over a grid of block tiles, plus a
 * "Browse all" escape hatch to the full sidebar palette.
 *
 * It's a WAI-ARIA combobox — focus stays in the search input while a
 * `dRovingFocus` "active" highlight moves through the results listbox
 * (`aria-activedescendant`), so the user can keep typing to refine. The
 * suggested set is filtered to blocks the drop target accepts, curated-first;
 * searching filters that same valid set.
 *
 * `@data` (injected by `menu.show(triggerEl, { component, data })`):
 *   - `palette`: the full `buildBlockPalette` row list.
 *   - `onPick`: `(entry) => void` — the calling placeholder inserts + closes.
 *   - `targetOutletName`: the outlet the drop target lives in, for validity.
 * `@close` is injected by FloatKit so "Browse all" can dismiss the menu.
 */
export default class EditorBlockPickerMenu extends Component {
  @service wireframeDropAuthority;
  @service wireframeRail;

  @tracked searchTerm = "";

  /** The search input element — the combobox controller `dRovingFocus` drives. */
  @tracked searchInput = null;

  /**
   * Stable id linking the input's `aria-controls` to the results listbox.
   *
   * @returns {string}
   */
  get listboxId() {
    return `${guidFor(this)}-listbox`;
  }

  /**
   * The palette filtered to blocks the drop target actually accepts.
   *
   * @returns {Array<Object>}
   */
  get validForTarget() {
    const targetOutletName = this.args.data.targetOutletName;
    return this.args.data.palette.filter((entry) =>
      this.wireframeDropAuthority.canInsertBlockAt({
        blockName: entry.name,
        targetOutletName,
      })
    );
  }

  /**
   * The rows to show: a substring filter of the valid set while searching,
   * otherwise the valid set with the curated blocks floated to the top. The
   * valid set is already displayName-sorted, and `sort` is stable, so ties keep
   * that order.
   *
   * @returns {Array<Object>}
   */
  get results() {
    const term = this.searchTerm.trim().toLowerCase();
    const valid = this.validForTarget;
    if (term) {
      return valid.filter(
        (entry) =>
          entry.displayName.toLowerCase().includes(term) ||
          entry.name.toLowerCase().includes(term) ||
          entry.description.toLowerCase().includes(term)
      );
    }
    const rank = (name) => {
      const index = CURATED_FIRST.indexOf(name);
      return index === -1 ? CURATED_FIRST.length : index;
    };
    return [...valid].sort((a, b) => rank(a.name) - rank(b.name));
  }

  @action
  captureInput(element) {
    this.searchInput = element;
  }

  @action
  updateSearch(event) {
    this.searchTerm = event.target.value;
  }

  @action
  pick(entry) {
    this.args.data.onPick?.(entry);
  }

  /**
   * Roving-focus activation handler. The modifier hands back the highlighted
   * tile element; resolve its row and insert. Clicking a tile reaches `pick`
   * directly with the row.
   *
   * @param {HTMLElement} element - The activated tile.
   */
  @action
  activate(element) {
    const entry = this.results.find(
      (row) => row.name === element.dataset.blockName
    );
    if (entry) {
      this.pick(entry);
    }
  }

  @action
  browseAll() {
    this.wireframeRail.showPalette();
    this.args.close?.();
  }

  <template>
    <div class="wireframe-block-picker">
      <input
        type="search"
        role="combobox"
        class="wireframe-block-picker__search"
        placeholder={{i18n "wireframe.palette.search_placeholder"}}
        aria-label={{i18n "wireframe.canvas.grid_overlay.pick_block"}}
        aria-expanded="true"
        aria-controls={{this.listboxId}}
        value={{this.searchTerm}}
        {{on "input" this.updateSearch}}
        {{didInsert this.captureInput}}
        {{dAutoFocus}}
      />

      <div
        id={{this.listboxId}}
        class="wireframe-block-picker__results"
        role="listbox"
        {{dRovingFocus
          selectionMode="active"
          controllerElement=this.searchInput
          itemSelector=".wireframe-block-tile"
          itemsKey=this.searchTerm
          activeClass="--active"
          onActivate=this.activate
        }}
      >
        {{#each this.results as |entry|}}
          <BlockTile @entry={{entry}} @onActivate={{this.pick}} />
        {{else}}
          <div class="wireframe-block-picker__empty">
            {{i18n "wireframe.inserter.no_results"}}
          </div>
        {{/each}}
      </div>

      <DButton
        class="wireframe-block-picker__browse-all btn-flat"
        @label="wireframe.inserter.browse_all"
        @action={{this.browseAll}}
      />
    </div>
  </template>
}
