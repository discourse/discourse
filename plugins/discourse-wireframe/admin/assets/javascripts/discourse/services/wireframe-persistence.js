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
import {
  cloneLayoutForDraft,
  serializeLayoutForSave,
} from "../lib/mutate-layout";

const SCHEMA_VERSION = 1;

/**
 * Bridges the editor's in-memory edits and server-side `block_layout`
 * persistence. Exposes the persistence verbs:
 *  - `publish`        — live write + broadcast, guarded by a stale-version 409
 *  - `saveDraft`      — private, never-live per-user draft
 *  - `resetToDefault` — delete the live field (fall back to the underlying layer)
 *  - `discardDraft`   — drop the caller's draft
 *
 * `publish` sends the version token this tab last observed for each outlet so
 * the server can reject a stale publish (another admin changed the live field
 * meanwhile). The baseline token is seeded from the boot preload and advanced
 * only by this tab's own successful publishes — never from MessageBus — so a
 * concurrent publish is detected as a conflict rather than silently adopted.
 */
export default class WireframePersistenceService extends Service {
  @service wireframe;

  /** `${themeId}:${outlet}` -> last-observed live version token. */
  #versionTokens = new Map();

  #tokensSeeded = false;

  /**
   * Publishes every edited outlet to the supplied theme — the live, broadcast
   * write. Sequential by design so a partial failure leaves earlier successes
   * persisted. Each success collapses the session draft into the theme layer
   * (keyed by the requested theme) and clears the outlet from `editedOutlets`;
   * a 409 conflict keeps the outlet edited so the edit isn't lost.
   *
   * @param {number} themeId - the id of the theme the editor is bound to.
   * @returns {Promise<{saved: Array<{outlet: string, themeId: number}>, errors: Array<{outlet: string, message: string, conflict: boolean}>}>}
   */
  async publish(themeId) {
    const result = { saved: [], errors: [] };

    for (const outlet of [...this.wireframe.editedOutlets]) {
      try {
        const response = await this.#publishOutlet(themeId, outlet);
        this.#publishToThemeLayer(outlet, themeId);
        this.#setToken(themeId, outlet, response.version_token);
        this.wireframe.editedOutlets.delete(outlet);
        result.saved.push({ outlet, themeId });
      } catch (error) {
        result.errors.push({
          outlet,
          message: this.#extractErrorMessage(error),
          conflict: error?.jqXHR?.status === 409,
        });
        // Keep a conflicted (or failed) outlet in `editedOutlets` so the edit
        // isn't lost; the conflict-resolution UX lands in a later phase.
      }
    }

    return result;
  }

  /**
   * Saves every edited outlet as a private, never-live draft. No broadcast and
   * no theme-layer collapse — the session draft stays the resolved layer.
   *
   * @param {number} themeId - the id of the theme the editor is bound to.
   * @returns {Promise<{saved: Array<{outlet: string}>, errors: Array<{outlet: string, message: string}>}>}
   */
  async saveDraft(themeId) {
    const result = { saved: [], errors: [] };

    for (const outlet of [...this.wireframe.editedOutlets]) {
      try {
        await this.#saveDraftOutlet(themeId, outlet);
        result.saved.push({ outlet });
      } catch (error) {
        result.errors.push({
          outlet,
          message: this.#extractErrorMessage(error),
        });
      }
    }

    return result;
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

  /**
   * Discards the caller's private draft for an outlet.
   *
   * @param {number} themeId - the id of the theme owning the outlet.
   * @param {string} outlet - the outlet identifier.
   * @returns {Promise<void>}
   */
  async discardDraft(themeId, outlet) {
    await ajax("/admin/plugins/wireframe/block-layout-drafts.json", {
      type: "DELETE",
      data: { theme_id: themeId, outlet_name: outlet },
    });
  }

  #publishOutlet(themeId, outlet) {
    const resolvedLayout = this.wireframe.readResolvedLayout(outlet);
    const layout = serializeLayoutForSave(resolvedLayout ?? []);

    // A null resolved read means the read path failed, not a deliberate
    // "delete all" (which resolves to a real empty array). Refusing the POST
    // preserves the server's copy instead of overwriting it with nothing.
    if (layout.length === 0 && resolvedLayout == null) {
      throw new Error(
        `Refusing to save outlet "${outlet}": resolved layout was empty/unreadable`
      );
    }

    return ajax("/admin/customize/block-layouts.json", {
      type: "POST",
      data: {
        theme_id: themeId,
        outlet_name: outlet,
        layout_json: JSON.stringify({ schema_version: SCHEMA_VERSION, layout }),
        expected_version_token: this.#tokenFor(themeId, outlet),
      },
    });
  }

  #saveDraftOutlet(themeId, outlet) {
    const resolvedLayout = this.wireframe.readResolvedLayout(outlet);
    const layout = serializeLayoutForSave(resolvedLayout ?? []);

    if (layout.length === 0 && resolvedLayout == null) {
      throw new Error(
        `Refusing to draft outlet "${outlet}": resolved layout was empty/unreadable`
      );
    }

    return ajax("/admin/plugins/wireframe/block-layout-drafts.json", {
      type: "POST",
      data: {
        theme_id: themeId,
        outlet_name: outlet,
        layout_json: JSON.stringify({ schema_version: SCHEMA_VERSION, layout }),
        base_version_token: this.#tokenFor(themeId, outlet),
      },
    });
  }

  // Collapses the just-published session draft into the `theme` layer, keyed by
  // the theme that was published to. The session-draft layer still wins while
  // the editor is active, so this is invisible until exit/reload (or another
  // tab via MessageBus). Cloned + permissive so a partial "save anyway" state
  // round-trips without re-throwing on exit.
  #publishToThemeLayer(outlet, themeId) {
    const layout = this.wireframe.readResolvedLayout(outlet);
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

  // The baseline token for an outlet: this tab's last-observed live version.
  // Seeded once from the boot preload; an outlet with no live field resolves to
  // "" (an empty token matches an absent field, so a first publish succeeds yet
  // still 409s if another admin created the field meanwhile).
  #tokenFor(themeId, outlet) {
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
}
