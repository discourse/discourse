import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { type ModifierLike } from "@glint/template";
import type { LayoutEntry } from "discourse/blocks/types";
import type A11yService from "discourse/services/a11y";
import type BlocksService from "discourse/services/blocks";
import dAutoFocusUntyped from "discourse/ui-kit/modifiers/d-auto-focus";
import dDragAndDropSource, {
  type DragSource,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";
import BlockRow from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-row";
import BlockTile from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-tile";
import {
  type BlockPaletteEntry,
  buildBlockPalette,
  RECENT_FALLBACK,
} from "discourse/plugins/discourse-wireframe/discourse/lib/palette";
import type WireframeBlockMutationsService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-block-mutations";
import WireframeDragSessionService, {
  type PaletteDragPayload,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-drag-session";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import WireframeRecentBlocksService, {
  RECENT_BLOCKS_LIMIT,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-recent-blocks";
import type WireframeSelectionService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

// `dAutoFocus` is a plain JS modifier with no Signature; Glint yields no
// callable overload for it, so it is cast to the shape it actually takes.
const dAutoFocus = dAutoFocusUntyped as unknown as ModifierLike<{
  /** Input element receiving focus. */
  Element: HTMLInputElement;
  /** Auto-focus configuration. */
  Args: {
    /** Named auto-focus options. */
    Named: {
      /** Whether the input text is selected after focusing. */
      selectText?: boolean;
    };
  };
}>;

type PaletteCategorySection = {
  /** Display category heading. */
  category: string;
  /** Palette entries in the category. */
  rows: BlockPaletteEntry[];
};

/**
 * Palette of registered blocks, shown in the left rail when the user
 * picks the "Palette" tab. One roving-focus listbox holds a Recent group of
 * compact tiles (what this layout inserted last), then every block as a row
 * under category section headers. Each row is a drag source for inserting a
 * fresh entry onto the canvas, and is also keyboard- and double-click
 * activatable to insert into the current selection.
 *
 * Search comes first: the input takes focus when the panel opens and stays
 * the keyboard's home, with the arrow keys moving an active row and Enter
 * inserting it (the combobox shape the inserter menu uses). The term narrows
 * the list by a case-insensitive substring match against `displayName`,
 * `name`, and `description`, and hides the Recent group while it is set so
 * matches are never listed twice.
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

  /** The blocks inserted most recently into this layout. */
  @service declare wireframeRecentBlocks: WireframeRecentBlocksService;

  /** Provides the current insertion selection. */
  @service declare wireframeSelection: WireframeSelectionService;

  /** Current palette search query. */
  @tracked searchTerm: string = "";

  /** The search input, which `dRovingFocus` drives as the listbox controller. */
  @tracked searchInput: HTMLInputElement | null = null;
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
   * Stable id linking the search input's `aria-controls` to the listbox.
   */
  get listboxId(): string {
    return `${guidFor(this)}-listbox`;
  }

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
   * The Recent group, newest first: the blocks inserted last into this
   * layout, topped up with the block types the layout uses most and then
   * with the palette's defaults, so the group is full even for a fresh
   * page. Limited to blocks the palette still lists. Empty while searching,
   * so a match is never shown twice.
   *
   * @returns Palette entries for the Recent group.
   */
  get recentRows(): BlockPaletteEntry[] {
    if (this.searchTerm.trim()) {
      return [];
    }
    const seen = new Set<string>();
    const rows: BlockPaletteEntry[] = [];
    for (const name of [
      ...this.wireframeRecentBlocks.names,
      ...this.#mostUsedBlockNames(),
      ...RECENT_FALLBACK,
    ]) {
      if (rows.length === RECENT_BLOCKS_LIMIT) {
        break;
      }
      const row = seen.has(name)
        ? undefined
        : this.rows.find((candidate) => candidate.name === name);
      seen.add(name);
      if (row) {
        rows.push(row);
      }
    }
    return rows;
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

  /** Captures the search input used as the listbox controller. */
  @action
  captureInput(element: HTMLInputElement): void {
    this.searchInput = element;
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
   * Inserts a block from the palette via keyboard (Enter on the active row) or
   * double-click — the keyboard/pointer counterpart to dragging a row onto the
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
   * Roving-focus activation handler. The modifier hands back the active row
   * element, so resolve the entry by its `data-block-name` and delegate.
   * Double-click activation goes straight through `insertFromPalette`.
   *
   * @param element - The activated row.
   */
  @action
  activateRow(element: HTMLElement): void {
    const entry = this.rows.find(
      (row) => row.name === element.dataset.blockName
    );
    if (entry) {
      this.insertFromPalette(entry);
    }
  }

  /**
   * Drag-start callback for a palette row. Records the entry as the drag source
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
   * Builds the native drag preview for a palette row or tile: a clone of the
   * dragged element without its description, rendered into the isolated offscreen
   * container so no neighboring row bleeds into the drag image the way the
   * browser's default snapshot of the live row does.
   *
   * @param args - Drag preview elements.
   *   - `container` - The offscreen host the browser photographs; appended to
   *     `document.body` and removed after cleanup.
   *   - `element` - The dragged row or tile.
   * @returns Cleanup that removes the cloned preview.
   */
  @action
  renderDragPreview({
    container,
    element,
  }: {
    /** Offscreen host photographed by the browser. */
    container: HTMLElement;
    /** Palette row or tile being dragged. */
    element: HTMLElement;
  }): () => void {
    const clone = element.cloneNode(true);
    if (!(clone instanceof HTMLElement)) {
      return () => {};
    }
    // Drop the source-only drag styling and the description (visible on a
    // row, screen-reader-only on a tile) so the ghost is the sketch and name.
    clone.classList.remove("--dragging");
    clone.querySelector(".wireframe-block-row__description")?.remove();
    clone.querySelector(".sr-only")?.remove();
    // Pin the clone to the source width so it renders at the row's size rather
    // than shrinking to its content in the unconstrained container.
    clone.style.width = `${element.offsetWidth}px`;
    container.append(clone);
    return () => clone.remove();
  }

  /**
   * Block names used across the editable outlets, most used first. The
   * implicit root layout that wraps an outlet's content is not a choice the
   * author made, so counting starts at its children.
   *
   * @returns Registered block names ordered by how often the layout uses them.
   */
  #mostUsedBlockNames(): string[] {
    const counts = new Map<string, number>();
    const count = (entries: readonly LayoutEntry[]) => {
      for (const entry of entries) {
        const name = this.wireframeLayoutQuery.blockNameOf(entry);
        if (name) {
          counts.set(name, (counts.get(name) ?? 0) + 1);
        }
        if (entry.children?.length) {
          count(entry.children);
        }
      }
    };
    for (const outletName of this.wireframeLayoutQuery.editableOutlets) {
      const layout = this.wireframeLayoutQuery.readResolvedLayout(outletName);
      if (!layout) {
        continue;
      }
      const [root] = layout;
      count(layout.length === 1 && root?.children ? root.children : layout);
    }
    return [...counts.entries()]
      .sort(([nameA, a], [nameB, b]) => b - a || nameA.localeCompare(nameB))
      .map(([name]) => name);
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
        role="combobox"
        class="wireframe-palette__search"
        placeholder={{i18n "wireframe.palette.search_placeholder"}}
        aria-label={{i18n "wireframe.palette.search_placeholder"}}
        aria-expanded="true"
        aria-controls={{this.listboxId}}
        value={{this.searchTerm}}
        {{on "input" this.updateSearchTerm}}
        {{didInsert this.captureInput}}
        {{dAutoFocus}}
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
          id={{this.listboxId}}
          class="wireframe-palette__list"
          role="listbox"
          aria-label={{i18n "wireframe.palette.list_label"}}
          {{dRovingFocus
            selectionMode="active"
            controllerElement=this.searchInput
            itemSelector=".wireframe-block-tile, .wireframe-block-row"
            itemsKey=this.searchTerm
            activeClass="--active"
            onActivate=this.activateRow
          }}
        >
          {{#if this.recentRows.length}}
            <div class="wireframe-palette__section-header">
              {{i18n "wireframe.palette.recent"}}
            </div>
            <div class="wireframe-palette__recent">
              {{#each this.recentRows key="name" as |row|}}
                <BlockTile
                  @entry={{row}}
                  @onActivate={{this.insertFromPalette}}
                  @activateOn="dblclick"
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
            </div>
          {{/if}}
          {{#each this.filteredRowsByCategory key="category" as |section|}}
            <div class="wireframe-palette__section-header">
              {{section.category}}
            </div>
            {{#each section.rows key="name" as |row|}}
              <BlockRow
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
