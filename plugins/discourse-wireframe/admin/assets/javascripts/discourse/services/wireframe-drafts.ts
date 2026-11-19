import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

const COMPANION_URL = "/admin/plugins/wireframe/companion.json";

/** A named layout of a theme. */
export type Design = {
  /** The layout component's theme ID. */
  id: number;
  /** Name the author gave the layout. */
  name: string;
  /** Whether the layout is the one installed on the theme. */
  active: boolean;
};

type CompanionResponse = {
  /** Installed layout's theme ID, or `null` when none is installed. */
  companion_id: number | null;
  /** The layout the editor opens: the installed one, else the latest saved. */
  current_id?: number | null;
  /** All layouts of the theme. */
  designs?: Design[];
};

/**
 * Looks up a theme's saved layouts (designs): which are available, which one is
 * installed, and which one the editor should open.
 */
export default class WireframeDraftsService extends Service {
  /**
   * Every layout of a theme, which one is installed, and which one the editor
   * should open. Never rejects: a transport error reads as "no layouts".
   *
   * @param themeId - Theme whose layouts should be listed.
   */
  async fetchDesigns(themeId: number): Promise<{
    /** Installed layout's ID, or `null`. */
    installedId: number | null;
    /** The layout to open: the installed one, else the latest saved, or `null`. */
    currentId: number | null;
    /** All layouts of the theme, newest first. */
    designs: Design[];
  }> {
    if (themeId == null) {
      return { installedId: null, currentId: null, designs: [] };
    }
    try {
      // TODO(devxp-typescript-pending): remove this response cast once core's
      // `ajax` helper exposes a generic response type.
      const response = (await ajax(COMPANION_URL, {
        type: "GET",
        data: { theme_id: themeId },
      })) as CompanionResponse;
      return {
        installedId: response?.companion_id ?? null,
        currentId: response?.current_id ?? response?.companion_id ?? null,
        designs: response?.designs ?? [],
      };
    } catch {
      return { installedId: null, currentId: null, designs: [] };
    }
  }
}
