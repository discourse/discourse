import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { type ModifierLike } from "@glint/template";
import type DialogService from "discourse/dialog-holder/services/dialog";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import type SiteSettingsService from "discourse/services/site-settings";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DTabs from "discourse/ui-kit/d-tabs";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dCloseOnClickOutsideUntyped from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import { i18n } from "discourse-i18n";
import { HOMEPAGE_OUTLET } from "discourse/plugins/discourse-wireframe/discourse/lib/editor-outlets";
import type WireframeEditModeService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-edit-mode";
import WireframeLayoutQueryService, {
  OUTLET_STATE,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeMutationEngineService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-mutation-engine";
import type WireframePublishPreviewService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-publish-preview";
import type WireframePublishTargetService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-publish-target";
import type WireframeStagingService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-staging";
import type WireframeValidationService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-validation";
import type WireframeWorkspaceService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-workspace";

// TODO(devxp-typescript-pending): drop once d-close-on-click-outside is authored
// in .ts with a real Signature. Its DefaultSignature rejects the positional
// close callback plus the options hash, so its positional contract is declared
// here.
const dCloseOnClickOutside =
  dCloseOnClickOutsideUntyped as unknown as ModifierLike<{
    /** Drawer element monitored for outside clicks. */
    Element: HTMLElement;
    /** Outside-click callback and exclusions. */
    Args: {
      /** Positional outside-click configuration. */
      Positional: [
        /** Callback invoked after an outside click. */
        close: () => void,
        /** Optional elements excluded from outside-click handling. */
        options?: {
          /** Primary excluded element selector. */
          targetSelector?: string;
          /** Secondary excluded element selector. */
          secondaryTargetSelector?: string;
          /** Explicit excluded element. */
          target?: Element;
        },
      ];
    };
  }>;

// TODO(devxp-typescript-pending): replace this local augmentation once core
// exposes a typed extension mechanism for plugin site settings.
interface WireframeSiteSettings extends SiteSettingsService {
  /** Whether the rendered theme uses the blocks homepage. Absent (undefined)
   * when the rendered theme has no entry in the themeable-settings map. */
  wireframe_custom_homepage?: boolean;
}

/**
 * The save-and-publish review surface: a right-docked drawer that consolidates
 * everything about committing edits. Its Details tab names the design the edits
 * will land on (or notes that one is created on first publish) and lists the
 * edited outlets. Its Changes tab summarises, per outlet, how the edited layout
 * differs from what is live, with an optional raw-layout view.
 *
 * Opened from the toolbar Save button and the design indicator; both flip
 * `wireframeStaging.reviewDrawerOpen`. Mounted once at the shell level so it
 * survives tab switches. Save/publish/discard all live here — the toolbar carries
 * only the button that opens the drawer.
 */
export default class PublishReviewDrawer extends Component {
  @service declare wireframeWorkspace: WireframeWorkspaceService;
  @service declare dialog: DialogService;
  @service declare siteSettings: WireframeSiteSettings;
  @service declare wireframeMutationEngine: WireframeMutationEngineService;
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;
  @service declare wireframePublishPreview: WireframePublishPreviewService;
  @service declare wireframeEditMode: WireframeEditModeService;
  @service declare wireframeStaging: WireframeStagingService;
  @service declare wireframePublishTarget: WireframePublishTargetService;
  @service declare wireframeValidation: WireframeValidationService;

  /** In-flight save or publish; disables the action buttons while awaiting. */
  @tracked isSaving = false;

  /** Banner message for a failed save/publish, or null. */
  @tracked saveError: string | null = null;

  @tracked activeTab = "details";

  isRawExpanded = (outletName: string) => this.#expandedRaw.has(outletName);
  outletState = (outletName: string) =>
    this.wireframeLayoutQuery.outletState(outletName);
  summaryFor = (outletName: string) =>
    this.wireframePublishPreview.outletChangeSummary(outletName);
  layoutJsonFor = (outletName: string) =>
    this.wireframePublishPreview.outletLayoutJson(outletName);
  isOutletPublished = (outletName: string) =>
    this.wireframeLayoutQuery.outletState(outletName) ===
    OUTLET_STATE.PUBLISHED;

  /** Outlets whose raw-layout view is expanded on the Changes tab. */
  #expandedRaw = trackedSet<string>();

  get isOpen() {
    return (
      this.wireframeEditMode.active && this.wireframeStaging.reviewDrawerOpen
    );
  }

  /** The edited outlets grouped by owner theme — the publish plan. */
  get targets() {
    return this.wireframePublishTarget.publishTargets;
  }

  /** A flat list of every edited outlet, for the Changes tab. */
  get editedOutlets() {
    return this.targets.flatMap((group) => group.outlets);
  }

  /** Whether Save draft is available (unsaved edits exist and nothing is in flight). */
  get canSaveDraft() {
    return (
      !this.isSaving &&
      this.wireframeStaging.hasUnsavedDraftEdits &&
      this.wireframePublishTarget.activeThemeId != null
    );
  }

  /** Whether Publish is available (something to commit and nothing in flight). */
  get canPublish() {
    return !this.isSaving && this.targets.length > 0;
  }

  /** Whether the homepage layout that publish would write renders anything. */
  get canEnableHomepage() {
    return this.wireframeLayoutQuery.hasRenderableContent(HOMEPAGE_OUTLET);
  }

  @action
  setTab(tab: string) {
    this.activeTab = tab;
  }

  @action
  close() {
    this.wireframeStaging.closeReviewDrawer();
  }

  @action
  toggleRaw(outletName: string) {
    if (this.#expandedRaw.has(outletName)) {
      this.#expandedRaw.delete(outletName);
    } else {
      this.#expandedRaw.add(outletName);
    }
  }

  @action
  discardAll() {
    this.wireframeStaging.discardAll();
  }

  @action
  saveDrafts() {
    if (!this.canSaveDraft) {
      return;
    }
    this.#performSaveDrafts();
  }

  @action
  publish() {
    if (!this.canPublish) {
      return;
    }
    if (this.wireframeValidation.hasValidationWarnings) {
      // Publishing goes live, so an invalid (mid-edit) layout shouldn't ship by
      // accident — confirm first. Save draft skips this; a draft is private.
      this.dialog.confirm({
        message: i18n("wireframe.chrome.publish_with_warnings_confirm", {
          count: this.wireframeValidation.validationWarnings.length,
        }),
        confirmButtonLabel: "wireframe.chrome.publish_anyway",
        didConfirm: () => this.#performPublish(),
      });
      return;
    }
    this.#performPublish();
  }

  @action
  confirmReset(outletName: string) {
    // Reset deletes the live ThemeField and is NOT undoable, so confirm first.
    this.dialog.confirm({
      title: i18n("wireframe.outlet.reset_confirm_title"),
      message: i18n("wireframe.outlet.reset_confirm_message"),
      confirmButtonLabel: "wireframe.outlet.reset_confirm_button",
      didConfirm: () => this.wireframeStaging.resetToDefault(outletName),
    });
  }

  async #performSaveDrafts() {
    this.isSaving = true;
    this.saveError = null;
    try {
      this.saveError = await this.wireframeStaging.saveAllEditedDrafts();
    } finally {
      this.isSaving = false;
    }
  }

  async #performPublish() {
    this.isSaving = true;
    this.saveError = null;
    let previewed = false;
    try {
      if (this.targets.length > 0 && !this.wireframePublishTarget.hasDesign) {
        this.saveError = await this.#createDesignForPublish();
        if (this.saveError != null) {
          return;
        }
      }
      let useDesign = false;
      if (
        this.wireframePublishTarget.hasDesign &&
        !this.wireframePublishTarget.designInUse
      ) {
        const choice = await this.#askToUseDesign();
        if (choice == null) {
          return;
        }
        previewed = true;
        useDesign = choice === "use";
      }
      // The service owns the per-outlet owner targeting, the stale-version
      // conflict prompt, and the edit-state reconciliation; a banner string comes
      // back for any non-conflict error, or null on success.
      this.saveError = await this.wireframeStaging.publishEditedOutlets();
      if (this.saveError == null && useDesign) {
        this.saveError = await this.#useDesign();
      }
      if (this.saveError == null && this.wireframePublishTarget.designInUse) {
        this.saveError = await this.#enableHomepage();
      }
    } finally {
      this.isSaving = false;
    }
    // A clean publish is the end of the editing session — leave the editor so the
    // author lands back on the live page showing what they just published. On a
    // failure the banner stays and the drawer stays open to retry: re-running the
    // layout publish with everything already saved is a no-op, so a retry after a
    // failed homepage write is safe.
    if (this.saveError == null) {
      this.wireframeWorkspace.exit();
      // A previewed design's layouts are only on this page; reload so it shows
      // what visitors see.
      if (previewed) {
        this.wireframePublishTarget.navigateToThemeInUse();
      }
    }
  }

  /**
   * Asks whether a design the theme doesn't use yet should be used once it's
   * published.
   *
   * @returns `"use"`, `"publish"` to publish without using it, or null when
   *   the author backs out.
   */
  async #askToUseDesign(): Promise<"use" | "publish" | null> {
    let choice: "use" | "publish" | null = null;
    await this.dialog.alert({
      title: i18n("wireframe.design.use_prompt_title"),
      message: i18n("wireframe.design.use_prompt_message", {
        name: this.wireframePublishTarget.designName,
      }),
      buttons: [
        {
          label: i18n("wireframe.design.use_prompt_use"),
          class: "btn-primary wireframe-use-design__use",
          action: () => (choice = "use"),
        },
        {
          label: i18n("wireframe.design.use_prompt_publish_only"),
          class: "btn-default wireframe-use-design__publish-only",
          action: () => (choice = "publish"),
        },
        {
          label: i18n("cancel"),
          class: "btn-flat wireframe-use-design__cancel",
        },
      ],
    });
    return choice;
  }

  /**
   * Makes the session's design the one its theme uses.
   *
   * @returns A banner message when that failed, or null.
   */
  async #useDesign(): Promise<string | null> {
    const designId = this.wireframePublishTarget.activeThemeId;
    if (designId == null) {
      return null;
    }
    const error = await this.wireframeStaging.switchDesign(designId);
    if (error == null) {
      this.wireframePublishTarget.markDesignInUse(designId);
    }
    return error;
  }

  /**
   * Switches the custom homepage on for the theme in use once the homepage
   * layout has been published with something to show, so publishing a homepage is
   * all it takes for visitors to see it. Re-validated at apply time: the drawer
   * survives SPA navigation, and a publish that returned cleanly can still have
   * left the homepage outlet unpublished (a version conflict the author
   * cancelled).
   *
   * @returns A banner message when the write failed, or null when it was applied
   *   or there was nothing to do.
   */
  async #enableHomepage(): Promise<string | null> {
    const themeId = this.wireframePublishTarget.homepageThemeId;
    if (
      themeId == null ||
      !this.wireframePublishTarget.homepageToggleAvailable ||
      this.siteSettings.wireframe_custom_homepage === true ||
      this.wireframeMutationEngine
        .editedOutletNames()
        .includes(HOMEPAGE_OUTLET) ||
      !this.canEnableHomepage
    ) {
      return null;
    }
    try {
      await ajax(`/admin/themes/${themeId}/site-setting`, {
        type: "PUT",
        data: { name: "wireframe_custom_homepage", value: true },
      });
    } catch (error) {
      return extractError(error, i18n("generic_error"));
    }
    // Mirror what the MessageBus subscriber would apply, so the session doesn't
    // depend on the echo arriving before teardown.
    this.siteSettings.wireframe_custom_homepage = true;
    return null;
  }

  /**
   * Creates the design the edits will publish to, named by the header title (or
   * its placeholder). On success the session is bound to it, so the publish that
   * follows writes there.
   *
   * @returns A banner message when the design couldn't be created, or null.
   */
  async #createDesignForPublish(): Promise<string | null> {
    const name = this.wireframePublishTarget.designName;
    const { themeId, error } = await this.wireframeStaging.createDesign(name);
    return themeId ? null : (error ?? i18n("wireframe.design.create_failed"));
  }

  <template>
    {{#if this.isOpen}}
      <div
        aria-label={{i18n "wireframe.review.title"}}
        class="wireframe-review wireframe-editor-overlay"
        role="dialog"
        {{! Clicking anywhere outside the drawer closes it; the toolbar Save
            button and target indicator that open it are excluded so re-clicking
            them doesn't close-then-reopen. }}
        {{dCloseOnClickOutside
          this.close
          (hash
            targetSelector=".wireframe-btn-save"
            secondaryTargetSelector=".wireframe-target-indicator"
          )
        }}
      >
        <div class="wireframe-review__header">
          <span class="wireframe-review__title">
            {{dIcon "cloud-arrow-up"}}
            <span>{{i18n "wireframe.review.title"}}</span>
          </span>
          <DButton
            class="btn-flat wireframe-review__close"
            @action={{this.close}}
            @ariaLabel="wireframe.review.close"
            @icon="xmark"
          />
        </div>

        <DTabs
          class="wireframe-review__sections"
          @active={{this.activeTab}}
          @label={{i18n "wireframe.review.title"}}
          @onActivate={{this.setTab}}
          as |tabs|
        >
          <tabs.Tab
            class="wireframe-review__tab"
            @key="details"
            @label={{i18n "wireframe.review.tab_details"}}
          >
            {{#each this.targets as |group|}}
              <section class="wireframe-review__group">
                <div class="wireframe-review__group-header">
                  <span class="wireframe-review__group-theme">
                    {{dIcon "paintbrush"}}
                    {{#if group.publishable}}
                      {{group.themeName}}
                    {{else}}
                      {{this.wireframePublishTarget.designName}}
                    {{/if}}
                  </span>
                  <span
                    class={{dConcatClass
                      "wireframe-review__group-status"
                      (if group.publishable "--ok" "--pending")
                    }}
                  >
                    {{#if group.publishable}}
                      {{i18n "wireframe.review.target_publishable"}}
                    {{else}}
                      {{i18n "wireframe.review.target_new_design"}}
                    {{/if}}
                  </span>
                </div>
                <ul class="wireframe-review__outlets">
                  {{#each group.outlets as |outletName|}}
                    <li class="wireframe-review__outlet">
                      <code
                        class="wireframe-review__outlet-name"
                      >{{outletName}}</code>
                      <div class="wireframe-review__outlet-actions">
                        {{#if group.publishable}}
                          {{#if (this.isOutletPublished outletName)}}
                            <DButton
                              class="btn-flat btn-danger wireframe-review__reset"
                              @action={{fn this.confirmReset outletName}}
                              @label="wireframe.outlet.reset_to_default"
                            />
                          {{/if}}
                        {{/if}}
                      </div>
                    </li>
                  {{/each}}
                </ul>
              </section>
            {{else}}
              <p class="wireframe-review__empty">
                {{i18n "wireframe.review.no_changes"}}
              </p>
            {{/each}}
          </tabs.Tab>
          <tabs.Tab
            class="wireframe-review__tab"
            @key="changes"
            @label={{i18n
              "wireframe.review.tab_changes"
              count=this.editedOutlets.length
            }}
          >
            {{#each this.editedOutlets as |outletName|}}
              {{#let (this.summaryFor outletName) as |summary|}}
                <section class="wireframe-review__change">
                  <div class="wireframe-review__change-header">
                    <code
                      class="wireframe-review__outlet-name"
                    >{{outletName}}</code>
                    <span class="wireframe-review__change-counts">
                      {{#if summary.reliable}}
                        {{#if summary.added}}<span
                            class="wireframe-review__count --added"
                          >{{i18n
                              "wireframe.review.count_added"
                              count=summary.added
                            }}</span>{{/if}}
                        {{#if summary.removed}}<span
                            class="wireframe-review__count --removed"
                          >{{i18n
                              "wireframe.review.count_removed"
                              count=summary.removed
                            }}</span>{{/if}}
                        {{#if summary.edited}}<span
                            class="wireframe-review__count --edited"
                          >{{i18n
                              "wireframe.review.count_edited"
                              count=summary.edited
                            }}</span>{{/if}}
                        {{#if summary.moved}}<span
                            class="wireframe-review__count --moved"
                          >{{i18n
                              "wireframe.review.count_moved"
                              count=summary.moved
                            }}</span>{{/if}}
                        {{#unless
                          (or
                            summary.added
                            summary.removed
                            summary.edited
                            summary.moved
                          )
                        }}<span class="wireframe-review__count">{{i18n
                              "wireframe.review.no_structural_changes"
                            }}</span>{{/unless}}
                      {{else}}
                        <span class="wireframe-review__count --edited">{{i18n
                            "wireframe.review.edited"
                          }}</span>
                      {{/if}}
                    </span>
                    <DButton
                      class="btn-flat wireframe-review__raw-toggle"
                      @action={{fn this.toggleRaw outletName}}
                      @icon={{if
                        (this.isRawExpanded outletName)
                        "chevron-up"
                        "chevron-down"
                      }}
                      @label={{if
                        (this.isRawExpanded outletName)
                        "wireframe.review.hide_raw"
                        "wireframe.review.view_raw"
                      }}
                    />
                  </div>
                  {{#if (this.isRawExpanded outletName)}}
                    <pre class="wireframe-review__raw">{{this.layoutJsonFor
                        outletName
                      }}</pre>
                  {{/if}}
                </section>
              {{/let}}
            {{else}}
              <p class="wireframe-review__empty">
                {{i18n "wireframe.review.no_changes"}}
              </p>
            {{/each}}
          </tabs.Tab>
        </DTabs>

        {{#if this.saveError}}
          <div class="wireframe-review__error" role="alert">
            {{dIcon "triangle-exclamation"}}
            <span>{{this.saveError}}</span>
          </div>
        {{/if}}

        <div class="wireframe-review__footer">
          <DButton
            class="btn-flat wireframe-review__discard"
            @action={{this.discardAll}}
            @disabled={{unless this.wireframeMutationEngine.isDirty true}}
            @label="wireframe.review.discard_all"
          />
          <DButton
            class="btn-default wireframe-review__save-draft"
            @action={{this.saveDrafts}}
            @disabled={{unless this.canSaveDraft true}}
            @label="wireframe.review.save_draft"
          />
          <DButton
            class="btn-primary wireframe-review__publish"
            @action={{this.publish}}
            @disabled={{unless this.canPublish true}}
            @label="wireframe.review.publish"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
