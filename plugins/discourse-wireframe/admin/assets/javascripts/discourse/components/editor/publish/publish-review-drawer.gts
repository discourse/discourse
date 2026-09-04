import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { type ComponentLike, type ModifierLike } from "@glint/template";
import type DialogService from "discourse/dialog-holder/services/dialog";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import type SiteSettingsService from "discourse/services/site-settings";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitchUntyped from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dCloseOnClickOutsideUntyped from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import { i18n } from "discourse-i18n";
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

// TODO(devxp-typescript-pending): drop once d-toggle-switch is authored in .gts
// with a real Signature, then import it directly. Untyped .gjs today gives no
// arg/attr types, so declaring its Element here lets the `{{on}}` modifier and
// aria attributes attach to the switch (it spreads `...attributes` onto its
// inner button).
const DToggleSwitch = DToggleSwitchUntyped as unknown as ComponentLike<{
  /** Toggle state and label configuration. */
  Args: {
    /** Whether the toggle is enabled. */
    state?: boolean;
    /** Translation key naming the toggle. */
    label?: string;
    /** Pre-translated toggle label. */
    translatedLabel?: string;
  };
  /** Button element receiving splatted attributes. */
  Element: HTMLButtonElement;
}>;

// TODO(devxp-typescript-pending): replace this local augmentation once core
// exposes a typed extension mechanism for plugin site settings.
interface WireframeSiteSettings extends SiteSettingsService {
  /** Whether the rendered theme uses the blocks homepage. Absent (undefined)
   * when the rendered theme has no entry in the themeable-settings map. */
  wireframe_custom_homepage?: boolean;
}

type ThemeActionResult = {
  /** Newly created theme identifier, when the action succeeds. */
  themeId?: number;
  /** Error message returned when the action fails. */
  error?: string;
};

/** The outlet whose layout the homepage opt-in publishes as `/`. */
const HOMEPAGE_OUTLET = "homepage-blocks";

