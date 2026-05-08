// @ts-check
import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import { _setLayoutLayer, LAYOUT_LAYERS } from "discourse/blocks/block-outlet";
import { ajax } from "discourse/lib/ajax";
import {
  cloneLayoutForDraft,
  serializeLayoutForSave,
} from "../lib/mutate-layout";

const SCHEMA_VERSION = 1;

/**
 * Bridges the editor's in-memory edits and the server-side `block_layout`
 * ThemeField persistence. Phase 3d ships a single endpoint
 * (`POST /admin/customize/block-layouts.json`) that saves one outlet at a
 * time; this service drives it once per edited outlet on save.
 *
 * After a successful save the service publishes the just-saved layout into
 * the `theme` layer too. That update is silent — the session-draft is still
 * resolved while the editor is active, so the canvas doesn't re-render at
 * save time. The fresh theme layer takes over on `exit()` (or in another
 * tab, via the MessageBus subscription).
 */
export default class VisualEditorPersistenceService extends Service {
  @service visualEditor;

  /**
   * Saves every edited outlet to the supplied theme. The save loop is
   * sequential by design — partial failure should leave earlier successes
   * persisted. Each successful save clears that outlet from
   * `_editedOutlets`; cleared snapshot history happens at the call-site
   * (the toolbar's Save handler) so the toolbar can stay in sync with
   * isDirty/canUndo/canRedo.
   *
   * @param {number} themeId - the id of the theme the editor is bound to.
   * @returns {Promise<{
   *   saved: Array<{outlet: string, targetThemeId: number, targetThemeName: string, redirected: boolean, childCreated: boolean}>,
   *   errors: Array<{outlet: string, message: string}>
   * }>}
   */
  async saveAll(themeId) {
    const result = { saved: [], errors: [] };
    const editedOutlets = [...this.visualEditor._editedOutlets];

    for (const outlet of editedOutlets) {
      try {
        const response = await this._saveOutlet(themeId, outlet);
        result.saved.push({
          outlet,
          targetThemeId: response.target_theme_id,
          targetThemeName: response.target_theme_name,
          redirected: response.redirected,
          childCreated: response.child_created,
        });
        this._publishToThemeLayer(outlet, response.target_theme_id);
        this.visualEditor._editedOutlets.delete(outlet);
      } catch (error) {
        result.errors.push({
          outlet,
          message: this._extractErrorMessage(error),
        });
      }
    }

    return result;
  }

  async _saveOutlet(themeId, outlet) {
    const resolvedLayout = this.visualEditor.readResolvedLayout(outlet);
    const layout = serializeLayoutForSave(resolvedLayout ?? []);
    return ajax("/admin/customize/block-layouts.json", {
      type: "POST",
      data: {
        theme_id: themeId,
        outlet_name: outlet,
        layout_json: JSON.stringify({
          schema_version: SCHEMA_VERSION,
          layout,
        }),
      },
    });
  }

  /**
   * Publishes the just-saved layout into the `theme` layer at
   * `targetThemeId`. The session-draft layer stays at the top of the
   * resolution chain while the editor is active, so this update is
   * invisible to the user — until they `exit()`, at which point the draft
   * clears and the theme layer takes over (now showing the saved state).
   *
   * Updates with `targetThemeId` (which can differ from the original theme
   * id when the server redirected to a `<theme-name>-customizations` child)
   * so the layer record matches what the server actually persisted.
   */
  _publishToThemeLayer(outlet, targetThemeId) {
    const layout = this.visualEditor.readResolvedLayout(outlet);
    if (!layout || !targetThemeId) {
      return;
    }
    // Clone so the theme layer's entries don't share `args` with the still-
    // mutable session-draft entries — a future edit shouldn't accidentally
    // bleed through into the "saved" state.
    _setLayoutLayer(
      outlet,
      LAYOUT_LAYERS.THEME,
      cloneLayoutForDraft(layout),
      getOwner(this),
      { themeId: targetThemeId }
    );
  }

  _extractErrorMessage(error) {
    const body = error?.jqXHR?.responseJSON;
    if (body?.errors?.length) {
      return body.errors.join(", ");
    }
    return error?.message ?? "Save failed";
  }
}
