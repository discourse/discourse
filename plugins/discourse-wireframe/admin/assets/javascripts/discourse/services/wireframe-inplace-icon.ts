import { service } from "@ember/service";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import type MenuService from "discourse/float-kit/services/menu";
import InplaceIconPopover from "discourse/plugins/discourse-wireframe/discourse/components/editor/inplace/inplace-icon-popover";
import InplaceArgEditSession, {
  type InplaceArgEditTarget,
} from "../lib/inplace-arg-edit-session";

/** Target and anchor used to open the in-place icon picker. */
export interface InplaceIconEditTarget extends InplaceArgEditTarget {
  /** Rendered icon element used to position the picker. */
  anchorEl: HTMLElement;
}

/**
 * Owns the state of an in-place icon-edit session: which `(blockKey, argName)`
 * is being edited (inherited from `InplaceArgEditSession`) plus the open FloatKit
 * menu instance hosting the icon picker.
 *
 * It extends the shared base with a menu-backed surface: `start` opens a FloatKit
 * menu anchored to the clicked icon, and `stop` closes it. The picker calls
 * `applyChange` (inherited) with the new icon id on selection; closing the menu —
 * by selection, click-outside, or ESC — routes through the menu's `onClose` so
 * the session state is always cleared. The picker UI lives in `InplaceIconPopover`,
 * mounted via the menu.
 */
export default class WireframeInplaceIconService extends InplaceArgEditSession {
  /** FloatKit service used to host the icon picker. */
  @service declare menu: MenuService;

  /**
   * The open FloatKit menu instance, returned by `menu.show(...)`. Closed by
   * `stop`. Tracked separately so we can close it from paths that don't have the
   * menu API in scope.
   *
   */
  #menuInstance: DMenuInstance | null = null;

  /**
   * Begins an icon-edit session for `(blockKey, argName)` and opens a FloatKit
   * menu anchored to `anchorEl` with the icon picker inside. Awaits closing any
   * prior session first so a stale menu can't outlive the new one.
   *
   * @param target - Block argument and rendered icon used to anchor the picker.
   */
  async start({
    blockKey,
    argName,
    anchorEl,
  }: InplaceIconEditTarget): Promise<void> {
    this.closeInplaceText();
    if (this.blockKey) {
      await this.stop();
    }
    if (!this.openSession({ blockKey, argName })) {
      return;
    }

    this.#menuInstance =
      (await this.menu.show(anchorEl, {
        // Match the public `DIconGridPicker`'s identifier / groupIdentifier /
        // maxWidth so the picker's CSS rules (`.fk-d-menu.d-icon-grid-picker-content
        // { --icon-grid-columns: 12; … }`) cascade and the grid lays out
        // correctly. Without this the picker collapses to a single column.
        identifier: "d-icon-grid-picker",
        groupIdentifier: "d-icon-grid-picker",
        maxWidth: 490,
        // `component:` (not `content:`) is what `d-menu.gjs` reads to render
        // a Glimmer component with `@data` injected. The service's JSDoc
        // mentions `options.content` accepting a Component, but the template
        // string-interpolates `content` instead of mounting it, so callbacks
        // and `@data` never reach the picker.
        component: InplaceIconPopover,
        placement: "bottom-start",
        fallbackPlacements: ["top-start", "bottom-end", "top-end"],
        data: {
          value: this.prevValue ?? "",
          onSelect: (iconId: string) => this.applyChange(iconId),
        },
        onClose: () => this.#onMenuClosed(),
      })) ?? null;
  }

  /**
   * Closes the popover without writing back. Idempotent. The menu's `onClose`
   * callback clears the session state, so this only needs to trigger the close.
   *
   */
  async stop(): Promise<void> {
    const instance = this.#menuInstance;
    if (instance) {
      await instance.close();
    } else {
      this.clearState();
    }
  }

  /**
   * Clears the menu handle on top of the shared session reset.
   */
  clearState(): void {
    this.#menuInstance = null;
    super.clearState();
  }

  /**
   * Called by the menu's `onClose` callback so paths that close the popover
   * externally (click-outside, ESC, etc.) still clear the session state.
   */
  #onMenuClosed(): void {
    this.clearState();
  }
}
