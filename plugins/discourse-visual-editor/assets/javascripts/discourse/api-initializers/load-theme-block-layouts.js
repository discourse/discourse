// @ts-check
import { apiInitializer } from "discourse/lib/api";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import PreloadStore from "discourse/lib/preload-store";

/**
 * Iterates every `{ theme_id, outlet, layout }` row in the supplied list and
 * publishes the layout to the block-outlet system's `theme` layer via
 * `api.setLayoutLayer`. Each failure is logged but doesn't halt the others —
 * a single bad theme-shipped layout shouldn't break the rest of the page.
 *
 * Publishes with `lazy: true`, which defers layout validation to the
 * moment `BlockOutlet` first reads the entry at render time — by then,
 * every other initializer (including theme api-initializers that
 * register blocks as a side-effect of `api.renderBlocks(class-ref)`)
 * has settled, so string-ref lookups in the JSON-loaded layouts
 * resolve cleanly. With eager validation we'd race those initializers
 * and reject before the registry was ready.
 *
 * Exported separately from the `apiInitializer` callback so it can be unit-
 * tested without going through the full app-boot machinery.
 *
 * @param {import("discourse/lib/plugin-api").default} api
 * @param {Array<{theme_id: number, outlet: string, layout: Array<Object>}>} layouts
 */
export function hydrateThemeBlockLayouts(api, layouts) {
  if (!Array.isArray(layouts) || layouts.length === 0) {
    return;
  }

  for (const row of layouts) {
    const { theme_id: themeId, outlet, layout } = row;
    if (!themeId || !outlet || !Array.isArray(layout)) {
      continue;
    }

    try {
      api.setLayoutLayer(outlet, api.LAYOUT_LAYERS.THEME, layout, {
        themeId,
        lazy: true,
      });
    } catch (error) {
      // Surface the failure in the console without breaking the rest of
      // the boot. A bad theme-shipped layout shouldn't take down the page;
      // the underlying code-default layer (if any) is still rendered by
      // the resolution chain.
      // eslint-disable-next-line no-console
      console.error(
        `[visual-editor] Failed to hydrate ${outlet} from theme ${themeId}:`,
        error
      );
    }
  }
}

/**
 * Subscribes to the per-theme MessageBus channel that
 * `Themes::SaveBlockLayout` publishes to whenever a `block_layout` field is
 * saved. Each message carries `{ outlet, layout, schema_version, theme_id }`
 * for one outlet on one theme; we re-publish it via `api.setLayoutLayer`
 * exactly as if the boot-time hydration had loaded it. That keeps the
 * canvas in sync across browser tabs (and other admins) without a page
 * reload.
 *
 * @param {import("discourse/lib/plugin-api").default} api
 * @param {number[]} themeIds - the ids of every theme currently in the
 *   active stack. We subscribe per id; foreign-theme messages are filtered
 *   out at the channel level.
 */
export function subscribeToBlockLayoutUpdates(api, themeIds) {
  const messageBus = getOwnerWithFallback().lookup("service:message-bus");
  if (!messageBus || !Array.isArray(themeIds)) {
    return;
  }
  for (const themeId of themeIds) {
    if (!themeId) {
      continue;
    }
    messageBus.subscribe(`/block-layouts/${themeId}`, (data) => {
      if (!data || data.theme_id !== themeId || !data.outlet) {
        return;
      }
      hydrateThemeBlockLayouts(api, [
        {
          theme_id: data.theme_id,
          outlet: data.outlet,
          layout: data.layout,
          schema_version: data.schema_version,
        },
      ]);
    });
  }
}

/**
 * Boot-time hydration of the block-outlet layout system's `theme` layer.
 *
 * The Rails preloader (`ApplicationLayoutPreloader#theme_block_layouts_json`)
 * exposes a flat list of `{ theme_id, outlet, schema_version, layout }` rows
 * — one per `block_layout` ThemeField on every theme in the active stack,
 * already ordered by stack position. We hand that list to
 * `hydrateThemeBlockLayouts`, which calls `api.setLayoutLayer(outlet, "theme",
 * layout, { themeId, lazy: true })` for each.
 *
 * Publishing in stack order means each outlet's `theme` layer array ends
 * up with the last theme in the stack at the tail — which the resolution
 * chain treats as the winner. Validation is deferred to first render
 * (`lazy: true`), so it doesn't matter whether this initializer runs
 * before or after a theme api-initializer that registers blocks via
 * `api.renderBlocks(class-ref)`.
 *
 * Once the initial hydration is in place we also subscribe to the
 * `/block-layouts/<theme_id>` MessageBus channels for every theme that ships
 * at least one layout. Saves from other tabs (or other admins) push their
 * updates into the `theme` layer as they arrive, no page reload needed.
 */
export default apiInitializer((api) => {
  const layouts = PreloadStore.get("themeBlockLayouts");
  hydrateThemeBlockLayouts(api, layouts);

  if (Array.isArray(layouts) && layouts.length > 0) {
    const themeIds = [...new Set(layouts.map((row) => row.theme_id))].filter(
      Boolean
    );
    subscribeToBlockLayoutUpdates(api, themeIds);
  }
});
