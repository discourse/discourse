import {
  _clearLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import { ajax } from "discourse/lib/ajax";
import type { PluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";
import {
  hydrateThemeBlockLayouts,
  type ThemeBlockLayout,
} from "discourse/plugins/discourse-wireframe/discourse/api-initializers/load-theme-block-layouts";
import type WireframeDraftsService from "../services/wireframe-drafts";
import type WireframeLiveLayoutService from "../services/wireframe-live-layout";
import type WireframePublishTargetService from "../services/wireframe-publish-target";

/** Ranks a previewed design above every theme in the stack, so it wins. */
const PREVIEW_STACK_INDEX = Number.MAX_SAFE_INTEGER;

/** A design and its published layouts, as the design endpoint returns them. */
type DesignDetail = {
  /** The design component's theme ID. */
  id: number;
  /** Name the author gave the design. */
  name: string;
  /** ID of the theme the design belongs to. */
  theme_id: number;
  /** Whether the theme uses the design. */
  active: boolean;
  /** The design's published layouts, with their version tokens. */
  layouts: Array<
    ThemeBlockLayout & {
      /** Live version of the layout. */
      version_token: string | null;
    }
  >;
};

/** The services a preview updates. */
type PreviewServices = {
  /** Finds the design the theme uses. */
  drafts: WireframeDraftsService;
  /** Records the previewed layouts' version tokens. */
  liveLayout: WireframeLiveLayoutService;
  /** Records the design so the session can publish to it. */
  publishTarget: WireframePublishTargetService;
};

/**
 * Whether a theme is part of the stack the page rendered, i.e. its layouts are
 * already loaded.
 *
 * @param themeId - Theme to look for.
 */
export function isInRenderedStack(themeId: number): boolean {
  // TODO(devxp-typescript-pending): remove this preload boundary cast once
  // core exposes a typed registry for `PreloadStore` keys.
  const meta = PreloadStore.get("themeBlockLayoutMeta") as
    | Record<string, unknown>
    | undefined;
  return meta?.[String(themeId)] != null;
}

/**
 * Loads a design the theme doesn't use into the page, so the editor can open
 * on it: the design the theme uses steps aside and the previewed design's
 * layouts render in its place. Only the editing session sees this; nothing is
 * installed until the author chooses to use the design.
 *
 * @param api - Plugin API used to publish the layouts.
 * @param designId - The design to preview.
 * @param services - The services the preview updates.
 * @returns Whether the design could be loaded.
 */
export async function previewDesign(
  api: PluginApi,
  designId: number,
  { drafts, liveLayout, publishTarget }: PreviewServices
): Promise<boolean> {
  let detail: DesignDetail;
  try {
    // TODO(devxp-typescript-pending): remove this response cast once core's
    // `ajax` helper exposes a generic response type.
    detail = (await ajax(
      `/admin/plugins/wireframe/designs/${designId}.json`
    )) as DesignDetail;
  } catch {
    return false;
  }

  const { installedId } = await drafts.fetchDesigns(detail.theme_id);
  if (installedId != null && installedId !== designId) {
    for (const outlet of loadedOutletsFor(installedId)) {
      _clearLayoutLayer(outlet, LAYOUT_LAYERS.THEME, { themeId: installedId });
    }
  }

  hydrateThemeBlockLayouts(api, detail.layouts, {
    [String(designId)]: { stack_index: PREVIEW_STACK_INDEX },
  });
  liveLayout.recordVersionTokens(detail.layouts);
  publishTarget.registerDesign(designId, detail.name, {
    inUse: detail.active,
  });
  return true;
}

/**
 * The outlets the boot preload loaded a layout for, from one theme.
 *
 * @param themeId - Theme whose outlets to list.
 */
function loadedOutletsFor(themeId: number): string[] {
  const rows: unknown = PreloadStore.get("themeBlockLayouts");
  if (!Array.isArray(rows)) {
    return [];
  }
  return (rows as ThemeBlockLayout[])
    .filter((row) => row?.theme_id === themeId)
    .map((row) => row.outlet);
}
