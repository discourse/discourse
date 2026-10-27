/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import UpcomingChangeBadges from "discourse/admin/components/admin-config-areas/upcoming-change-badges";
import linkifySettingLinks from "discourse/admin/modifiers/linkify-setting-links";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import lightbox from "discourse/lib/lightbox";
import { sanitize } from "discourse/lib/text";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class UpcomingChangeItem extends Component {
  @service site;
  @service toasts;

  @tracked
  bufferedGroups = this.args.change.groups?.split(",").filter(Boolean) || [];
  @tracked bufferedEnabledFor = this.args.change.upcoming_change.enabled_for;
  @tracked savingEnabledFor = false;
  @tracked showGroups = false;
  @tracked enableAfterSelection = false;
  @tracked bufferedGroupsDirty = false;

  groupSelectionId = `${guidFor(this)}-groups`;

  applyLightbox = modifier((element) => lightbox(element));

  #groupsInitialized = false;
  #lastSavedSelection = [];

  get allowEnabledFor() {
    return this.args.change.upcoming_change.allow_enabled_for;
  }

  get canRefineGroups() {
    return (
      !this.allowEnabledFor || this.allowEnabledFor.includes("specific_groups")
    );
  }

  get isEnabled() {
    return this.bufferedEnabledFor !== "no_one";
  }

  get requiresStaff() {
    return this.allowEnabledFor?.includes("staff");
  }

  get staffGroupName() {
    return this.site.groupsById[AUTO_GROUPS.staff.id].name;
  }

  get lockedGroups() {
    return this.requiresStaff ? [this.staffGroupName] : [];
  }

  get toggleLabel() {
    return i18n("admin.upcoming_changes.toggle", {
      name: this.args.change.humanized_name,
    });
  }

  get groupsDescription() {
    if (this.requiresStaff) {
      return i18n("admin.upcoming_changes.staff_always_included");
    }
    if (this.enableAfterSelection || !this.bufferedGroups.length) {
      return i18n("admin.upcoming_changes.add_groups_to_enable");
    }
  }

  get saveGroupsDisabled() {
    return (
      this.savingEnabledFor ||
      !this.bufferedGroupsDirty ||
      (this.enableAfterSelection && !this.bufferedGroups.length)
    );
  }

  get showPermanentSoonNotice() {
    return (
      this.args.change.upcoming_change.status === "stable" &&
      this.args.change.upcoming_change.permanent_warning !== false
    );
  }

  get showDependsOnNotice() {
    return (
      this.args.change.depends_on?.length > 0 &&
      !this.args.change.depends_on_met
    );
  }

  get dependsOnNoticeText() {
    const path = dBasePath();
    const links = this.args.change.depends_on
      .map((name, index) => {
        const label = sanitize(
          this.args.change.depends_on_humanized_names?.[index] ||
            name.replaceAll("_", " ")
        );
        return `<a href="${path}/admin/site_settings/category/all_results?filter=${encodeURIComponent(name)}">${label}</a>`;
      })
      .join(", ");

    return trustHTML(
      i18n("admin.upcoming_changes.depends_on_notice", {
        dependencyLinks: links,
      })
    );
  }

  get showDependentSettingsLink() {
    return (
      this.args.change.dependents.length && this.bufferedEnabledFor !== "no_one"
    );
  }

  get showDefaultOverrideSettingLink() {
    return (
      this.args.change.overriding_defaults &&
      this.bufferedEnabledFor !== "no_one"
    );
  }

  get defaultOverrideSettingFilter() {
    return `upcoming_change_default_override:${this.args.change.setting}`;
  }

  @action
  toggleGroupSelection() {
    this.showGroups = !this.showGroups;
    if (this.showGroups) {
      this.#initializeGroups();
    }
  }

  @action
  async toggleEnabled() {
    if (this.savingEnabledFor) {
      return;
    }
    if (this.isEnabled) {
      await this.#save(false);
      return;
    }

    this.#initializeGroups();
    const groups = this.bufferedGroupsDirty
      ? this.#lastSavedSelection
      : this.bufferedGroups;
    if (this.allowEnabledFor?.includes("specific_groups") && !groups.length) {
      this.showGroups = true;
      this.enableAfterSelection = true;
      return;
    }
    await this.#save(true, groups);
  }

  @action
  groupsChanged(groups) {
    if (this.savingEnabledFor) {
      return;
    }
    this.bufferedGroups = [...new Set([...this.lockedGroups, ...groups])];
    this.bufferedGroupsDirty =
      this.bufferedGroups.length !== this.#lastSavedSelection.length ||
      this.bufferedGroups.some(
        (group) => !this.#lastSavedSelection.includes(group)
      );
  }

  @action
  async saveGroups() {
    if (this.saveGroupsDisabled) {
      return;
    }
    const enabled =
      this.bufferedGroups.length > 0 &&
      (this.isEnabled || this.enableAfterSelection);
    if (await this.#save(enabled, this.bufferedGroups)) {
      this.#lastSavedSelection = this.bufferedGroups;
      this.bufferedGroupsDirty = false;
    }
  }

  #initializeGroups() {
    if (this.#groupsInitialized) {
      return;
    }
    if (this.allowEnabledFor?.includes("everyone")) {
      this.bufferedGroups = [];
    } else if (this.requiresStaff) {
      this.bufferedGroups = this.canRefineGroups
        ? [...new Set([this.staffGroupName, ...this.bufferedGroups])]
        : [this.staffGroupName];
    } else if (!this.allowEnabledFor && !this.bufferedGroups.length) {
      this.bufferedGroups = [
        AUTO_GROUPS.logged_in_users,
        AUTO_GROUPS.anonymous_users,
      ].map((group) => this.site.groupsById[group.id]?.name || group.name);
    }
    this.#lastSavedSelection = this.bufferedGroups;
    this.#groupsInitialized = true;
  }

  #enabledFor(enabled, groups) {
    if (!enabled) {
      return "no_one";
    }
    if (!groups.length) {
      return "everyone";
    }
    if (groups.length === 1 && groups[0] === this.staffGroupName) {
      return this.staffGroupName;
    }
    return "groups";
  }

  #persistedGroups(groups) {
    if (!this.allowEnabledFor) {
      const defaults = [
        AUTO_GROUPS.logged_in_users,
        AUTO_GROUPS.anonymous_users,
      ].map((group) => this.site.groupsById[group.id]?.name || group.name);
      if (defaults.every((group) => groups.includes(group))) {
        return [];
      }
    }
    return groups;
  }

  async #save(enabled, groupNames) {
    const previousEnabledFor = this.bufferedEnabledFor;
    const persistedGroups =
      groupNames === undefined
        ? this.args.change.groups?.split(",").filter(Boolean) || []
        : this.#persistedGroups(groupNames);
    this.savingEnabledFor = true;
    this.bufferedEnabledFor = this.#enabledFor(enabled, persistedGroups);

    try {
      await ajax("/admin/config/upcoming-changes/toggle", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({
          enabled,
          setting_name: this.args.change.setting,
          ...(groupNames === undefined ? {} : { group_names: persistedGroups }),
        }),
      });

      this.enableAfterSelection = false;
      this.args.change.groups = persistedGroups.join(",");
      this.args.change.value = enabled;
      this.args.enabledForChanged?.(
        this.args.change.setting,
        this.bufferedEnabledFor
      );
      this.#showSuccessToast(enabled, persistedGroups, previousEnabledFor);
      return true;
    } catch (error) {
      this.bufferedEnabledFor = previousEnabledFor;
      popupAjaxError(error);
      return false;
    } finally {
      this.savingEnabledFor = false;
    }
  }

  #showSuccessToast(enabled, groups, previousEnabledFor) {
    let message;
    if (enabled === (previousEnabledFor !== "no_one")) {
      message = i18n("admin.upcoming_changes.groups_updated");
    } else if (!enabled) {
      message = i18n("admin.upcoming_changes.change_disabled");
    } else {
      let enabledFor;
      if (groups.length === 1 && groups[0] === this.staffGroupName) {
        enabledFor = i18n("admin.upcoming_changes.enabled_for_options.staff", {
          staffGroupName: this.staffGroupName,
        });
      } else if (groups.length) {
        enabledFor = i18n(
          "admin.upcoming_changes.enabled_for_options.specific_groups_with_group_names",
          {
            groupNames: groups.join(", "),
            count: groups.length,
          }
        );
      } else {
        enabledFor = i18n(
          "admin.upcoming_changes.enabled_for_options.eligible_users"
        ).toLowerCase();
      }
      message = i18n("admin.upcoming_changes.change_enabled_for_success", {
        enabledFor,
      });
    }
    this.toasts.success({ duration: "short", data: { message } });
  }

  <template>
    <tr
      class="d-table__row upcoming-change-row"
      data-upcoming-change={{@change.setting}}
    >
      <td class="d-table__cell --overview">
        {{#if @change.plugin}}
          <span class="upcoming-change__plugin">
            {{dIcon "plug"}}
            {{@change.plugin}}
          </span>
        {{/if}}

        <div class="d-table__overview-name">
          {{@change.humanized_name}}
        </div>

        {{#if @change.description}}
          <div
            class="d-table__overview-about upcoming-change__description"
            {{linkifySettingLinks @change.description}}
          >
            {{trustHTML @change.description}}

            <div
              class="upcoming-change__description-details"
              {{this.applyLightbox}}
            >
              {{#if @change.upcoming_change.image.url}}
                <a
                  class="lightbox upcoming-change__image-preview"
                  data-large-src={{@change.upcoming_change.image.url}}
                  data-target-height={{@change.upcoming_change.image.height}}
                  data-target-width={{@change.upcoming_change.image.width}}
                  href={{@change.upcoming_change.image.url}}
                  rel="nofollow ugc noopener"
                >{{dIcon "far-image"}}
                  {{i18n "admin.upcoming_changes.preview"}}</a>
              {{/if}}

              {{#if @change.upcoming_change.learn_more_url}}
                <span class="upcoming-change__learn-more">
                  {{trustHTML
                    (i18n
                      "feedback_with_link"
                      url=@change.upcoming_change.learn_more_url
                    )
                  }}
                </span>
              {{/if}}
            </div>
          </div>
        {{/if}}

        {{#if this.showDependsOnNotice}}
          <div class="upcoming-change__depends-on-notice">
            {{dIcon "triangle-exclamation"}}
            {{this.dependsOnNoticeText}}
          </div>
        {{/if}}

        {{#if this.showPermanentSoonNotice}}
          <div class="upcoming-change__status-notice">
            {{dIcon "triangle-exclamation"}}
            {{i18n "admin.upcoming_changes.permanent_soon_notice"}}
          </div>
        {{/if}}

        <UpcomingChangeBadges @upcomingChange={{@change.upcoming_change}} />
      </td>
      <td class="d-table__cell --detail upcoming-change__toggle-cell">
        <div class="d-table__mobile-label">
          {{i18n "admin.upcoming_changes.availability"}}
        </div>

        <div class="upcoming-change__controls">
          <DToggleSwitch
            aria-label={{this.toggleLabel}}
            class="upcoming-change__enabled"
            disabled={{this.savingEnabledFor}}
            @state={{this.isEnabled}}
            {{on "click" this.toggleEnabled}}
          />
          {{#if this.canRefineGroups}}
            <DButton
              aria-controls={{this.groupSelectionId}}
              aria-expanded={{if this.showGroups "true" "false"}}
              class="btn-default upcoming-change__edit-groups"
              @disabled={{this.savingEnabledFor}}
              @icon="user-group-gear"
              @title="admin.upcoming_changes.edit_groups"
              {{on "click" this.toggleGroupSelection}}
            />
          {{/if}}
        </div>

        {{#if this.showGroups}}
          <div
            class="upcoming-change__group-selection-wrapper"
            id={{this.groupSelectionId}}
          >
            <div class="upcoming-change__group-controls">
              <EmailGroupUserChooser
                @onChange={{this.groupsChanged}}
                @options={{hash
                  disabled=this.savingEnabledFor
                  groupsOnly=true
                  useHeaderFilter=true
                  fullWidthWrap=true
                  lockedValues=this.lockedGroups
                  none="admin.upcoming_changes.select_groups"
                  headerAriaLabel=(i18n "admin.upcoming_changes.select_groups")
                }}
                @value={{this.bufferedGroups}}
              />
              <DButton
                class="btn-primary upcoming-change__save-groups"
                @disabled={{this.saveGroupsDisabled}}
                @icon="check"
                @title="admin.upcoming_changes.save_groups"
                {{on "click" this.saveGroups}}
              />
            </div>
            {{#if this.groupsDescription}}
              <p
                class="upcoming-change__groups-description"
              >{{this.groupsDescription}}</p>
            {{/if}}
          </div>
        {{/if}}

        {{#if this.showDependentSettingsLink}}
          <div class="upcoming-change__dependents">
            <LinkTo
              @query={{hash filter="all_results" dependsOn=@change.setting}}
              @route="adminSiteSettings"
            >
              {{i18n "admin.upcoming_changes.show_related_settings"}}
            </LinkTo>
          </div>
        {{/if}}

        {{#if this.showDefaultOverrideSettingLink}}
          <div class="upcoming-change__default-override-setting">
            <LinkTo
              @query={{hash filter=this.defaultOverrideSettingFilter}}
              @route="adminSiteSettings"
            >
              {{i18n "admin.upcoming_changes.show_related_settings"}}
            </LinkTo>
          </div>
        {{/if}}
      </td>
    </tr>
  </template>
}
