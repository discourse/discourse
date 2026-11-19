import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

/** The URL parameter that previews an unpublished layout on the live page. */
export const PREVIEW_PARAM = "wf_preview";

/**
 * Tracks an unpublished layout an admin is previewing on the live site, outside
 * the editor. Nothing is installed; the layout only renders for this page view.
 */
export default class WireframeDraftPreviewService extends Service {
  /** The previewed layout's theme ID, or null when not previewing. */
  @tracked designId: number | null = null;

  /** The previewed layout's name. */
  @tracked designName = "";

  /** Whether a layout is being previewed. */
  get active(): boolean {
    return this.designId != null;
  }

  /**
   * URL that previews a layout on the live site.
   *
   * @param designId - The layout to preview.
   */
  urlFor(designId: number): string {
    const url = new URL("/", window.location.origin);
    url.searchParams.set(PREVIEW_PARAM, String(designId));
    return url.toString();
  }

  /** Leaves the preview, showing the live site again. */
  exitUrl(): string {
    const url = new URL(window.location.href);
    url.searchParams.delete(PREVIEW_PARAM);
    return url.toString();
  }

  /**
   * Ends the preview once the editor takes over, and drops the parameter from
   * the address so a reload doesn't bring the preview back.
   */
  clear(): void {
    if (!this.active) {
      return;
    }
    this.designId = null;
    window.history.replaceState(window.history.state, "", this.exitUrl());
  }
}
