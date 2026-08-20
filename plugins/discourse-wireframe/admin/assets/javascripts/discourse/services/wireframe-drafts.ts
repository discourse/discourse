import Service, { service } from "@ember/service";
import type { LayoutEntry } from "discourse/blocks/types";
import { ajax } from "discourse/lib/ajax";
import { serializeLayoutForSave } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import type WireframeLayoutQueryService from "./wireframe-layout-query";

const SCHEMA_VERSION = 1;
const DRAFTS_URL = "/admin/plugins/wireframe/block-layout-drafts.json";
const COMPANION_URL = "/admin/plugins/wireframe/companion.json";

type CompanionResponse = {
  /** Existing companion theme ID, or `null` when none exists. */
  companion_id: number | null;
};

type DraftRowResponse = {
  /** Version token of the live layout on which the draft was based. */
  base_version_token: string | null;
  /** Serialized draft envelope. */
  data: string;
  /** Outlet containing the draft. */
  outlet: string;
  /** Owning theme ID. */
  theme_id: number;
};

type DraftsResponse = {
  /** Draft rows visible to the current user. */
  drafts: DraftRowResponse[];
};

type DraftEnvelope = {
  /** Persisted layout entries. */
  layout?: LayoutEntry[];
  /** Serialization schema version. */
  schema_version?: number;
};

/** A hydrated per-user layout draft. */
export interface PersistedDraft {
  /** Version token of the live layout on which the draft was based. */
  baseVersionToken: string | null;
  /** Hydrated draft layout. */
  layout: LayoutEntry[];
  /** Outlet containing the draft. */
  outlet: string;
  /** Owning theme ID. */
  themeId: number;
}

/**
 * Owns all per-user block-layout draft I/O — read, save, and delete — against
 * the plugin's drafts endpoint. Drafts are private and never live; promoting one
 * to the live `block_layout` ThemeField is the live-layout service's `publish`.
 *
 * A draft records the live version token it was based on (`base_version_token`)
 * so a later session can tell whether the live layout moved on underneath it.
 */
export default class WireframeDraftsService extends Service {
  /** Resolves the live layout that is serialized into a draft. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Per-session cache of `themeId → companion id (or null)`; the mapping is stable within a load. */
  #companionCache = new Map<number, number | null>();

  /**
   * The id of a theme's block-layout companion component (a publishable child that
   * holds its overrides), or null when there is none. Lets the editor target an
   * existing companion on re-entry instead of re-offering to set one up. Cached
   * per session; a transport error degrades to null (no companion).
   *
   * @param themeId - Theme whose companion should be resolved.
   * @returns The companion theme ID, or `null` when none exists.
   */
  async companionId(themeId: number): Promise<number | null> {
    if (themeId == null) {
      return null;
    }
    const cachedCompanionId = this.#companionCache.get(themeId);
    if (cachedCompanionId !== undefined) {
      return cachedCompanionId;
    }
    let companionId: number | null;
    try {
      // TODO(devxp-typescript-pending): remove this response cast once core's
      // `ajax` helper exposes a generic response type.
      const response = (await ajax(COMPANION_URL, {
        type: "GET",
        data: { theme_id: themeId },
      })) as CompanionResponse;
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
   * @param themeIds - Theme IDs to scope the fetch to.
   * @returns Hydrated drafts whose payloads use the current readable shape.
   */
  async fetchDrafts(themeIds?: number[]): Promise<PersistedDraft[]> {
    let response: DraftsResponse;
    try {
      // TODO(devxp-typescript-pending): remove this response cast once core's
      // `ajax` helper exposes a generic response type.
      response = (await ajax(DRAFTS_URL, {
        type: "GET",
        data: themeIds?.length ? { theme_ids: themeIds } : {},
      })) as DraftsResponse;
    } catch {
      return [];
    }

    const drafts: PersistedDraft[] = [];
    for (const row of response?.drafts ?? []) {
      let parsed: DraftEnvelope;
      try {
        // TODO(devxp-typescript-pending): replace this JSON boundary cast when
        // draft envelopes have a shared runtime validator and inferred type.
        parsed = JSON.parse(row.data) as DraftEnvelope;
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
   * @param themeId - ID of the theme owning the outlet.
   * @param outlet - The outlet identifier.
   */
  async deleteDraft(themeId: number, outlet: string): Promise<void> {
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
   * @param themeId - ID of the theme owning the outlet.
   * @param outlet - The outlet identifier.
   * @param baseVersionToken - The live version token the draft is based
   *   on, supplied by the caller (the live-layout layer owns the token map, so it
   *   is passed in rather than read here — that keeps this draft-I/O leaf free of
   *   a dependency on the live-layout service).
   * @returns The draft endpoint request.
   */
  saveDraftOutlet(
    themeId: number,
    outlet: string,
    baseVersionToken: string | null
  ): Promise<unknown> {
    const resolvedLayout = this.wireframeLayoutQuery.readResolvedLayout(outlet);
    const layout = serializeLayoutForSave(resolvedLayout ?? []);

    // A null resolved read means the read path failed, not a deliberate empty
    // layout; refuse so we don't persist a draft of nothing.
    if (layout.length === 0 && resolvedLayout == null) {
      throw new Error(
        `Refusing to draft outlet "${outlet}": resolved layout was empty/unreadable`
      );
    }

    // TODO(devxp-typescript-pending): remove this response cast once core's
    // `ajax` helper exposes a generic response type.
    return ajax(DRAFTS_URL, {
      type: "POST",
      data: {
        theme_id: themeId,
        outlet_name: outlet,
        layout_json: JSON.stringify({ schema_version: SCHEMA_VERSION, layout }),
        base_version_token: baseVersionToken,
      },
    }) as Promise<unknown>;
  }
}