/**
 * The save-and-publish review surface: a right-docked drawer that consolidates
 * everything about committing edits. Its Details tab groups the edited outlets by
 * the theme that owns them, so the author sees exactly where each region will
 * land — the directly-publishable themes and, separately, the active theme when
 * it can't be published to (a core or Git theme), with the companion / duplicate /
 * export escape hatches inline. Its Changes tab summarises, per outlet, how the
 * edited layout differs from what is live, with an optional raw-layout view.
 *
 * Opened from the toolbar Save button, the publish-target indicator, and the
 * blocked callout; all three flip `wireframeStaging.reviewDrawerOpen`. Mounted once at
 * the shell level so it survives tab switches. Save/publish/discard and the
 * escape hatches all live here — the toolbar carries only the button that opens
 * the drawer.
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
  /** In-flight theme-producing escape-hatch action (create component / duplicate). */
  @tracked isWorking = false;
  /** Inline error from an escape-hatch action, or null. */
  @tracked actionError: string | null = null;
  @tracked activeTab = "details";

  isTabActive = (tab: string) => this.activeTab === tab;
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

  /**
   * The staged homepage opt-in choice, applied by publish; null while the
   * author hasn't touched the toggle (the row then mirrors the live setting).
   * Deliberately component-local: the drawer is destroyed with the editing
   * session, so the intent can never outlive it.
   */
  @tracked _homepageIntent: boolean | null = null;

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

  /**
   * The theme this session edits against, surfaced when it can't be published to
   * directly so the companion / duplicate escape hatches have a home. These
   * actions target the active theme (not a per-group theme), so they live in one
   * place rather than inside each group.
   */
  get showActiveThemeEscapeHatch() {
    const target = this.wireframePublishTarget.activeThemeTarget;
    return target != null && !target.publishable;
  }

  get activeThemeTarget() {
    return this.wireframePublishTarget.activeThemeTarget;
  }

  /** Whether at least one edited outlet can be published directly. */
  get hasPublishableTargets() {
    return this.targets.some((group) => group.publishable);
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
    return (
      !this.isSaving &&
      (this.hasPublishableTargets || this.homepageIntentPending)
    );
  }

  /** Whether the homepage opt-in row may be offered in this session/state. */
  get showHomepageToggle() {
    return this.wireframePublishTarget.homepageToggleAvailable;
  }

  /** The homepage setting's live value for the rendered theme. */
  get homepageCurrentValue() {
    return this.siteSettings.wireframe_custom_homepage === true;
  }

  /** The state the homepage row displays: the staged intent, else the live value. */
  get homepageDesired() {
    return this._homepageIntent ?? this.homepageCurrentValue;
  }

  /** Whether the homepage layout that publish would write renders anything. */
  get canEnableHomepage() {
    return this.wireframeLayoutQuery.hasRenderableContent(HOMEPAGE_OUTLET);
  }

  /**
   * Whether the homepage toggle is interactable. Switching ON is gated on the
   * post-publish layout having content — an enabled-but-empty homepage renders
   * a blank page for visitors; switching OFF is always permitted.
   */
  get homepageToggleDisabled() {
    return !this.homepageDesired && !this.canEnableHomepage;
  }

  /** Whether publish must also write the staged homepage choice. */
  get homepageIntentPending() {
    return (
      this.showHomepageToggle &&
      this._homepageIntent != null &&
      this._homepageIntent !== this.homepageCurrentValue
    );
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
  toggleHomepageIntent() {
    const next = !this.homepageDesired;
    if (next && !this.canEnableHomepage) {
      return;
    }
    this._homepageIntent = next;
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

  @action
  async exportOutlet(outletName: string) {
    this.actionError = await this.wireframeStaging.exportOutlet(outletName);
  }

  @action
  confirmCreateComponent() {
    this.dialog.confirm({
      title: i18n("wireframe.outlet.create_component_confirm_title"),
      message: i18n("wireframe.outlet.create_component_confirm_message"),
      confirmButtonLabel: "wireframe.outlet.create_component_confirm_button",
      didConfirm: () =>
        this.#runThemeAction(
          () => this.wireframeStaging.createCustomizationComponent(),
          { isComponent: true }
        ),
    });
  }

  @action
  confirmDuplicate() {
    this.dialog.confirm({
      title: i18n("wireframe.outlet.duplicate_confirm_title"),
      message: i18n("wireframe.outlet.duplicate_confirm_message"),
      confirmButtonLabel: "wireframe.outlet.duplicate_confirm_button",
      didConfirm: () =>
        this.#runThemeAction(() => this.wireframeStaging.duplicateForEditing()),
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
    try {
      // The service owns the per-outlet owner targeting, the stale-version
      // conflict prompt, and the edit-state reconciliation; a banner string comes
      // back for any non-conflict error, or null on success.
      this.saveError = await this.wireframeStaging.publishEditedOutlets();
      if (this.saveError == null) {
        this.saveError = await this.#applyHomepageIntent();
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
    }
  }

  /**
   * Writes the staged homepage choice for the rendered theme, re-validating at
   * apply time: the drawer survives SPA navigation, so an intent staged on the
   * homepage must not fire from another page; and a publish that returned
   * cleanly can still have skipped the homepage outlet (a Git-owned target, or
   * a version conflict the author cancelled) — an edit state that survives the
   * publish is the tell.
   *
   * @returns A banner message when the write failed or was refused, or null
   *   when the choice was applied or there was nothing to apply.
   */
  async #applyHomepageIntent(): Promise<string | null> {
    if (!this.homepageIntentPending) {
      return null;
    }
    const desired = this._homepageIntent!;
    const themeId = this.wireframePublishTarget.homepageThemeId;
    if (themeId == null) {
      return null;
    }
    if (desired) {
      if (
        this.wireframeMutationEngine
          .editedOutletNames()
          .includes(HOMEPAGE_OUTLET)
      ) {
        return i18n("wireframe.review.use_as_homepage_unpublished");
      }
      if (!this.canEnableHomepage) {
        return i18n("wireframe.review.use_as_homepage_empty");
      }
    }
    try {
      // Always an explicit boolean: a nil value makes the endpoint delete the
      // override, which errors when no override row exists yet.
      await ajax(`/admin/themes/${themeId}/site-setting`, {
        type: "PUT",
        data: { name: "wireframe_custom_homepage", value: desired },
      });
    } catch (error) {
      return extractError(error, i18n("generic_error"));
    }
    // Mirror what the MessageBus subscriber would apply, so the session doesn't
    // depend on the echo arriving before teardown.
    this.siteSettings.wireframe_custom_homepage = desired;
    this._homepageIntent = null;
    return null;
  }

  // Runs a theme-producing escape-hatch action; on success reloads onto the new
  // theme so its layers load and Publish enables, otherwise surfaces the error.
  async #runThemeAction(
    produce: () => Promise<ThemeActionResult>,
    {
      isComponent = false,
    }: {
      /** Whether the produced theme is a component rather than a parent theme. */
      isComponent?: boolean;
    } = {}
  ): Promise<void> {
    this.isWorking = true;
    this.actionError = null;
    try {
      const { themeId, error } = await produce();
      if (themeId) {
        this.wireframePublishTarget.navigateToEditTheme(themeId, {
          isComponent,
        });
      } else {
        this.actionError = error ?? null;
      }
    } finally {
      this.isWorking = false;
    }
  }

  <template>
    {{#if this.isOpen}}
      <div
        class="wireframe-review wireframe-editor-overlay"
        role="dialog"
        aria-label={{i18n "wireframe.review.title"}}
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
            @icon="xmark"
            @ariaLabel="wireframe.review.close"
            @action={{this.close}}
          />
        </div>

        <div class="wireframe-review__tabs" role="tablist">
          <DButton
            class={{dConcatClass
              "btn-flat wireframe-review__tab"
              (if (this.isTabActive "details") "--active")
            }}
            @label="wireframe.review.tab_details"
            @action={{fn this.setTab "details"}}
          />
          <DButton
            class={{dConcatClass
              "btn-flat wireframe-review__tab"
              (if (this.isTabActive "changes") "--active")
            }}
            @translatedLabel={{i18n
              "wireframe.review.tab_changes"
              count=this.editedOutlets.length
            }}
            @action={{fn this.setTab "changes"}}
          />
        </div>

        <div class="wireframe-review__body">
          {{#if (this.isTabActive "details")}}
            {{#if this.showActiveThemeEscapeHatch}}
              <section class="wireframe-review__escape">
                <p class="wireframe-review__escape-notice">
                  {{#if this.activeThemeTarget.isSystem}}
                    {{i18n "wireframe.outlet.system_notice"}}
                  {{else}}
                    {{i18n "wireframe.outlet.git_notice"}}
                  {{/if}}
                </p>
                <DButton
                  class="btn-primary wireframe-review__create-component"
                  @label="wireframe.outlet.create_component"
                  @title={{i18n "wireframe.outlet.create_component_title"}}
                  @disabled={{this.isWorking}}
                  @action={{this.confirmCreateComponent}}
                />
                {{#unless this.activeThemeTarget.isSystem}}
                  <DButton
                    class="btn-default wireframe-review__duplicate"
                    @label="wireframe.outlet.duplicate"
                    @title={{i18n "wireframe.outlet.duplicate_title"}}
                    @disabled={{this.isWorking}}
                    @action={{this.confirmDuplicate}}
                  />
                {{/unless}}
                {{#if this.actionError}}
                  <p class="wireframe-review__escape-error" role="alert">
                    {{this.actionError}}
                  </p>
                {{/if}}
              </section>
            {{/if}}

            {{#if this.showHomepageToggle}}
              <section class="wireframe-review__homepage">
                <div class="wireframe-review__homepage-row">
                  <DToggleSwitch
                    @state={{this.homepageDesired}}
                    @translatedLabel={{i18n "wireframe.review.use_as_homepage"}}
                    aria-label={{i18n "wireframe.review.use_as_homepage"}}
                    aria-describedby={{if
                      this.homepageToggleDisabled
                      "wireframe-review-homepage-hint"
                    }}
                    disabled={{this.homepageToggleDisabled}}
                    {{on "click" this.toggleHomepageIntent}}
                  />
                </div>
                {{#if this.homepageToggleDisabled}}
                  <p
                    id="wireframe-review-homepage-hint"
                    class="wireframe-review__homepage-hint"
                  >
                    {{i18n "wireframe.review.use_as_homepage_empty"}}
                  </p>
                {{else if this.homepageIntentPending}}
                  <p class="wireframe-review__homepage-hint">
                    {{i18n "wireframe.review.use_as_homepage_pending"}}
                  </p>
                {{/if}}
              </section>
            {{/if}}

            {{#each this.targets as |group|}}
              <section class="wireframe-review__group">
                <div class="wireframe-review__group-header">
                  <span class="wireframe-review__group-theme">
                    {{dIcon (if group.publishable "paintbrush" "lock")}}
                    {{group.themeName}}
                  </span>
                  <span
                    class={{dConcatClass
                      "wireframe-review__group-status"
                      (if group.publishable "--ok" "--blocked")
                    }}
                  >
                    {{#if group.publishable}}
                      {{i18n "wireframe.review.target_publishable"}}
                    {{else}}
                      {{i18n "wireframe.review.target_blocked"}}
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
                        {{#if group.isGit}}
                          <DButton
                            class="btn-flat wireframe-review__export"
                            @icon="download"
                            @label="wireframe.outlet.export"
                            @title={{i18n "wireframe.outlet.export_title"}}
                            @disabled={{this.isWorking}}
                            @action={{fn this.exportOutlet outletName}}
                          />
                        {{else if (this.isOutletPublished outletName)}}
                          {{#if group.publishable}}
                            <DButton
                              class="btn-flat btn-danger wireframe-review__reset"
                              @label="wireframe.outlet.reset_to_default"
                              @action={{fn this.confirmReset outletName}}
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
          {{else}}
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
                      @action={{fn this.toggleRaw outletName}}
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
          {{/if}}
        </div>

        {{#if this.saveError}}
          <div class="wireframe-review__error" role="alert">
            {{dIcon "triangle-exclamation"}}
            <span>{{this.saveError}}</span>
          </div>
        {{/if}}

        <div class="wireframe-review__footer">
          <DButton
            class="btn-flat wireframe-review__discard"
            @label="wireframe.review.discard_all"
            @disabled={{unless this.wireframeMutationEngine.isDirty true}}
            @action={{this.discardAll}}
          />
          <DButton
            class="btn-default wireframe-review__save-draft"
            @label="wireframe.review.save_draft"
            @disabled={{unless this.canSaveDraft true}}
            @action={{this.saveDrafts}}
          />
          <DButton
            class="btn-primary wireframe-review__publish"
            @label="wireframe.review.publish"
            @disabled={{unless this.canPublish true}}
            @action={{this.publish}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
