import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import type A11yService from "discourse/services/a11y";
import type BlocksService from "discourse/services/blocks";
import dDragAndDropSource, {
  type DragSource,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";
import BlockTile from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-tile";
import {
  type BlockPaletteEntry,
  buildBlockPalette,
} from "discourse/plugins/discourse-wireframe/discourse/lib/palette";
import blockPreview from "discourse/plugins/discourse-wireframe/discourse/modifiers/block-preview";
import type WireframeBlockMutationsService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-block-mutations";
import WireframeDragSessionService, {
  type PaletteDragPayload,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-drag-session";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeSelectionService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

type PaletteCategorySection = {
  /** Display category heading. */
  category: string;
  /** Palette entries in the category. */
  rows: BlockPaletteEntry[];
};

/**
 * Palette of registered blocks, shown in the left rail when the user
 * picks the "Palette" tab. Tiles are laid out as one roving-focus grid,
 * grouped under category section headers: each tile is a drag source for
 * inserting a fresh entry onto the canvas, and is also keyboard- and
 * click-activatable to insert into the current selection.
 *
 * Search (the text input) narrows the grid by a case-insensitive substring
 * match against `displayName`, `name`, and `description`.
 *
 * The block registry is frozen post-boot, so we read it once on
 * insertion and memoise the decorated rows via `@cached`.
 */
export default class PalettePanel extends Component {
  /** Announces insertion guidance to assistive technology. */
  @service declare a11y: A11yService;

  /** Provides the registered blocks displayed by the palette. */
  @service declare blocks: BlocksService;

  /** Inserts blocks selected from the palette. */
  @service declare wireframeBlockMutations: WireframeBlockMutationsService;

  /** Tracks palette drag lifecycle state. */
  @service declare wireframeDragSession: WireframeDragSessionService;

  /** Classifies the current insertion target. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Provides the current insertion selection. */
  @service declare wireframeSelection: WireframeSelectionService;

  /** Current palette search query. */
  @tracked searchTerm: string = "";

  /** Resolves a tile back to its palette entry, for the shared hover preview. */
  entryFor = (blockName: string): BlockPaletteEntry | undefined =>
    this.rows.find((row) => row.name === blockName);
  /**
   * The selected block key at the moment the hint was shown. The hint is about
   * that selection, so once the selection changes the hint is stale (see
   * `insertHint`).
   *
   */
  #insertHintSelectionKey: string | null = null;

  /**
   * The message backing `insertHint`, set when a keyboard/click insert can't
   * proceed. `null` when there's nothing to say.
   *
   */
  @tracked _insertHintMessage: string | null = null;

  /**
   * Decorated palette rows for every registered block, from the shared
   * `buildBlockPalette` source so the panel and the popovers stay in sync.
   * Read once — the block registry is immutable after boot.
   *
   * @returns Decorated entries for every pickable block.
   */
  @cached
  get rows(): BlockPaletteEntry[] {
    return buildBlockPalette(this.blocks);
  }

  /**
   * Rows that match the current search term.
   *
   * @returns Palette entries matching the search query.
   */
  get filteredRows(): BlockPaletteEntry[] {
    const term = this.searchTerm.trim().toLowerCase();
    if (!term) {
      return this.rows;
    }
    return this.rows.filter(
      (row) =>
        row.displayName.toLowerCase().includes(term) ||
        row.name.toLowerCase().includes(term) ||
        row.description.toLowerCase().includes(term)
    );
  }

  /**
   * Same rows as `filteredRows`, but grouped into category sections for the
   * list-with-headers view. Each section is `{category, rows}`; a canonical
   * order (Content, Layout, Navigation, Data) leads, then any remaining
   * categories alphabetically. Within a section, rows keep their displayName
   * order (from the shared `buildBlockPalette` sort).
   *
   * @returns Matching palette entries grouped by category.
   */
  get filteredRowsByCategory(): PaletteCategorySection[] {
    const groups = new Map<string, BlockPaletteEntry[]>();
    for (const row of this.filteredRows) {
      // `buildBlockPalette` always fills `category` (falling back to "Misc").
      const key = row.category;
      const bucket = groups.get(key) ?? [];
      bucket.push(row);
      groups.set(key, bucket);
    }
    const order = ["Content", "Layout", "Navigation", "Data"];
    const sorted: PaletteCategorySection[] = [];
    for (const cat of order) {
      const rows = groups.get(cat);
      if (rows) {
        sorted.push({ category: cat, rows });
        groups.delete(cat);
      }
    }
    for (const [category, rows] of [...groups.entries()].sort()) {
      sorted.push({ category, rows });
    }
    return sorted;
  }

  /**
   * The insert hint to show, or `null`. Backed by `_insertHintMessage`, but
   * gated on the selection still being the one the hint was about — the moment
   * the user changes selection (acting on the hint), it's stale and hides
   * itself, so it never lingers. Reading `selectedBlockKey` here keeps that
   * reactive.
   *
   * @returns Current insertion hint, or `null` when stale or absent.
   */
  get insertHint(): string | null {
    if (this._insertHintMessage == null) {
      return null;
    }
    if (
      this.wireframeSelection.selectedBlockKey !== this.#insertHintSelectionKey
    ) {
      return null;
    }
    return this._insertHintMessage;
  }

  /**
   * Updates the palette search query.
   *
   * @param event - Search-input event.
   */
  @action
  updateSearchTerm(event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    this.searchTerm = event.currentTarget.value;
    this._insertHintMessage = null;
  }

  /**
   * Inserts a block from the palette via keyboard (Enter/Space on the focused
   * tile) or click — the keyboard/pointer counterpart to dragging a tile onto the
   * canvas. The destination is the current selection: inside it when it's a
   * container, otherwise after it.
   *
   * Grids are the exception: a grid needs a specific target cell, and the cell a
   * user has highlighted lives in the grid overlay's own state, not the shared
   * selection — so the sidebar can't address it. Rather than insert into the
   * wrong place, it points the user at the cell's own "+" (which is
   * coordinate-aware). With nothing selected there's likewise no target. Both
   * cases surface a hint instead of acting. Validity is enforced by `insertBlock`.
   *
   * @param entry - The palette entry the user activated.
   */
  @action
  insertFromPalette(entry: BlockPaletteEntry): void {
    this._insertHintMessage = null;
    const selectedKey = this.wireframeSelection.selectedBlockKey;
    const selected = this.wireframeSelection.selectedBlockData;
    if (!selectedKey || !selected?.outletName) {
      this.#showInsertHint("wireframe.palette.insert_hint.no_selection");
      return;
    }
    const targetEntry =
      this.wireframeLayoutQuery.findEntryAndOutletSync(selectedKey)?.entry;
    if (
      this.wireframeLayoutQuery.isGridContainer(targetEntry ?? null) ||
      this.wireframeLayoutQuery.isGridCellEntry(targetEntry ?? null)
    ) {
      this.#showInsertHint("wireframe.palette.insert_hint.grid");
      return;
    }
    this.wireframeBlockMutations.insertBlock({
      blockName: entry.name,
      targetKey: selectedKey,
      position: selected.metadata?.isContainer ? "inside" : "after",
      targetOutletName: selected.outletName,
    });
  }

  /**
   * Roving-focus activation handler. The modifier hands back the focused tile
   * element (not the row), so resolve the row by its `data-block-name` and
   * delegate. Click activation goes straight through `insertFromPalette`.
   *
   * @param element - The activated tile.
   */
  @action
  activateTile(element: HTMLElement): void {
    const entry = this.rows.find(
      (row) => row.name === element.dataset.blockName
    );
    if (entry) {
      this.insertFromPalette(entry);
    }
  }

  /**
   * Drag-start callback for a palette tile. Records the entry as the drag source
   * so dragover-time consumers can build labels like "Add Heading here" before
   * the drop fires.
   */
  @action
  handleDragStart({ source }: { source: DragSource }): void {
    this.wireframeDragSession.startPaletteDrag(
      source.data as unknown as PaletteDragPayload
    );
  }

  /**
   * Builds the native drag preview for a palette tile: a faithful clone of the
   * dragged tile, rendered into the isolated offscreen container so no
   * neighboring tile bleeds into the drag image the way the browser's default
   * snapshot of the live tile does.
   *
   * @param args - Drag preview elements.
   *   - `container` - The offscreen host the browser photographs; appended to
   *     `document.body` and removed after cleanup.
   *   - `element` - The dragged tile.
   * @returns Cleanup that removes the cloned preview.
   */
  @action
  renderDragPreview({
    container,
    element,
  }: {
    /** Offscreen host photographed by the browser. */
    container: HTMLElement;
    /** Palette tile being dragged. */
    element: HTMLElement;
  }): () => void {
    const clone = element.cloneNode(true);
    if (!(clone instanceof HTMLElement)) {
      return () => {};
    }
    // Drop the source-only drag styling and the screen-reader-only description
    // span so the preview shows just the tile's thumbnail and label.
    clone.classList.remove("--dragging");
    clone.querySelector(".sr-only")?.remove();
    // Pin the clone to the source width so it renders at the tile's size rather
    // than shrinking to its content in the unconstrained container.
    clone.style.width = `${element.offsetWidth}px`;
    container.append(clone);
    return () => clone.remove();
  }

  /**
   * Shows an insert hint, tagged with the current selection so the visible
   * callout auto-hides once the selection changes, and announces it through the
   * core live-region service for screen readers (the visible callout is
   * `aria-hidden` to avoid a double announcement).
   *
   * @param key - The i18n key for the hint message.
   */
  #showInsertHint(key: string): void {
    const message = i18n(key);
    this.#insertHintSelectionKey = this.wireframeSelection.selectedBlockKey;
    this._insertHintMessage = message;
    this.a11y.announce(message, "polite");
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

      {{! Visual-only callout — screen readers hear the hint via the core a11y
          announce service (see `#showInsertHint`), so this stays aria-hidden to
          avoid announcing it twice. }}
      {{#if this.insertHint}}
        <div class="wireframe-palette__hint" aria-hidden="true">
          {{this.insertHint}}
        </div>
      {{/if}}

      {{#if this.filteredRowsByCategory.length}}
        <div
          class="wireframe-palette__list"
          role="listbox"
          aria-label={{i18n "wireframe.palette.list_label"}}
          {{dRovingFocus
            itemSelector=".wireframe-block-tile"
            onActivate=this.activateTile
          }}
          {{blockPreview entryFor=this.entryFor}}
        >
          {{#each this.filteredRowsByCategory as |section|}}
            <div class="wireframe-palette__section-header">
              {{section.category}}
            </div>
            {{#each section.rows as |row|}}
              <BlockTile
                @entry={{row}}
                @onActivate={{this.insertFromPalette}}
                @activateOn="dblclick"
                {{! The offset pushes the ghost ahead of the pointer so it
                    doesn't cover the drop point. }}
                {{dDragAndDropSource
                  type="wf-palette-block"
                  data=(hash blockName=row.name)
                  dragPreview=this.renderDragPreview
                  dragPreviewOffset=(hash x="1rem" y="0.5rem")
                  onDragStart=this.handleDragStart
                  onDragEnd=this.wireframeDragSession.endDrag
                }}
              />
            {{/each}}
          {{/each}}
        </div>
      {{else}}
        <div class="panel-empty">
          {{i18n "wireframe.palette.empty"}}
        </div>
      {{/if}}
    </div>
  </template>
}
