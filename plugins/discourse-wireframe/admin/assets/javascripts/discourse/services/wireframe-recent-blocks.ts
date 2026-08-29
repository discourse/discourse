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

/** How many block names the Recent group holds. */
export const RECENT_BLOCKS_LIMIT = 6;

// Persisted under core's global key-value store; the `wireframe_` prefix
// namespaces our keys within its shared `discourse_` bucket to avoid collisions.
const KEY_PREFIX = "wireframe_recentBlocks_";

/**
 * Remembers which blocks were inserted most recently into the layout being
 * edited, so the palette can offer them first.
 *
 * The list is per theme: a theme's block layout is the thing an editing session
 * edits, so the blocks a page keeps using are the ones that belong at the top
 * for that theme and not another. It lives in the browser's key-value store,
 * so it survives a reload but is not shared between browsers or users.
 */
export default class WireframeRecentBlocksService extends Service {
  @service declare keyValueStore: ProxiedKeyValueStoreService;
  @service declare wireframePublishTarget: WireframePublishTargetService;

  /**
   * The list last written or read for its storage key. Written only by
   * `record`, so `names` stays free of tracked writes and simply falls back to
   * the store when the theme has changed; `@tracked` cannot sit on a `#`
   * field, hence the prefix.
   */
  @tracked _current: { key: string; list: readonly string[] } | null = null;

  /**
   * Block names inserted most recently into the active theme's layout, most
   * recent first. Empty when no theme is being edited.
   */
  get names(): readonly string[] {
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
   * @param blockName - The registered name of the inserted block.
   */
  record(blockName: string): void {
    const key = this.#key;
    if (!key) {
      return;
    }
    const list = [
      blockName,
      ...this.names.filter((name) => name !== blockName),
    ].slice(0, RECENT_BLOCKS_LIMIT);
    this.keyValueStore.setObject({ key, value: list });
    this._current = { key, list };
  }

  get #key(): string | null {
    const themeId = this.wireframePublishTarget.activeThemeId;
    return themeId == null ? null : `${KEY_PREFIX}${themeId}`;
  }
}
