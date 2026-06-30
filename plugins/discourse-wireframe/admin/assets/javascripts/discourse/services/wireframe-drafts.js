// @ts-check
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { serializeLayoutForSave } from "../lib/mutate-layout";

const SCHEMA_VERSION = 1;
const DRAFTS_URL = "/admin/plugins/wireframe/block-layout-drafts.json";
const COMPANION_URL = "/admin/plugins/wireframe/companion.json";

/**
 * Owns all per-user block-layout draft I/O — read, save, and delete — against
 * the plugin's drafts endpoint. Drafts are private and never live; promoting one
 * to the live `block_layout` ThemeField is the live-layout service's `publish`.
 *
 * A draft records the live version token it was based on (`base_version_token`)
 * so a later session can tell whether the live layout moved on underneath it.
 */
export default class WireframeDraftsService extends Service {
  @service wireframeLayoutQuery;

  /** Per-session cache of `themeId → companion id (or null)`; the mapping is stable within a load. */
  #companionCache = new Map();

  /**
   * The id of a theme's block-layout companion component (a publishable child that
   * holds its overrides), or null when there is none. Lets the editor target an
   * existing companion on re-entry instead of re-offering to set one up. Cached
   * per session; a transport error degrades to null (no companion).
   *
   * @param {number} themeId
   * @returns {Promise<number|null>}
   */
  async companionId(themeId) {
    if (themeId == null) {
      return null;
    }
    if (this.#companionCache.has(themeId)) {
      return this.#companionCache.get(themeId);
    }
    let companionId = null;
    try {
      const response = await ajax(COMPANION_URL, {
        type: "GET",
        data: { theme_id: themeId },
      });
      companionId = response?.companion_id ?? null;
    } catch {
      companionId = null;
    }
    this.#companionCache.set(themeId, companionId);
    return companionId;
  }

  /**
   * Fetches the current user's drafts, optionally scoped to a set of theme ids
   * (the active stack). Returns parsed rows; a row whose stored `data` can't be
   * parsed is dropped (the caller falls back to the live layout). Never rejects
   * on a transport error — returns an empty array so a failed fetch degrades to
   * "no drafts" rather than breaking the editor's entry path.
   *
   * @param {Array<number>} [themeIds] - theme ids to scope the fetch to.
   * @returns {Promise<Array<{themeId: number, outlet: string, layout: Array<Object>, baseVersionToken: (string|null)}>>}
   */
  async fetchDrafts(themeIds) {
    let response;
    try {
      response = await ajax(DRAFTS_URL, {
        type: "GET",
        data: themeIds?.length ? { theme_ids: themeIds } : {},
      });
    } catch {
      return [];
    }

    const drafts = [];
    for (const row of response?.drafts ?? []) {
      let parsed;
      try {
        parsed = JSON.parse(row.data);
      } catch {
        // A corrupt or older-schema draft row is skipped; the outlet keeps its
        // live seed instead of throwing during hydration.
        continue;
      }
      drafts.push({
        themeId: row.theme_id,
        outlet: row.outlet,
        layout: parsed?.layout ?? [],
        baseVersionToken: row.base_version_token ?? null,
      });
    }
    return drafts;
  }

  /**
   * Deletes the caller's draft for an outlet. The server endpoint is idempotent,
   * and a transport error is swallowed on purpose: a leftover draft is detected
   * and cleaned on the next hydrate, so a failed cleanup must never fail the
   * publish or reset that triggered it.
   *
   * @param {number} themeId - the id of the theme owning the outlet.
   * @param {string} outlet - the outlet identifier.
   * @returns {Promise<void>}
   */
  async deleteDraft(themeId, outlet) {
    try {
      await ajax(DRAFTS_URL, {
        type: "DELETE",
        data: { theme_id: themeId, outlet_name: outlet },
      });
    } catch {
      // Intentionally ignored — see the method doc.
    }
  }

  /**
   * Saves a single outlet as a private draft — the per-outlet Save draft
   * affordance.
   *
   * @param {number} themeId - the id of the theme owning the outlet.
   * @param {string} outlet - the outlet identifier.
   * @param {string} baseVersionToken - the live version token the draft is based
   *   on, supplied by the caller (the live-layout layer owns the token map, so it
   *   is passed in rather than read here — that keeps this draft-I/O leaf free of
   *   a dependency on the live-layout service).
   * @returns {Promise<void>}
   */
  saveDraftOutlet(themeId, outlet, baseVersionToken) {
    const resolvedLayout = this.wireframeLayoutQuery.readResolvedLayout(outlet);
    const layout = serializeLayoutForSave(resolvedLayout ?? []);

    // A null resolved read means the read path failed, not a deliberate empty
    // layout; refuse so we don't persist a draft of nothing.
    if (layout.length === 0 && resolvedLayout == null) {
      throw new Error(
        `Refusing to draft outlet "${outlet}": resolved layout was empty/unreadable`
      );
    }

    return ajax(DRAFTS_URL, {
      type: "POST",
      data: {
        theme_id: themeId,
        outlet_name: outlet,
        layout_json: JSON.stringify({ schema_version: SCHEMA_VERSION, layout }),
        base_version_token: baseVersionToken,
      },
    });
  }
}
