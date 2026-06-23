// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { OUTLET_STATE } from "../../services/wireframe";

/**
 * The per-outlet section shown in the inspector when an outlet root is
 * selected. Surfaces the outlet's status in one badge — "Editing" while it has
 * unsaved edits, otherwise its state (read-only / default / published, with the
 * owning theme named so an override is trackable) — and the per-outlet verbs:
 *
 * - Save draft / Publish — enabled only while the outlet has unsaved edits;
 *   Publish is also disabled for a Git-managed owner.
 * - Reset to default / Discard — published-and-not-Git / has-edits respectively.
 * - Git escape hatches (when the owner is Git-managed): Create customization
 *   component (primary — a local component overrides the Git theme and is
 *   publishable), Export (commit upstream), and Duplicate (fork the whole theme).
 *   Create-component and Duplicate reload the page onto the resulting theme.
 */
export default class InspectorOutletSection extends Component {
  @service wireframe;
  @service dialog;

  @tracked isWorking = false;
  @tracked actionError = null;

  get state() {
    return this.wireframe.outletState(this.args.outletName);
  }

  get owner() {
    return this.wireframe.outletOwner(this.args.outletName);
  }

  get isEditing() {
    return this.wireframe.isOutletEditing(this.args.outletName);
  }

  get isEditable() {
    return this.state !== OUTLET_STATE.LOCKED;
  }

  get isPublished() {
    return this.state === OUTLET_STATE.PUBLISHED;
  }

  get isGit() {
    return this.owner.isGit;
  }

  /**
   * Whether Publish is available: the outlet has unsaved edits and its owner is
   * not Git-managed.
   *
   * @returns {boolean}
   */
  get canPublish() {
    return this.isEditing && !this.isGit;
  }

  get canResetToDefault() {
    return this.isPublished && !this.isGit;
  }

  /**
   * The owning theme's name, shown on the published badge so an override (a
   * component owning the outlet over its parent) is visible.
   *
   * @returns {string|null}
   */
  get ownerName() {
    return this.owner.themeName;
  }

  @action
  async exportOutlet() {
    this.actionError = await this.wireframe.exportOutlet(this.args.outletName);
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
  confirmReset() {
    // Reset deletes the live ThemeField and is NOT undoable, so confirm first.
    this.dialog.confirm({
      title: i18n("wireframe.outlet.reset_confirm_title"),
      message: i18n("wireframe.outlet.reset_confirm_message"),
      confirmButtonLabel: "wireframe.outlet.reset_confirm_button",
      didConfirm: () => this.wireframe.resetToDefault(this.args.outletName),
    });
  }

  // Runs a theme-producing git action; on success reloads onto the new theme so
  // its layers load and Publish enables, otherwise surfaces the error inline.
  async #runThemeAction(produce) {
    this.isWorking = true;
    this.actionError = null;
    try {
      const { themeId, error } = await produce();
      if (themeId) {
        this.wireframe.navigateToEditTheme(themeId);
      } else {
        this.actionError = error;
      }
    } finally {
      this.isWorking = false;
    }
  }

  <template>
    <section class="wireframe-inspector__outlet">
      <div class="wireframe-inspector__outlet-state">
        {{! One badge: "Editing" supersedes the base state so the two are never
          shown together. }}
        <span
          class={{concat
            "wireframe-outlet-badge --"
            (if this.isEditing "editing" this.state)
          }}
        >
          {{#if this.isEditing}}
            {{i18n "wireframe.outlet.editing"}}
          {{else if (if this.isPublished this.ownerName)}}
            {{i18n "wireframe.outlet.published_by" theme=this.ownerName}}
          {{else}}
            {{i18n (concat "wireframe.outlet.state." this.state)}}
          {{/if}}
        </span>
      </div>

      {{#if this.isEditable}}
        <div class="wireframe-inspector__outlet-verbs">
          <DButton
            class="btn-default wireframe-outlet-verb__save-draft"
            @label="wireframe.outlet.save_draft"
            @disabled={{unless this.isEditing true}}
            @action={{fn this.wireframe.saveDraftOutlet @outletName}}
          />
          <DButton
            class="btn-primary wireframe-outlet-verb__publish"
            @label="wireframe.outlet.publish"
            @disabled={{unless this.canPublish true}}
            @title={{if
              this.isGit
              (i18n "wireframe.outlet.publish_disabled_git")
            }}
            @action={{fn this.wireframe.publishOutlet @outletName}}
          />
          {{#if this.isEditing}}
            <DButton
              class="btn-default wireframe-outlet-verb__discard"
              @label="wireframe.outlet.discard"
              @action={{fn this.wireframe.discardOutlet @outletName}}
            />
          {{/if}}
          {{#if this.canResetToDefault}}
            <DButton
              class="btn-danger wireframe-outlet-verb__reset"
              @label="wireframe.outlet.reset_to_default"
              @action={{this.confirmReset}}
            />
          {{/if}}
        </div>

        {{#if this.isGit}}
          <div class="wireframe-inspector__outlet-git">
            <p class="wireframe-inspector__outlet-git-notice">
              {{i18n "wireframe.outlet.git_notice"}}
            </p>
            <DButton
              class="btn-primary wireframe-outlet-verb__create-component"
              @label="wireframe.outlet.create_component"
              @title={{i18n "wireframe.outlet.create_component_title"}}
              @disabled={{this.isWorking}}
              @action={{this.confirmCreateComponent}}
            />
            <DButton
              class="btn-default wireframe-outlet-verb__export"
              @label="wireframe.outlet.export"
              @title={{i18n "wireframe.outlet.export_title"}}
              @disabled={{this.isWorking}}
              @action={{this.exportOutlet}}
            />
            <DButton
              class="btn-default wireframe-outlet-verb__duplicate"
              @label="wireframe.outlet.duplicate"
              @title={{i18n "wireframe.outlet.duplicate_title"}}
              @disabled={{this.isWorking}}
              @action={{this.confirmDuplicate}}
            />
            {{#if this.actionError}}
              <p class="wireframe-inspector__outlet-git-error" role="alert">
                {{this.actionError}}
              </p>
            {{/if}}
          </div>
        {{/if}}
      {{/if}}
    </section>
  </template>
}
