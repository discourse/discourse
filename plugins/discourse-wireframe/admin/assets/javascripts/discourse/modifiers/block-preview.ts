import { registerDestructor } from "@ember/destroyable";
import { type default as Owner, getOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import Modifier, { type ArgsFor } from "ember-modifier";
import DTooltipInstance from "discourse/float-kit/lib/d-tooltip-instance";
import type TooltipService from "discourse/float-kit/services/tooltip";
import discourseLater from "discourse/lib/later";
import BlockPreviewCard from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-preview-card";
import type { BlockPaletteEntry } from "discourse/plugins/discourse-wireframe/discourse/lib/palette";

/** The float-kit identifier of the shared preview, for styling and tests. */
export const BLOCK_PREVIEW_IDENTIFIER = "wireframe-block-preview";

/** How long the pointer rests on a tile before the preview opens. */
export const BLOCK_PREVIEW_OPEN_DELAY = 200;

/** How long the preview survives once the pointer leaves every tile. */
export const BLOCK_PREVIEW_CLOSE_GRACE = 150;

const TILE_SELECTOR = ".wireframe-block-tile[data-palette-id]";

interface BlockPreviewSignature {
  /** The grid whose tiles get a preview. */
  Element: HTMLElement;
  /** Modifier arguments. */
  Args: {
    /** Named modifier arguments. */
    Named: {
      /** Resolves a tile's palette id to the entry its preview describes. */
      entryFor: (paletteId: string) => BlockPaletteEntry | undefined;
    };
    /** This modifier accepts no positional arguments. */
    Positional: [];
  };
}

/**
 * Shows one hover preview for every tile in a grid of blocks.
 *
 * A single tooltip instance serves the whole grid. The first tile the pointer
 * rests on opens it after a short intent delay, so passing across the grid
 * opens nothing. While it is open, moving onto another tile re-anchors the same
 * instance and swaps its entry in place, so the card travels between tiles
 * instead of closing and reopening at each one. Leaving every tile starts a
 * grace period before it closes, long enough to cross a gutter; starting a drag
 * closes it at once so the drag ghost is never paired with a stale card.
 *
 * The preview is hover-only by design: the tile's `aria-describedby` already
 * carries the description for keyboard and assistive-technology users.
 */
export default class BlockPreview extends Modifier<BlockPreviewSignature> {
  @service declare tooltip: TooltipService;

  /** The grid the listeners are attached to. */
  #element: HTMLElement | null = null;

  /** The latest `entryFor` argument. */
  #entryFor: BlockPreviewSignature["Args"]["Named"]["entryFor"] | null = null;

  /** The shared tooltip, created on first use. */
  #instance: DTooltipInstance | null = null;

  /** The tile currently under the pointer, if any. */
  #currentTile: HTMLElement | null = null;

  /** The pending intent-delay open. */
  #openTimer: ReturnType<typeof discourseLater> | null = null;

  /** The pending grace-period close. */
  #closeTimer: ReturnType<typeof discourseLater> | null = null;

  #onPointerOver = (event: PointerEvent): void => {
    const tile = this.#tileFrom(event.target);
    if (tile === this.#currentTile) {
      return;
    }
    this.#currentTile = tile;

    const entry = tile ? this.#entryFor?.(tile.dataset.paletteId!) : undefined;
    if (!tile || !entry) {
      this.#cancelOpen();
      this.#scheduleClose();
      return;
    }

    this.#cancelClose();

    if (this.#instance?.expanded) {
      this.#anchor(tile, entry);
      return;
    }

    this.#cancelOpen();
    this.#openTimer = discourseLater(() => {
      this.#openTimer = null;
      this.#open(tile, entry);
    }, BLOCK_PREVIEW_OPEN_DELAY);
  };

  #onPointerLeave = (): void => {
    this.#currentTile = null;
    this.#cancelOpen();
    this.#scheduleClose();
  };

  #onDragStart = (): void => {
    this.#currentTile = null;
    this.#cancelOpen();
    this.#cancelClose();
    this.#close();
  };

  constructor(owner: Owner, args: ArgsFor<BlockPreviewSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#teardown());
  }

  /**
   * Attaches the delegated listeners once per element and keeps the entry
   * resolver current.
   *
   * @param element - The grid element.
   * @param _positional - Unused positional arguments.
   * @param named - The entry resolver.
   */
  modify(
    element: HTMLElement,
    _positional: [],
    { entryFor }: BlockPreviewSignature["Args"]["Named"]
  ): void {
    this.#entryFor = entryFor;

    if (this.#element === element) {
      return;
    }

    this.#detach();
    this.#element = element;
    element.addEventListener("pointerover", this.#onPointerOver);
    element.addEventListener("pointerleave", this.#onPointerLeave);
    element.addEventListener("dragstart", this.#onDragStart, { capture: true });
  }

  /**
   * The tile under an event target, when the target sits inside this grid.
   *
   * @param target - The event target.
   * @returns The tile element, or `null` when the pointer is over a gutter or
   *   a section header.
   */
  #tileFrom(target: EventTarget | null): HTMLElement | null {
    if (!(target instanceof Element)) {
      return null;
    }
    const tile = target.closest<HTMLElement>(TILE_SELECTOR);
    return tile && this.#element?.contains(tile) ? tile : null;
  }

  #open(tile: HTMLElement, entry: BlockPaletteEntry): void {
    this.#instance ??= new DTooltipInstance(getOwner(this)!, {
      identifier: BLOCK_PREVIEW_IDENTIFIER,
      component: BlockPreviewCard,
      interactive: false,
      placement: "right",
      fallbackPlacements: ["left", "top", "bottom"],
    });
    // Rendered by the app-root host, the way service-created tooltips are; the
    // grid owns no element of its own for the float to live in.
    this.#instance.detachedTrigger = true;
    this.#anchor(tile, entry);
    this.tooltip.show(this.#instance);
  }

  /**
   * Points the open preview at another tile and swaps its entry, without
   * closing it: the float follows its tracked trigger, and its content reads
   * the tracked options.
   *
   * @param tile - The tile to anchor to.
   * @param entry - The entry the card now describes.
   */
  #anchor(tile: HTMLElement, entry: BlockPaletteEntry): void {
    const instance = this.#instance!;
    // Marks the float as travelling rather than appearing: the stylesheet only
    // eases position changes on a warm float, so the first placement does not
    // animate in from the corner it was mounted at.
    if (instance.expanded) {
      instance.portalOutletElement
        ?.querySelector(`[data-identifier="${BLOCK_PREVIEW_IDENTIFIER}"]`)
        ?.setAttribute("data-wf-warm", "");
    }
    instance.trigger = tile;
    instance.options = { ...instance.options, data: { entry } };
  }

  #close(): void {
    if (this.#instance?.expanded) {
      this.tooltip.close(this.#instance);
    }
  }

  #scheduleClose(): void {
    if (!this.#instance?.expanded) {
      return;
    }
    this.#cancelClose();
    this.#closeTimer = discourseLater(() => {
      this.#closeTimer = null;
      this.#close();
    }, BLOCK_PREVIEW_CLOSE_GRACE);
  }

  #cancelOpen(): void {
    cancel(this.#openTimer);
    this.#openTimer = null;
  }

  #cancelClose(): void {
    cancel(this.#closeTimer);
    this.#closeTimer = null;
  }

  #detach(): void {
    const element = this.#element;
    if (!element) {
      return;
    }
    element.removeEventListener("pointerover", this.#onPointerOver);
    element.removeEventListener("pointerleave", this.#onPointerLeave);
    element.removeEventListener("dragstart", this.#onDragStart, {
      capture: true,
    });
    this.#element = null;
  }

  #teardown(): void {
    this.#cancelOpen();
    this.#cancelClose();
    this.#detach();
    this.#close();
    this.#instance?.destroy();
    this.#instance = null;
    this.#currentTile = null;
  }
}
