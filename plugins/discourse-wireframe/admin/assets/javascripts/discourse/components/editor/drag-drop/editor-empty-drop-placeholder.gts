import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import type MenuService from "discourse/float-kit/services/menu";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import EditorBlockPickerMenu from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/editor-block-picker-menu";
import type { BlockPaletteEntry } from "discourse/plugins/discourse-wireframe/discourse/lib/palette";

interface EditorEmptyDropPlaceholderSignature {
  /** Placeholder label, palette, target, and activation callbacks. */
  Args: {
    /** Pre-translated visible and accessible label. */
    hint: string;
    /** Called before the picker opens. */
    onActivate?: () => void;
    /** Called with the palette entry selected by the author. */
    onPick?: (
      /** Palette entry selected by the author. */
      block: BlockPaletteEntry
    ) => void;
    /** Accessible label for the optional background-image action. */
    backgroundHint?: string;
    /** Keeps the primary action on a readable grouped surface. */
    groupActions?: boolean;
    /** Uploads the image selected by the optional background action. */
    onAddBackground?: (
      /** Image file selected by the author. */
      file: File
    ) => void;
    /** Blocks available for insertion. */
    palette: BlockPaletteEntry[];
    /** Outlet used to filter valid blocks. */
    targetOutletName: string;
  };
}

/**
 * Unified empty-state placeholder shown wherever the editor needs an
 * "insert a block here" affordance: an empty outlet, an empty non-grid
 * container, an empty merged cell, and each unoccupied cell of a grid
 * `wf:layout`.
 *
 * The primary clickable bar opens the shared block picker. Containers with a
 * passive background image arg can also provide a secondary upload action,
 * keeping both ways to initialize the container in one coherent empty state.
 *
 * Responsive degradation: the root sets a `wireframe-empty` CSS container so
 * SCSS collapses the visible hint text below ~12rem, leaving just the centered
 * `+`. The button carries an `aria-label` with the same hint, so it stays named
 * for assistive tech in the icon-only state.
 *
 * Args:
 *   - `@hint` (string) — pre-translated message. Shown as the visible label
 *     when there's room, and always the button's accessible name.
 *   - `@palette` (`Array<{name, displayName, icon, ...}>`) — the shared
 *     `buildBlockPalette` rows, already filtered to user-pickable blocks.
 *   - `@targetOutletName` (string) — the outlet the drop target lives in.
 *     The picker filters its suggestions to blocks valid for this outlet.
 *   - `@onPick` (`(blockEntry) => void`) — fired when the author picks
 *     a block from the popover. The placeholder closes the menu after
 *     `onPick` returns.
 *   - `@onActivate` (`() => void`) — fired when the placeholder is
 *     clicked, before the picker opens. The click stops propagation so
 *     the surrounding chrome's own selection handler never runs, so the
 *     owner wires this to select the block the drop target belongs to
 *     (the empty container / slot, or the grid layout for a cell).
 */
export default class EditorEmptyDropPlaceholder extends Component<EditorEmptyDropPlaceholderSignature> {
  /** Opens and closes the block-picker menu. */
  @service declare menu: MenuService;

  #backgroundInputEl: HTMLInputElement | null = null;

  /** Button used as the FloatKit menu anchor. */
  #buttonEl: HTMLButtonElement | null = null;

  /** Open picker-menu instance, or `null` while the picker is closed. */
  #menuInstance: DMenuInstance | null = null;

  get usesActionGroup(): boolean {
    return Boolean(this.args.groupActions || this.args.onAddBackground);
  }

  /**
   * Captures the button used as the menu anchor.
   *
   * @param element - Mounted placeholder button.
   */
  @action
  captureButton(element: HTMLButtonElement): void {
    this.#buttonEl = element;
  }

  /**
   * Selects the owning target and opens its block picker.
   *
   * @param event - Placeholder activation event.
   */
  @action
  async openPicker(event: MouseEvent): Promise<void> {
    // The surrounding `<BlockChrome>` click handler calls
    // `event.preventDefault()` + `selectBlock(...)` and triggers a
    // re-render. Stop propagation so the chrome doesn't swallow the
    // click before the menu opens.
    event?.stopPropagation?.();
    event?.preventDefault?.();
    // Because we stopped propagation, the chrome's own selection never
    // fires. Select the owning block ourselves so the inspector tracks
    // the container / slot / layout the author is dropping into.
    this.args.onActivate?.();
    if (!this.#buttonEl) {
      return;
    }
    this.#menuInstance = await this.menu.show(this.#buttonEl, {
      component: EditorBlockPickerMenu,
      identifier: "wireframe-block-picker",
      placement: "bottom",
      fallbackPlacements: ["top", "right", "left"],
      maxWidth: 320,
      data: {
        palette: this.args.palette,
        targetOutletName: this.args.targetOutletName,
        onPick: this.handlePick,
      },
    });
  }

  /**
   * Forwards a selected palette entry and closes the picker.
   *
   * @param blockEntry - Palette entry selected by the author.
   */
  @action
  handlePick(blockEntry: BlockPaletteEntry): void {
    this.args.onPick?.(blockEntry);
    this.#menuInstance?.close?.();
    this.#menuInstance = null;
  }

  @action
  addBackground(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (file) {
      this.args.onAddBackground?.(file);
    }
    input.value = "";
  }

  @action
  captureBackgroundInput(element: HTMLInputElement): void {
    this.#backgroundInputEl = element;
  }

  @action
  openBackgroundPicker(): void {
    this.args.onActivate?.();
    this.#backgroundInputEl?.click();
  }

  <template>
    {{#if this.usesActionGroup}}
      <div class="wireframe-empty-drop-actions">
        <button
          type="button"
          class="wireframe-empty-drop-placeholder"
          aria-label={{@hint}}
          {{didInsert this.captureButton}}
          {{on "click" this.openPicker}}
        >
          <span class="wireframe-empty-drop-placeholder__icon">
            {{dIcon "plus"}}
          </span>
          <span class="wireframe-empty-drop-placeholder__hint">{{@hint}}</span>
        </button>
        {{#if @onAddBackground}}
          <DButton
            class="wireframe-empty-drop-actions__background btn-flat"
            @icon="image"
            @translatedLabel={{@backgroundHint}}
            @action={{this.openBackgroundPicker}}
          />
          <input
            type="file"
            accept="image/*"
            hidden
            {{didInsert this.captureBackgroundInput}}
            {{on "change" this.addBackground}}
          />
        {{/if}}
      </div>
    {{else}}
      <button
        type="button"
        class="wireframe-empty-drop-placeholder"
        aria-label={{@hint}}
        {{didInsert this.captureButton}}
        {{on "click" this.openPicker}}
      >
        <span class="wireframe-empty-drop-placeholder__icon">
          {{dIcon "plus"}}
        </span>
        <span class="wireframe-empty-drop-placeholder__hint">{{@hint}}</span>
      </button>
    {{/if}}
  </template>
}
