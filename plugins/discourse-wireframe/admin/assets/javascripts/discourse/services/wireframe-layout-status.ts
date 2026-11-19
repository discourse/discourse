import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import type DialogService from "discourse/dialog-holder/services/dialog";
import { i18n } from "discourse-i18n";
import type { BlockChange } from "discourse/plugins/discourse-wireframe/discourse/lib/outlet-change-summary";
import type WireframeLayoutQueryService from "./wireframe-layout-query";
import type WireframeLiveLayoutService from "./wireframe-live-layout";
import type WireframeMutationEngineService from "./wireframe-mutation-engine";
import type WireframePublishPreviewService from "./wireframe-publish-preview";
import type WireframePublishTargetService from "./wireframe-publish-target";
import type WireframeStagingService from "./wireframe-staging";
import type WireframeValidationService from "./wireframe-validation";

/** The layout's publish status. It is separate from whether edits are saved. */
export type LayoutStatus = "draft" | "published";

/** One row of the unsaved-changes list. */
export type ChangeRow = {
  /** The block's display name. */
  name: string;
  /** What happened to it. */
  kind: BlockChange["kind"];
};

const SAVED_NOTICE_MS = 4000;

/**
 * The editor's save and publish state. Two independent pieces:
 *
 * - **Saved or not:** whether the canvas differs from the last saved layout.
 *   Saving writes the layout and never changes the status.
 * - **Status:** `published` when the theme uses this layout (members see its last
 *   saved version), `draft` when it does not. Changing the status never saves.
 */
export default class WireframeLayoutStatusService extends Service {
  @service declare dialog: DialogService;
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;
  @service declare wireframeLiveLayout: WireframeLiveLayoutService;
  @service declare wireframeMutationEngine: WireframeMutationEngineService;
  @service declare wireframePublishPreview: WireframePublishPreviewService;
  @service declare wireframePublishTarget: WireframePublishTargetService;
  @service declare wireframeStaging: WireframeStagingService;
  @service declare wireframeValidation: WireframeValidationService;

  /** An in-flight save or status change. */
  @tracked busy = false;

  /** Message for the last failed save or status change, or null. */
  @tracked error: string | null = null;

  /** Whether a save just finished, to show "Saved just now" briefly. */
  @tracked justSaved = false;

  /**
   * Whether something visitors can see may have changed this session (a save or
   * a status change), so the page reloads when the editor closes.
   */
  @tracked needsReload = false;

  #savedTimer: ReturnType<typeof setTimeout> | undefined;

  willDestroy(): void {
    clearTimeout(this.#savedTimer);
    super.willDestroy();
  }

  get status(): LayoutStatus {
    return this.wireframePublishTarget.hasDesign &&
      this.wireframePublishTarget.designInUse
      ? "published"
      : "draft";
  }

  /** A layout can only go live once it has been saved. */
  get canPublish(): boolean {
    return this.wireframePublishTarget.hasDesign;
  }

  get hasUnsavedChanges(): boolean {
    return this.wireframeMutationEngine.isDirty;
  }

  /** Every unsaved change, one row per block and kind of change. */
  get changes(): ChangeRow[] {
    return this.wireframeMutationEngine
      .editedOutletNames()
      .flatMap((outletName) =>
        this.wireframePublishPreview
          .outletChangeSummary(outletName)
          .changes.map(({ entry, kind }) => ({
            name:
              this.wireframeLayoutQuery.lookupEntryDisplayName(entry) ??
              String(entry.block),
            kind,
          }))
      );
  }

  /**
   * Saves the edited layout. Creates the layout on the first save (as a draft),
   * leaves the status alone, and stays in the editor.
   *
   * @returns A message when saving failed, or null on success.
   */
  async save(): Promise<string | null> {
    if (this.busy) {
      return null;
    }
    if (!this.hasUnsavedChanges) {
      return null;
    }
    if (this.wireframeValidation.hasValidationWarnings) {
      const confirmed = await this.#confirmSaveWithWarnings();
      if (!confirmed) {
        return null;
      }
    }
    this.busy = true;
    this.error = null;
    try {
      if (!this.wireframePublishTarget.hasDesign) {
        const { themeId, error } = await this.wireframeStaging.createDesign(
          this.wireframePublishTarget.designName
        );
        if (!themeId) {
          this.error = error ?? i18n("wireframe.design.create_failed");
          return this.error;
        }
      }
      this.error = await this.wireframeStaging.publishEditedOutlets();
      if (this.error == null) {
        this.needsReload = true;
        this.#flashSaved();
      }
      return this.error;
    } finally {
      this.busy = false;
    }
  }

  /**
   * Makes the layout live or takes it off the homepage. Only the last saved
   * version goes live; unsaved edits stay unsaved.
   *
   * @param next - The status to switch to.
   * @returns A message when it failed, or null on success.
   */
  async setStatus(next: LayoutStatus): Promise<string | null> {
    if (this.busy || next === this.status) {
      return null;
    }
    const designId = this.wireframePublishTarget.activeThemeId;
    const parentId = this.wireframePublishTarget.parentThemeId;
    if (designId == null || parentId == null) {
      return null;
    }
    this.busy = true;
    this.error = null;
    try {
      if (next === "published") {
        this.error = await this.wireframeStaging.switchDesign(designId);
      } else {
        try {
          await this.wireframeLiveLayout.uninstallDesign(parentId);
        } catch {
          this.error = i18n("wireframe.design.switch_failed");
        }
      }
      if (this.error == null) {
        this.wireframePublishTarget.markDesignInUse(
          designId,
          next === "published"
        );
        this.needsReload = true;
      }
      return this.error;
    } finally {
      this.busy = false;
    }
  }

  /** Throws away every unsaved change. */
  async discard(): Promise<void> {
    await this.wireframeStaging.discardAll();
  }

  async #confirmSaveWithWarnings(): Promise<boolean> {
    let confirmed = false;
    await this.dialog.confirm({
      message: i18n("wireframe.chrome.save_with_warnings_confirm", {
        count: this.wireframeValidation.validationWarnings.length,
      }),
      confirmButtonLabel: "wireframe.chrome.save_anyway",
      didConfirm: () => (confirmed = true),
    });
    return confirmed;
  }

  #flashSaved(): void {
    this.justSaved = true;
    // A plain timer: it only fades a notice, so nothing should wait on it.
    clearTimeout(this.#savedTimer);
    this.#savedTimer = setTimeout(() => {
      this.justSaved = false;
    }, SAVED_NOTICE_MS);
  }
}
