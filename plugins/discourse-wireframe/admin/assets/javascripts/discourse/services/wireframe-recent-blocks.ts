import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import type KeyValueStoreService from "discourse/services/key-value-store";
import type WireframePublishTargetService from "./wireframe-publish-target";

// TODO(devxp-typescript-pending): use the core service type directly once it
// declares the `KeyValueStore` methods installed dynamically by its proxy loop.
interface ProxiedKeyValueStoreService extends KeyValueStoreService {
  /** Reads and parses a value stored under the supplied key. */
  getObject<Value = unknown>(
    /** Key within the service's global namespace. */
    key: string
  ): Value | null | undefined;
  /** Serializes and stores a value under the supplied key. */
  setObject<Value>(
    /** Storage key and JSON-serializable value to persist. */
    options: {
      /** Key within the service's global namespace. */
      key: string;
      /** JSON-serializable value written for the key. */
      value: Value;
    }
  ): void;
}

/** Maximum number of choices kept in the Recent group. */
export const RECENT_BLOCKS_LIMIT = 6;

// Persisted under core's global key-value store; the `wireframe_` prefix
// namespaces our keys within its shared `discourse_` bucket to avoid collisions.
const KEY_PREFIX = "wireframe_recentBlocks_";

/**
 * Remembers the palette choices inserted most recently into the active theme.
 * The browser-local list survives reloads but is not shared between browsers
 * or users.
 */
export default class WireframeRecentBlocksService extends Service {
  @service declare keyValueStore: ProxiedKeyValueStoreService;
  @service declare wireframePublishTarget: WireframePublishTargetService;

  /**
   * Cached list for the current storage key. The decorator requires `_`
   * instead of JavaScript private syntax.
   */
  @tracked _current: { key: string; list: readonly string[] } | null = null;

  /**
   * Palette choice ids inserted most recently into the active theme's layout,
   * most recent first. Empty when no theme is being edited.
   */
  get ids(): readonly string[] {
    const key = this.#key;
    if (!key) {
      return [];
    }
    if (this._current?.key === key) {
      return this._current.list;
    }
    return this.keyValueStore.getObject<string[]>(key) ?? [];
  }

  /**
   * Notes that a block was just inserted. Moves it to the front of the active
   * theme's list, dropping the oldest entry past the limit; ignored when no
   * theme is being edited.
   *
   * @param paletteId - The stable id of the inserted palette choice.
   */
  record(paletteId: string): void {
    const key = this.#key;
    if (!key) {
      return;
    }
    const list = [
      paletteId,
      ...this.ids.filter((id) => id !== paletteId),
    ].slice(0, RECENT_BLOCKS_LIMIT);
    this.keyValueStore.setObject({ key, value: list });
    this._current = { key, list };
  }

  get #key(): string | null {
    const themeId = this.wireframePublishTarget.activeThemeId;
    return themeId == null ? null : `${KEY_PREFIX}${themeId}`;
  }
}
