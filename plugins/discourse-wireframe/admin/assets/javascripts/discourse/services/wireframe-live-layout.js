// @ts-check
import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import {
  _clearLayoutLayer,
  _setLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import { ajax } from "discourse/lib/ajax";
import PreloadStore from "discourse/lib/preload-store";
import { downloadJson as triggerJsonDownload } from "../lib/download-json";
import {
  cloneLayoutForDraft,
  serializeLayoutForSave,
} from "../lib/mutate-layout";

const SCHEMA_VERSION = 1;

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
  @service wireframeDrafts;
  @service wireframeMutationEngine;
  @service wireframeLayoutQuery;
  @service wireframePublishTarget;

  /** `${themeId}:${outlet}` -> last-observed live version token. */
  #versionTokens = new Map();

  #tokensSeeded = false;

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
   * @param {number} [fallbackThemeId] - publish target for outlets nothing owns yet.
   * @returns {Promise<{saved: Array<{outlet: string, themeId: number}>, errors: Array<{outlet: string, themeId: number, message: string, conflict: boolean, currentVersion: (string|undefined), publishedAt: (string|undefined)}>, skipped: Array<{outlet: string, themeId: number, reason: string}>}>}
   */
  async publish(fallbackThemeId) {
    const result = { saved: [], errors: [], skipped: [] };
    for (const outlet of this.wireframeMutationEngine.editedOutletNames()) {
      await this.#publishOne(outlet, fallbackThemeId, result);
    }
    return result;
  }

  /**
   * Publishes a single outlet to its owner theme — the per-outlet Publish
   * affordance. Same per-outlet logic as the `publish` loop.
   *
   * @param {string} outlet - the outlet identifier.
   * @param {number} [fallbackThemeId] - target when nothing owns the outlet yet.
   * @returns {Promise<{saved: Array<Object>, errors: Array<Object>, skipped: Array<Object>}>}
   */
  async publishOutlet(outlet, fallbackThemeId) {
    const result = { saved: [], errors: [], skipped: [] };
    await this.#publishOne(outlet, fallbackThemeId, result);
    return result;
  }

  /**
   * Re-publishes an outlet against the server's current version, intentionally
   * overwriting a concurrent change — the "Overwrite" path of the conflict
   * prompt. The token comes from the 409 response, so the guard now matches.
   *
   * @param {string} outlet - the outlet identifier.
   * @param {number} themeId - the owner theme id.
   * @param {string} currentVersion - the live token from the 409 response.
   * @returns {Promise<boolean>} true on success.
   */
  async overwriteOutlet(outlet, themeId, currentVersion) {
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
   * @param {number} themeId - the id of the theme owning the outlet.
   * @param {string} outlet - the outlet identifier.
   * @returns {Promise<void>}
   */
  async resetToDefault(themeId, outlet) {
    await ajax("/admin/customize/block-layouts.json", {
      type: "DELETE",
      data: { theme_id: themeId, outlet_name: outlet },
    });
    _clearLayoutLayer(outlet, LAYOUT_LAYERS.THEME, { themeId });
    this.#versionTokens.delete(this.#tokenKey(themeId, outlet));
  }

  async #publishOne(outlet, fallbackThemeId, result) {
    const owner = this.wireframePublishTarget.outletOwner(outlet);
    const themeId =
      owner.themeId ??
      fallbackThemeId ??
      this.wireframePublishTarget.defaultThemeId;

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
      const conflict = error?.jqXHR?.status === 409;
      const body = error?.jqXHR?.responseJSON;
      result.errors.push({
        outlet,
        themeId,
        message: this.#extractErrorMessage(error),
        conflict,
        currentVersion: conflict ? body?.current_version : undefined,
        publishedAt: conflict ? body?.published_at : undefined,
      });
      // Keep a conflicted (or failed) outlet in `editedOutlets` so the edit
      // isn't lost; the caller surfaces the conflict prompt.
    }
  }

  // Shared success path: collapse the just-published draft into the theme layer,
  // capture the new live token, clear the outlet from the edited set, and drop
  // the now-redundant persisted draft (a failed cleanup is harmless).
  async #afterPublishSuccess(outlet, themeId, versionToken) {
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
   * @param {number} themeId - the id of the theme owning the outlet.
   * @param {string} outlet - the outlet identifier.
   * @param {object} [options]
   * @param {boolean} [options.useDraft] - export the current draft instead of the live field.
   * @returns {Promise<void>}
   */
  async exportOutlet(themeId, outlet, { useDraft } = {}) {
    const data = { theme_id: themeId, outlet_name: outlet };
    if (useDraft) {
      data.layout_json = this.#serializeLayoutJson(outlet);
    }
    const response = await ajax("/admin/customize/block-layouts/export.json", {
      type: "POST",
      data,
    });
    // `content` is already a serialized JSON string — download it verbatim.
    this._triggerDownload(response.filename, response.content);
  }

  /**
   * Duplicates the theme into a new editable (non-Git) theme, carrying every
   * edited outlet's draft, and returns the new theme id.
   *
   * @param {number} themeId - the id of the source theme.
   * @returns {Promise<{theme_id: number}>}
   */
  duplicateTheme(themeId) {
    return ajax("/admin/customize/block-layouts/duplicate.json", {
      type: "POST",
      data: { theme_id: themeId, drafts: this.#editedDrafts() },
    });
  }

  /**
   * Creates (or reuses) a local customization component for a Git theme,
   * carrying every edited outlet's draft, and returns the component's theme id.
   *
   * @param {number} themeId - the id of the parent theme being customized.
   * @returns {Promise<{theme_id: number}>}
   */
  createCustomizationComponent(themeId) {
    // Companion creation + its parent↔component mapping is an editor concept, so it
    // lives on the plugin endpoint rather than the core block-layouts controller.
    return ajax("/admin/plugins/wireframe/customization-component.json", {
      type: "POST",
      data: { theme_id: themeId, drafts: this.#editedDrafts() },
    });
  }

  #publishRequest(outlet, themeId, expectedToken) {
    return ajax("/admin/customize/block-layouts.json", {
      type: "POST",
      data: {
        theme_id: themeId,
        outlet_name: outlet,
        layout_json: this.#serializeLayoutJson(outlet),
        expected_version_token: expectedToken,
      },
    });
  }

  // Serializes an outlet's resolved layout to the wire `layout_json` string. A
  // null resolved read means the read path failed, not a deliberate "delete
  // all" (which resolves to a real empty array) — throw so a caller never
  // persists/exports nothing over the server's copy.
  #serializeLayoutJson(outlet) {
    const resolvedLayout = this.wireframeLayoutQuery.readResolvedLayout(outlet);
    const layout = serializeLayoutForSave(resolvedLayout ?? []);
    if (layout.length === 0 && resolvedLayout == null) {
      throw new Error(
        `Refusing to serialize outlet "${outlet}": resolved layout was empty/unreadable`
      );
    }
    return JSON.stringify({ schema_version: SCHEMA_VERSION, layout });
  }

  // The edited outlets as `{ outlet_name, layout_json }` rows for the duplicate
  // / customization-component endpoints, so no in-session edit is lost.
  #editedDrafts() {
    return this.wireframeMutationEngine.editedOutletNames().map((outlet) => ({
      outlet_name: outlet,
      layout_json: this.#serializeLayoutJson(outlet),
    }));
  }

  // Collapses the just-published session draft into the `theme` layer, keyed by
  // the theme that was published to. The session-draft layer still wins while
  // the editor is active, so this is invisible until exit/reload (or another
  // tab via MessageBus). Cloned + permissive so a partial "save anyway" state
  // round-trips without re-throwing on exit.
  #publishToThemeLayer(outlet, themeId) {
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

  #tokenKey(themeId, outlet) {
    return `${themeId}:${outlet}`;
  }

  /**
   * The baseline token for an outlet: this tab's last-observed live version.
   * Seeded once from the boot preload; an outlet with no live field resolves to
   * `""` (an empty token matches an absent field, so a first publish succeeds
   * yet still 409s if another admin created the field meanwhile). Public so the
   * drafts service can stamp a draft's `base_version_token`.
   *
   * @param {number} themeId - the id of the theme owning the outlet.
   * @param {string} outlet - the outlet identifier.
   * @returns {string} the last-observed live version token, or `""`.
   */
  tokenFor(themeId, outlet) {
    this.#seedTokens();
    return this.#versionTokens.get(this.#tokenKey(themeId, outlet)) ?? "";
  }

  #setToken(themeId, outlet, token) {
    if (token == null) {
      return;
    }
    this.#versionTokens.set(this.#tokenKey(themeId, outlet), token);
  }

  #seedTokens() {
    if (this.#tokensSeeded) {
      return;
    }
    this.#tokensSeeded = true;
    const rows = PreloadStore.get("themeBlockLayouts");
    if (!Array.isArray(rows)) {
      return;
    }
    for (const row of rows) {
      if (row?.version_token != null) {
        this.#versionTokens.set(
          this.#tokenKey(row.theme_id, row.outlet),
          row.version_token
        );
      }
    }
  }

  #extractErrorMessage(error) {
    const body = error?.jqXHR?.responseJSON;
    if (body?.errors?.length) {
      return body.errors.join(", ");
    }
    return error?.message ?? "Save failed";
  }

  // Thin seam over the download helper so tests can assert the download without
  // poking the DOM. (Underscore-prefixed: internal + stubbed only from tests.)
  _triggerDownload(filename, content) {
    triggerJsonDownload(filename, content);
  }
}
