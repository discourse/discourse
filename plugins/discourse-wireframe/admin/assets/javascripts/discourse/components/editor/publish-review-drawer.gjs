// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dCloseOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import { i18n } from "discourse-i18n";
import { OUTLET_STATE } from "../../services/wireframe-layout-query";

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
 * blocked callout; all three flip `wireframe.reviewDrawerOpen`. Mounted once at
 * the shell level so it survives tab switches. Save/publish/discard and the
 * escape hatches all live here — the toolbar carries only the button that opens
 * the drawer.
 */
export default class PublishReviewDrawer extends Component {
  @service wireframe;
  @service dialog;
  @service wireframeEditEngine;
  @service wireframeLayoutQuery;
  @service wireframePublishPreview;
  @service wireframeSession;
  @service wireframeTheme;
  @service wireframeValidation;

  /** In-flight save or publish; disables the action buttons while awaiting. */
  @tracked isSaving = false;
  /** Banner message for a failed save/publish, or null. */
  @tracked saveError = null;
  /** In-flight theme-producing escape-hatch action (create component / duplicate). */
  @tracked isWorking = false;
  /** Inline error from an escape-hatch action, or null. */
  @tracked actionError = null;
  @tracked activeTab = "details";

  isTabActive = (tab) => this.activeTab === tab;
  isRawExpanded = (outletName) => this.#expandedRaw.has(outletName);
  outletState = (outletName) =>
    this.wireframeLayoutQuery.outletState(outletName);
  summaryFor = (outletName) =>
    this.wireframePublishPreview.outletChangeSummary(outletName);
  layoutJsonFor = (outletName) =>
    this.wireframePublishPreview.outletLayoutJson(outletName);
  isOutletPublished = (outletName) =>
    this.wireframeLayoutQuery.outletState(outletName) ===
    OUTLET_STATE.PUBLISHED;
  /** Outlets whose raw-layout view is expanded on the Changes tab. */
  #expandedRaw = trackedSet();

  get isOpen() {
    return this.wireframeSession.active && this.wireframe.reviewDrawerOpen;
  }

  /** The edited outlets grouped by owner theme — the publish plan. */
  get targets() {
    return this.wireframeTheme.publishTargets;
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
   *
   * @returns {boolean}
   */
  get showActiveThemeEscapeHatch() {
    const target = this.wireframeTheme.activeThemeTarget;
    return target != null && !target.publishable;
  }

  get activeThemeTarget() {
    return this.wireframeTheme.activeThemeTarget;
  }

  /** Whether at least one edited outlet can be published directly. */
  get hasPublishableTargets() {
    return this.targets.some((group) => group.publishable);
  }

  /** Whether Save draft is available (unsaved edits exist and nothing is in flight). */
  get canSaveDraft() {
    return (
      !this.isSaving &&
      this.wireframe.hasUnsavedDraftEdits &&
      this.wireframeTheme.activeThemeId != null
    );
  }

  /** Whether Publish is available (a publishable target exists and nothing is in flight). */
  get canPublish() {
    return !this.isSaving && this.hasPublishableTargets;
  }

  @action
  setTab(tab) {
    this.activeTab = tab;
  }

  @action
  close() {
    this.wireframe.closeReviewDrawer();
  }

  @action
  toggleRaw(outletName) {
    if (this.#expandedRaw.has(outletName)) {
      this.#expandedRaw.delete(outletName);
    } else {
      this.#expandedRaw.add(outletName);
    }
  }

  @action
  discardAll() {
    this.wireframe.discardAll();
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
  confirmReset(outletName) {
    // Reset deletes the live ThemeField and is NOT undoable, so confirm first.
    this.dialog.confirm({
      title: i18n("wireframe.outlet.reset_confirm_title"),
      message: i18n("wireframe.outlet.reset_confirm_message"),
      confirmButtonLabel: "wireframe.outlet.reset_confirm_button",
      didConfirm: () => this.wireframe.resetToDefault(outletName),
    });
  }

  @action
  async exportOutlet(outletName) {
    this.actionError = await this.wireframe.exportOutlet(outletName);
  }

  @action
  confirmCreateComponent() {
    this.dialog.confirm({
      title: i18n("wireframe.outlet.create_component_confirm_title"),
      message: i18n("wireframe.outlet.create_component_confirm_message"),
      confirmButtonLabel: "wireframe.outlet.create_component_confirm_button",
      didConfirm: () =>
        this.#runThemeAction(() =>
          this.wireframe.createCustomizationComponent()
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
        this.#runThemeAction(() => this.wireframe.duplicateForEditing()),
    });
  }

  async #performSaveDrafts() {
    this.isSaving = true;
    this.saveError = null;
    try {
      this.saveError = await this.wireframe.saveAllEditedDrafts();
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
      this.saveError = await this.wireframe.publishEditedOutlets();
    } finally {
      this.isSaving = false;
    }
    // A clean publish is the end of the editing session — leave the editor so the
    // author lands back on the live page showing what they just published. On a
    // failure the banner stays and the drawer stays open to retry.
    if (this.saveError == null) {
      this.wireframe.exit();
    }
  }

  // Runs a theme-producing escape-hatch action; on success reloads onto the new
  // theme so its layers load and Publish enables, otherwise surfaces the error.
  async #runThemeAction(produce) {
    this.isWorking = true;
    this.actionError = null;
    try {
      const { themeId, error } = await produce();
      if (themeId) {
        this.wireframeTheme.navigateToEditTheme(themeId);
      } else {
        this.actionError = error;
      }
    } finally {
      this.isWorking = false;
    }
  }

  <template>
    {{#if this.isOpen}}
      <div
        class="wireframe-review"
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
            @disabled={{unless this.wireframeEditEngine.isDirty true}}
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
