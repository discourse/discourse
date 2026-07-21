import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { type ModifierLike } from "@glint/template";
import DButton from "discourse/ui-kit/d-button";
import dAutoFocusUntyped from "discourse/ui-kit/modifiers/d-auto-focus";
import dRovingFocusUntyped from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";
import BlockTile from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-tile";
import type { BlockPaletteEntry } from "discourse/plugins/discourse-wireframe/discourse/lib/palette";
import type WireframeDropAuthority from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-drop-authority";
import type WireframeRail from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-rail";

// TODO(devxp-typescript-pending): drop once d-auto-focus is authored in .gts
// with a real Signature. Its DefaultSignature yields no callable modifier
// overload in Glint, so a direct invocation is rejected.
const dAutoFocus = dAutoFocusUntyped as unknown as ModifierLike<{
  Element: HTMLInputElement;
  Args: {
    Named: {
      selectText?: boolean;
      preventScroll?: boolean;
    };
    Positional: [];
  };
}>;

// TODO(devxp-typescript-pending): drop once d-roving-focus is authored in .gts
// with a real Signature. Its DefaultSignature rejects the named args this
// combobox passes.
const dRovingFocus = dRovingFocusUntyped as unknown as ModifierLike<{
  Element: HTMLElement;
  Args: {
    Named: {
      selectionMode?: "focus" | "active";
      controllerElement?: Element | null;
      itemSelector?: string;
      itemsKey?: string;
      activeClass?: string;
      onActivate?: (element: HTMLElement, event?: Event) => void;
    };
    Positional: [];
  };
}>;

/**
 * A small curated set floated to the top of the suggested grid (when the user
 * hasn't searched), so the everyday blocks are always one keystroke away.
 */
const CURATED_FIRST = ["paragraph", "heading", "image"];

interface EditorBlockPickerMenuSignature {
  Args: {
    /**
     * Injected by `menu.show(triggerEl, { component, data })`:
     *   - `palette`: the full `buildBlockPalette` row list.
     *   - `onPick`: the calling placeholder inserts + closes.
     *   - `targetOutletName`: the outlet the drop target lives in, for validity.
     */
    data: {
      palette: BlockPaletteEntry[];
      onPick?: (entry: BlockPaletteEntry) => void;
      targetOutletName: string;
    };

    /** Injected by FloatKit so "Browse all" can dismiss the menu. */
    close?: () => void;
  };
}

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
 */
export default class EditorBlockPickerMenu extends Component<EditorBlockPickerMenuSignature> {
  @service declare wireframeDropAuthority: WireframeDropAuthority;
  @service declare wireframeRail: WireframeRail;

  @tracked searchTerm = "";

  /** The search input element — the combobox controller `dRovingFocus` drives. */
  @tracked searchInput: HTMLInputElement | null = null;

  /**
   * Stable id linking the input's `aria-controls` to the results listbox.
   */
  get listboxId() {
    return `${guidFor(this)}-listbox`;
  }

  /**
   * The palette filtered to blocks the drop target actually accepts.
   */
  get validForTarget(): BlockPaletteEntry[] {
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
   */
  get results(): BlockPaletteEntry[] {
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
    const rank = (name: string) => {
      const index = CURATED_FIRST.indexOf(name);
      return index === -1 ? CURATED_FIRST.length : index;
    };
    return [...valid].sort((a, b) => rank(a.name) - rank(b.name));
  }

  @action
  captureInput(element: HTMLInputElement) {
    this.searchInput = element;
  }

  @action
  updateSearch(event: Event) {
    this.searchTerm = (event.target as HTMLInputElement).value;
  }

  @action
  pick(entry: BlockPaletteEntry) {
    this.args.data.onPick?.(entry);
  }

  /**
   * Roving-focus activation handler. The modifier hands back the highlighted
   * tile element; resolve its row and insert. Clicking a tile reaches `pick`
   * directly with the row.
   *
   * @param element - The activated tile.
   */
  @action
  activate(element: HTMLElement) {
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
