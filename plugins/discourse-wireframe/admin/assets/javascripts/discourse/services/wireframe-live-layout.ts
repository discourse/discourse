import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import {
  _clearLayoutLayer,
  _setLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import { ajax } from "discourse/lib/ajax";
import PreloadStore from "discourse/lib/preload-store";
import {
  cloneLayoutForDraft,
  serializeLayoutForSave,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import { downloadJson as triggerJsonDownload } from "../lib/download-json";
import type WireframeDraftsService from "./wireframe-drafts";
import type WireframeLayoutQueryService from "./wireframe-layout-query";
import type WireframeMutationEngineService from "./wireframe-mutation-engine";
import type WireframePublishTargetService from "./wireframe-publish-target";

const SCHEMA_VERSION = 1;

/** Outcome of publishing one or more edited outlets. */
export type LiveLayoutPublishResult = {
  /** Outlets successfully written to their destination themes. */
  saved: Array<{
    /** Published outlet identifier. */
    outlet: string;
    /** Destination theme ID. */
    themeId: number;
  }>;
  /** Outlets whose publish request failed. */
  errors: Array<{
    /** Failed outlet identifier. */
    outlet: string;
    /** Attempted destination theme ID. */
    themeId: number;
    /** Human-readable failure message. */
    message: string;
    /** Whether the server rejected a stale version token. */
    conflict: boolean;
    /** Current live version returned for a conflict. */
    currentVersion?: string;
    /** Current live publication timestamp returned for a conflict. */
    publishedAt?: string;
  }>;
  /** Git-owned outlets deliberately left unpublished. */
  skipped: Array<{
    /** Skipped outlet identifier. */
    outlet: string;
    /** Destination theme ID. */
    themeId: number;
    /** Reason the outlet was not written. */
    reason: "git";
  }>;
};

type PublishResponse = {
  /** New live version after a successful publish. */
  version_token: string;
};
type ThemeActionResponse = {
  /** ID of the created or reused theme. */
  theme_id: number;
};
type AjaxError = {
  /** jQuery request wrapper attached to Ajax rejections. */
  jqXHR?: {
    /** HTTP response status. */
    status?: number;
    /** Structured error response returned by the server. */
    responseJSON?: {
      /** Human-readable server errors. */
      errors?: string[];
      /** Current live version returned after a conflict. */
      current_version?: string;
      /** Current live publication timestamp. */
      published_at?: string;
    };
  };
  /** Error message supplied by a thrown value. */
  message?: string;
};

/**
 * Bridges the editor's in-memory edits and the live `block_layout` ThemeField:
 *  - `publish`        — live write + broadcast, guarded by a stale-version 409
 *  - `resetToDefault` — delete the live field (fall back to the underlying layer)
 *
 * It also owns the version-token map — the live version each outlet was last
 * seen at — which the drafts service reads via `tokenFor` to stamp a draft's
 * baseline. `publish` sends the token this tab last observed for each outlet so
 * the server can reject a stale publish (another admin changed the live field
 * meanwhile). The baseline is seeded from the boot preload and advanced only by
 * this tab's own successful publishes — never from MessageBus — so a concurrent
 * publish is detected as a conflict rather than silently adopted.
 *
 * Per-user draft I/O (read / save / delete) lives in the drafts service; this
 * service calls it for post-publish cleanup.
 */
export default class WireframeLiveLayoutService extends Service {
  /** Deletes private drafts after successful publication. */
  @service declare wireframeDrafts: WireframeDraftsService;

  /** Supplies edited outlets and reconciles successful publication. */
  @service declare wireframeMutationEngine: WireframeMutationEngineService;

  /** Reads the currently resolved layout for persistence. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Resolves each outlet's destination theme and ownership metadata. */
  @service declare wireframePublishTarget: WireframePublishTargetService;

  /** `${themeId}:${outlet}` -> last-observed live version token. */
  #versionTokens = new Map<string, string>();

  /** Whether boot-preloaded live tokens have been read. */
  #tokensSeeded: boolean = false;

  /**
   * Publishes every edited outlet to its owner theme — the live, broadcast
   * write. Sequential by design so a partial failure leaves earlier successes
   * persisted. Each outlet resolves its own owner, so a page assembled from
   * several themes publishes each region to the theme that owns it;
   * `fallbackThemeId` is the target only for an outlet nothing owns yet. A
   * Git-owned outlet is skipped (never written) with its draft preserved; a 409
   * conflict keeps the outlet edited and carries the live version for the
   * conflict prompt.
   *
   * @param fallbackThemeId - Publish target for outlets nothing owns yet.
   * @returns Per-outlet successes, failures, and deliberate skips.
   */
  async publish(
    fallbackThemeId?: number | null
  ): Promise<LiveLayoutPublishResult> {
    const result: LiveLayoutPublishResult = {
      saved: [],
      errors: [],
      skipped: [],
    };
    for (const outlet of this.wireframeMutationEngine.editedOutletNames()) {
      await this.#publishOne(outlet, fallbackThemeId, result);
    }
    return result;
  }

  /**
   * Publishes a single outlet to its owner theme — the per-outlet Publish
   * affordance. Same per-outlet logic as the `publish` loop.
   *
   * @param outlet - Outlet identifier.
   * @param fallbackThemeId - Target when nothing owns the outlet yet.
   * @returns Per-outlet success, failure, or deliberate skip.
   */
  async publishOutlet(
    outlet: string,
    fallbackThemeId?: number | null
  ): Promise<LiveLayoutPublishResult> {
    const result: LiveLayoutPublishResult = {
      saved: [],
      errors: [],
      skipped: [],
    };
    await this.#publishOne(outlet, fallbackThemeId, result);
    return result;
  }

  /**
   * Re-publishes an outlet against the server's current version, intentionally
   * overwriting a concurrent change — the "Overwrite" path of the conflict
   * prompt. The token comes from the 409 response, so the guard now matches.
   *
   * @param outlet - Outlet identifier.
   * @param themeId - Owner theme ID.
   * @param currentVersion - Live token from the 409 response.
   * @returns Whether the overwrite succeeded.
   */
  async overwriteOutlet(
    outlet: string,
    themeId: number,
    currentVersion: string
  ): Promise<boolean> {
    try {
      const response = await this.#publishRequest(
        outlet,
        themeId,
        currentVersion
      );
      await this.#afterPublishSuccess(outlet, themeId, response.version_token);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Resets an outlet to its default by deleting the live field, then clears the
   * theme layer locally so the underlying (code) layer resolves.
   *
   * @param themeId - ID of the theme owning the outlet.
   * @param outlet - Outlet identifier.
   */
  async resetToDefault(themeId: number, outlet: string): Promise<void> {
    await ajax("/admin/customize/block-layouts.json", {
      type: "DELETE",
      data: { theme_id: themeId, outlet_name: outlet },
    });
    _clearLayoutLayer(outlet, LAYOUT_LAYERS.THEME, { themeId });
    this.#versionTokens.delete(this.#tokenKey(themeId, outlet));
  }

  /**
   * Publishes one outlet and appends its outcome to an aggregate result.
   *
   * @param outlet - Outlet identifier to publish.
   * @param fallbackThemeId - Destination when the outlet has no owner.
   * @param result - Aggregate result receiving this outlet's outcome.
   */
  async #publishOne(
    outlet: string,
    fallbackThemeId: number | null | undefined,
    result: LiveLayoutPublishResult
  ): Promise<void> {
    const owner = this.wireframePublishTarget.outletOwner(outlet);
    // An active editor session always has an owner, explicit fallback, or
    // default theme target; retain the existing runtime fallback chain.
    const themeId =
      owner.themeId ??
      fallbackThemeId ??
      this.wireframePublishTarget.defaultThemeId!;

    if (owner.isGit) {
      // Never write a Git-managed theme's live field (Export/Duplicate is a
      // later phase); leave the outlet edited and its draft intact so the work
      // isn't lost.
      result.skipped.push({ outlet, themeId, reason: "git" });
      return;
    }

    try {
      const response = await this.#publishRequest(
        outlet,
        themeId,
        this.tokenFor(themeId, outlet)
      );
      await this.#afterPublishSuccess(outlet, themeId, response.version_token);
      result.saved.push({ outlet, themeId });
    } catch (error) {
      // TODO(devxp-typescript-pending): remove once core's `ajax` rejection
      // type exposes the jqXHR response metadata.
      const ajaxError = error as AjaxError;
      const conflict = ajaxError.jqXHR?.status === 409;
      const body = ajaxError.jqXHR?.responseJSON;
      result.errors.push({
        outlet,
        themeId,
        message: this.#extractErrorMessage(ajaxError),
        conflict,
        currentVersion: conflict ? body?.current_version : undefined,
        publishedAt: conflict ? body?.published_at : undefined,
      });
      // Keep a conflicted (or failed) outlet in `editedOutlets` so the edit
      // isn't lost; the caller surfaces the conflict prompt.
    }
  }

  /**
   * Reconciles local layers, version state, and drafts after publication.
   *
   * @param outlet - Published outlet identifier.
   * @param themeId - Destination theme ID.
   * @param versionToken - New live version returned by the server.
   */
  async #afterPublishSuccess(
    outlet: string,
    themeId: number,
    versionToken: string
  ): Promise<void> {
    this.#publishToThemeLayer(outlet, themeId);
    this.#setToken(themeId, outlet, versionToken);
    this.wireframeMutationEngine.markOutletPublished(outlet);
    await this.wireframeDrafts.deleteDraft(themeId, outlet);
  }

  /**
   * Exports a single outlet's layout as the repo-file JSON and triggers a
   * download. With `useDraft`, the current (possibly unpublished) draft is sent
   * as the source; otherwise the server exports the live field.
   *
   * @param themeId - ID of the theme owning the outlet.
   * @param outlet - Outlet identifier.
   * @param options - Export source options.
   * @param options.useDraft - Export the current draft instead of the live field.
   */
  async exportOutlet(
    themeId: number,
    outlet: string,
    {
      useDraft,
    }: {
      /** Whether to export the current draft instead of the live layout. */
      useDraft?: boolean;
    } = {}
  ): Promise<void> {
    const data: {
      /** Serialized draft layout, when requested. */
      layout_json?: string;
      /** The outlet identifier. */
      outlet_name: string;
      /** The owning theme ID. */
      theme_id: number;
    } = { theme_id: themeId, outlet_name: outlet };
    if (useDraft) {
      data.layout_json = this.#serializeLayoutJson(outlet);
    }
    // TODO(devxp-typescript-pending): remove this response cast once core's
    // `ajax` helper exposes a generic response type.
    const response = (await ajax("/admin/customize/block-layouts/export.json", {
      type: "POST",
      data,
    })) as {
      /** Download filename returned by the export endpoint. */
      filename: string;
      /** Serialized layout content returned by the export endpoint. */
      content: string;
    };
    // `content` is already a serialized JSON string — download it verbatim.
    this._triggerDownload(response.filename, response.content);
  }

  /**
   * Duplicates the theme into a new editable (non-Git) theme, carrying every
   * edited outlet's draft, and returns the new theme id.
   *
   * @param themeId - ID of the source theme.
   * @returns Newly created editable theme.
   */
  duplicateTheme(themeId: number): Promise<ThemeActionResponse> {
    // TODO(devxp-typescript-pending): remove this response cast once core's
    // `ajax` helper exposes a generic response type.
    return ajax("/admin/customize/block-layouts/duplicate.json", {
      type: "POST",
      data: { theme_id: themeId, drafts: this.#editedDrafts() },
    }) as Promise<ThemeActionResponse>;
  }

  /**
   * Creates (or reuses) a local customization component for a Git theme,
   * carrying every edited outlet's draft, and returns the component's theme id.
   *
   * @param themeId - ID of the parent theme being customized.
   * @returns Created or reused customization component.
   */
  createCustomizationComponent(themeId: number): Promise<ThemeActionResponse> {
    // Companion creation + its parent↔component mapping is an editor concept, so it
    // lives on the plugin endpoint rather than the core block-layouts controller.
    // TODO(devxp-typescript-pending): remove this response cast once core's
    // `ajax` helper exposes a generic response type.
    return ajax("/admin/plugins/wireframe/customization-component.json", {
      type: "POST",
      data: { theme_id: themeId, drafts: this.#editedDrafts() },
    }) as Promise<ThemeActionResponse>;
  }

  /**
   * Sends one guarded live-layout publish request.
   *
   * @param outlet - Outlet identifier to publish.
   * @param themeId - Destination theme ID.
   * @param expectedToken - Live version this tab expects to replace.
   * @returns Server response carrying the new live version.
   */
  #publishRequest(
    outlet: string,
    themeId: number,
    expectedToken: string
  ): Promise<PublishResponse> {
    // TODO(devxp-typescript-pending): remove this response cast once core's
    // `ajax` helper exposes a generic response type.
    return ajax("/admin/customize/block-layouts.json", {
      type: "POST",
      data: {
        theme_id: themeId,
        outlet_name: outlet,
        layout_json: this.#serializeLayoutJson(outlet),
        expected_version_token: expectedToken,
      },
    }) as Promise<PublishResponse>;
  }

  /**
   * Serializes an outlet's resolved layout to the wire JSON string.
   * A `null` read is a failed lookup rather than a deliberate empty layout, so
   * it throws instead of overwriting the server with no entries.
   *
   * @param outlet - Outlet whose resolved layout should be serialized.
   * @returns Versioned layout JSON accepted by persistence endpoints.
   */
  #serializeLayoutJson(outlet: string): string {
    const resolvedLayout = this.wireframeLayoutQuery.readResolvedLayout(outlet);
    const layout = serializeLayoutForSave(resolvedLayout ?? []);
    if (layout.length === 0 && resolvedLayout == null) {
      throw new Error(
        `Refusing to serialize outlet "${outlet}": resolved layout was empty/unreadable`
      );
    }
    return JSON.stringify({ schema_version: SCHEMA_VERSION, layout });
  }

  /** @returns Edited outlet payloads for theme-creation endpoints. */
  #editedDrafts(): Array<{
    /** Edited outlet identifier. */
    outlet_name: string;
    /** Serialized in-session layout. */
    layout_json: string;
  }> {
    return this.wireframeMutationEngine.editedOutletNames().map((outlet) => ({
      outlet_name: outlet,
      layout_json: this.#serializeLayoutJson(outlet),
    }));
  }

  /**
   * Copies a published draft into its destination theme layer locally.
   * The session draft still wins until exit; cloning permissively preserves a
   * partial save-anyway state without revalidating it during reconciliation.
   *
   * @param outlet - Published outlet identifier.
   * @param themeId - Destination theme ID.
   */
  #publishToThemeLayer(outlet: string, themeId: number): void {
    const layout = this.wireframeLayoutQuery.readResolvedLayout(outlet);
    if (!layout || !themeId) {
      return;
    }
    _setLayoutLayer(
      outlet,
      LAYOUT_LAYERS.THEME,
      cloneLayoutForDraft(layout),
      getOwner(this),
      { themeId, permissive: true }
    );
  }

  /**
   * @param themeId - Theme portion of the token identity.
   * @param outlet - Outlet portion of the token identity.
   * @returns Stable key for the local version-token map.
   */
  #tokenKey(themeId: number, outlet: string): string {
    return `${themeId}:${outlet}`;
  }

  /**
   * The baseline token for an outlet: this tab's last-observed live version.
   * Seeded once from the boot preload; an outlet with no live field resolves to
   * `""` (an empty token matches an absent field, so a first publish succeeds
   * yet still 409s if another admin created the field meanwhile). Public so the
   * drafts service can stamp a draft's `base_version_token`.
   *
   * @param themeId - ID of the theme owning the outlet.
   * @param outlet - Outlet identifier.
   * @returns Last-observed live version token, or `""`.
   */
  tokenFor(themeId: number, outlet: string): string {
    this.#seedTokens();
    return this.#versionTokens.get(this.#tokenKey(themeId, outlet)) ?? "";
  }

  /**
   * Stores a newly observed live version token.
   *
   * @param themeId - Theme owning the live layout.
   * @param outlet - Outlet owning the live layout.
   * @param token - New live version, or `null` when unavailable.
   */
  #setToken(themeId: number, outlet: string, token: string | null): void {
    if (token == null) {
      return;
    }
    this.#versionTokens.set(this.#tokenKey(themeId, outlet), token);
  }

  /** Seeds live version tokens once from the boot preload. */
  #seedTokens(): void {
    if (this.#tokensSeeded) {
      return;
    }
    this.#tokensSeeded = true;
    const rows: unknown = PreloadStore.get("themeBlockLayouts");
    if (!Array.isArray(rows)) {
      return;
    }
    for (const row of rows) {
      // TODO(devxp-typescript-pending): cast the preload rows at the boundary
      // until the preload store exposes a typed schema for these entries.
      const typedRow = row as {
        theme_id: number;
        outlet: string;
        version_token: string | null;
      } | null;
      if (typedRow?.version_token != null) {
        this.#versionTokens.set(
          this.#tokenKey(typedRow.theme_id, typedRow.outlet),
          typedRow.version_token
        );
      }
    }
  }

  /**
   * @param error - Failed Ajax request metadata.
   * @returns Most specific available human-readable error.
   */
  #extractErrorMessage(error: AjaxError): string {
    const body = error.jqXHR?.responseJSON;
    if (body?.errors?.length) {
      return body.errors.join(", ");
    }
    return error.message ?? "Save failed";
  }

  /**
   * Thin seam over the download helper for test observation.
   *
   * @param filename - Suggested downloaded file name.
   * @param content - Serialized JSON file contents.
   */
  _triggerDownload(filename: string, content: string): void {
    triggerJsonDownload(filename, content);
  }
}
