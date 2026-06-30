// @ts-check
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service from "@ember/service";
import {
  readBoolStorage,
  writeBoolStorage,
} from "discourse/plugins/discourse-wireframe/discourse/lib/storage";

const COLLAPSED_KEY = "ve.leftCollapsed";

/**
 * Owns the editor's left-rail UI state — which panel is showing and whether the
 * rail is collapsed — so any part of the editor can read or drive it without a
 * line to the shell component. The shell binds its rail chrome to this service;
 * detached UI (the quick-inserter's "Browse all", which lives in a FloatKit
 * portal) calls `showPalette()` directly.
 *
 * The collapse preference is persisted; the active panel is session state. A
 * later phase that adds more rail panels (layers, issues, …) extends this owner.
 */
export default class WireframeRail extends Service {
  /** The active left-rail panel: "palette" | "outline". */
  @tracked leftPanelTab = "palette";

  @tracked leftCollapsed = readBoolStorage(COLLAPSED_KEY);

  /**
   * @param {string} tab
   * @returns {boolean}
   */
  isLeftPanelTabActive = (tab) => this.leftPanelTab === tab;

  @action
  setLeftPanelTab(tab) {
    this.leftPanelTab = tab;
  }

  @action
  toggleLeftCollapsed() {
    this.leftCollapsed = !this.leftCollapsed;
    writeBoolStorage(COLLAPSED_KEY, this.leftCollapsed);
  }

  /**
   * Reveals the palette: switches to its tab and expands the rail if collapsed.
   */
  @action
  showPalette() {
    this.leftPanelTab = "palette";
    if (this.leftCollapsed) {
      this.leftCollapsed = false;
      writeBoolStorage(COLLAPSED_KEY, false);
    }
  }
}
