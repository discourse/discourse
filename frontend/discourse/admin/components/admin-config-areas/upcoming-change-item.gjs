/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import UpcomingChangeBadges from "discourse/admin/components/admin-config-areas/upcoming-change-badges";
import UpcomingChangeGroupControl from "discourse/admin/components/admin-config-areas/upcoming-change-group-control";
import AdminSiteSetting from "discourse/admin/models/site-setting";
import linkifySettingLinks from "discourse/admin/modifiers/linkify-setting-links";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import lightbox from "discourse/lib/lightbox";
import { sanitize } from "discourse/lib/text";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ROLE_GROUPS = {
  all_members: [AUTO_GROUPS.logged_in_users, AUTO_GROUPS.anonymous_users],
  staff: [AUTO_GROUPS.staff],
  admins: [AUTO_GROUPS.admins],
  developers: [AUTO_GROUPS.admins],
  moderators: [AUTO_GROUPS.moderators],
};

export default class UpcomingChangeItem extends Component {
  @service site;
  @service toasts;
  @service siteSettingChangeTracker;

  @tracked
  bufferedGroups = this.args.change.groups?.split(",").filter(Boolean) || [];
  @tracked bufferedEnabledFor = this.args.change.upcoming_change.enabled_for;
  @tracked savingEnabledFor = false;
  @tracked enableAfterSelection = false;

  applyLightbox = modifier((element) => lightbox(element));

  @tracked _linkedGroupSetting = this.args.change.group_setting;

  get allowEnabledFor() {
    return this.args.change.upcoming_change.allow_enabled_for;
  }

  // Changes that only read the boolean setting can't be scoped, so their
  // audience is shown as the groups the change affects rather than stored.
  get isLocked() {
    return Boolean(
      !this._linkedGroupSetting &&
      this.allowEnabledFor &&
      !this.allowEnabledFor.includes("specific_groups")
    );
  }

  get roleGroups() {
    const groups =
      ROLE_GROUPS[this.args.change.upcoming_change.impact_role] ||
      ROLE_GROUPS.all_members;
    return groups.map(
      (group) => this.site.groupsById[group.id]?.name || group.name
    );
  }

  get displayGroups() {
    if (this._linkedGroupSetting) {
      return this.bufferedGroups;
    }
    if (this.isLocked) {
      return this.requiresStaff ? [this.staffGroupName] : this.roleGroups;
    }
    if (this.requiresStaff) {
      return [...new Set([this.staffGroupName, ...this.bufferedGroups])];
    }
    if (!this.allowEnabledFor && !this.bufferedGroups.length) {
      return this.roleGroups;
    }
    return this.bufferedGroups;
  }

  get isEnabled() {
    return this.bufferedEnabledFor !== "no_one";
  }

  get requiresStaff() {
    return !this._linkedGroupSetting && this.allowEnabledFor?.includes("staff");
  }

  get staffGroupName() {
    return this.site.groupsById[AUTO_GROUPS.staff.id].name;
  }

  get lockedGroups() {
    if (this.isLocked) {
      return this.displayGroups;
    }
    if (this._linkedGroupSetting) {
      return (this._linkedGroupSetting.mandatory_values || "")
        .split("|")
        .filter(Boolean)
        .map((id) => this.site.groupsById[Number(id)]?.name)
        .filter(Boolean);
    }
    return this.requiresStaff ? [this.staffGroupName] : [];
  }

  get disallowedGroups() {
    return (this._linkedGroupSetting?.disallowed_groups || "")
      .split("|")
      .filter(Boolean)
      .map(Number);
  }

  get emptySelectionMessage() {
    if (this._linkedGroupSetting) {
      return i18n("admin.upcoming_changes.toggle_instead_of_empty_groups");
    }
  }

  get preventEmptyGroups() {
    return Boolean(this._linkedGroupSetting || this.enableAfterSelection);
  }

  get includeEveryone() {
    return Boolean(
      this._linkedGroupSetting &&
      !this.disallowedGroups.includes(AUTO_GROUPS.everyone.id)
    );
  }

  get toggleLabel() {
    return i18n("admin.upcoming_changes.toggle", {
      name: this.args.change.humanized_name,
    });
  }

  get groupsDescription() {
    if (this.isLocked) {
      return i18n("admin.upcoming_changes.audience_locked");
    }
    if (this.requiresStaff) {
      return i18n("admin.upcoming_changes.staff_always_included");
    }
    if (this.enableAfterSelection || !this.displayGroups.length) {
      return i18n("admin.upcoming_changes.add_groups_to_enable");
    }
  }

  get showPermanentSoonNotice() {
    return (
      this.args.change.upcoming_change.status === "stable" &&
      this.args.change.upcoming_change.permanent_warning !== false
    );
  }

  get showNotices() {
    return this.showDependsOnNotice || this.showPermanentSoonNotice;
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

  get hasLinks() {
    return Boolean(
      this.args.change.upcoming_change.image?.url ||
      this.args.change.upcoming_change.learn_more_url ||
      this.showDependentSettingsLink ||
      this.showDefaultOverrideSettingLink
    );
  }

  get defaultOverrideSettingFilter() {
    return `upcoming_change_default_override:${this.args.change.setting}`;
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

    if (this._linkedGroupSetting) {
      await this.#save(true);
      return;
    }
    if (this.isLocked) {
      await this.#save(true, this.requiresStaff ? [this.staffGroupName] : []);
      return;
    }
    const groups = this.displayGroups;
    if (this.allowEnabledFor?.includes("specific_groups") && !groups.length) {
      this.enableAfterSelection = true;
      return;
    }
    await this.#save(true, groups);
  }

  @action
  async saveGroups(groups) {
    if (this._linkedGroupSetting) {
      return this.#saveLinkedGroups(groups);
    }
    const enabled =
      groups.length > 0 && (this.isEnabled || this.enableAfterSelection);
    return this.#save(enabled, groups);
  }

  async #saveLinkedGroups(groups) {
    if (!groups.length || this.savingEnabledFor) {
      return false;
    }
    this.savingEnabledFor = true;
    try {
      const setting = AdminSiteSetting.create(this._linkedGroupSetting);
      if (
        setting.requiresConfirmation &&
        !(await this.siteSettingChangeTracker.confirmChanges(setting))
      ) {
        return false;
      }
      const result = await ajax("/admin/config/upcoming-changes/groups", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({
          setting: this.args.change.setting,
          group_names: groups,
        }),
      });
      this._linkedGroupSetting = result.group_setting;
      this.bufferedGroups = result.groups?.split(",").filter(Boolean) || [];
      this.args.change.groups = result.groups;
      this.args.change.group_setting = result.group_setting;
      this.bufferedEnabledFor = this.#enabledFor(
        this.isEnabled,
        this.bufferedGroups
      );
      this.args.enabledForChanged?.(
        this.args.change.setting,
        this.bufferedEnabledFor
      );
      this.toasts.success({
        duration: "short",
        data: { message: i18n("admin.upcoming_changes.groups_updated") },
      });
      return true;
    } catch (error) {
      popupAjaxError(error);
      return false;
    } finally {
      this.savingEnabledFor = false;
    }
  }

  #enabledFor(enabled, groups) {
    if (!enabled) {
      return "no_one";
    }
    if (this._linkedGroupSetting) {
      const everyone = [
        AUTO_GROUPS.logged_in_users,
        AUTO_GROUPS.anonymous_users,
      ].map((group) => this.site.groupsById[group.id]?.name || group.name);
      if (everyone.every((group) => groups.includes(group))) {
        return "everyone";
      }
      if (!groups.length) {
        return "groups";
      }
    } else if (!groups.length) {
      return "everyone";
    }
    if (groups.length === 1 && groups[0] === this.staffGroupName) {
      return this.staffGroupName;
    }
    return "groups";
  }

  // Mirrors UpcomingChanges.normalize_group_names: the default audience is
  // stored as no restriction.
  #persistedGroups(groups) {
    if (!this.allowEnabledFor) {
      const everyone = ROLE_GROUPS.all_members.map(
        (group) => this.site.groupsById[group.id]?.name || group.name
      );
      const isRoleDefault =
        groups.length === this.roleGroups.length &&
        this.roleGroups.every((group) => groups.includes(group));
      if (isRoleDefault || everyone.every((group) => groups.includes(group))) {
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
      if (groupNames !== undefined) {
        this.bufferedGroups = persistedGroups;
      }
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
    if (this._linkedGroupSetting && enabled) {
      message = i18n("admin.upcoming_changes.change_enabled");
    } else if (enabled === (previousEnabledFor !== "no_one")) {
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
        {{#if this.showNotices}}
          <div class="upcoming-change__notices">
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
          </div>
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
          </div>
        {{/if}}

        {{#if this.hasLinks}}
          <div class="upcoming-change__links" {{this.applyLightbox}}>
            {{#if @change.upcoming_change.image.url}}
              <span class="upcoming-change__link">
                <a
                  class="lightbox upcoming-change__image-preview"
                  data-large-src={{@change.upcoming_change.image.url}}
                  data-target-height={{@change.upcoming_change.image.height}}
                  data-target-width={{@change.upcoming_change.image.width}}
                  href={{@change.upcoming_change.image.url}}
                  rel="nofollow ugc noopener"
                >{{dIcon "far-image"}}
                  {{i18n "admin.upcoming_changes.preview"}}</a>
              </span>
            {{/if}}

            {{#if @change.upcoming_change.learn_more_url}}
              <span class="upcoming-change__link upcoming-change__learn-more">
                <a
                  href={{@change.upcoming_change.learn_more_url}}
                  rel="noopener noreferrer"
                  target="_blank"
                >{{dIcon "up-right-from-square"}}
                  {{i18n "admin.upcoming_changes.feedback"}}</a>
              </span>
            {{/if}}

            {{#if this.showDependentSettingsLink}}
              <span class="upcoming-change__link upcoming-change__dependents">
                <LinkTo
                  @query={{hash filter="all_results" dependsOn=@change.setting}}
                  @route="adminSiteSettings"
                >
                  {{dIcon "gear"}}
                  {{i18n "admin.upcoming_changes.settings"}}
                </LinkTo>
              </span>
            {{/if}}

            {{#if this.showDefaultOverrideSettingLink}}
              <span
                class="upcoming-change__link upcoming-change__default-override-setting"
              >
                <LinkTo
                  @query={{hash filter=this.defaultOverrideSettingFilter}}
                  @route="adminSiteSettings"
                >
                  {{dIcon "gear"}}
                  {{i18n "admin.upcoming_changes.settings"}}
                </LinkTo>
              </span>
            {{/if}}
          </div>
        {{/if}}

        <UpcomingChangeBadges
          @plugin={{@change.plugin}}
          @upcomingChange={{@change.upcoming_change}}
        />
      </td>
      <td class="d-table__cell --detail upcoming-change__availability-cell">
        <div class="d-table__mobile-label">
          {{i18n "admin.upcoming_changes.availability"}}
        </div>

        <UpcomingChangeGroupControl
          @description={{this.groupsDescription}}
          @disabled={{this.savingEnabledFor}}
          @disallowedGroups={{this.disallowedGroups}}
          @emptySelectionMessage={{this.emptySelectionMessage}}
          @groups={{this.displayGroups}}
          @includeEveryone={{this.includeEveryone}}
          @locked={{this.isLocked}}
          @lockedGroups={{this.lockedGroups}}
          @onSave={{this.saveGroups}}
          @preventEmpty={{this.preventEmptyGroups}}
        />

      </td>
      <td class="d-table__cell --detail upcoming-change__enabled-cell">
        <div class="d-table__mobile-label">
          {{i18n "admin.upcoming_changes.enabled"}}
        </div>

        <DToggleSwitch
          aria-label={{this.toggleLabel}}
          class="upcoming-change__enabled"
          disabled={{this.savingEnabledFor}}
          @state={{this.isEnabled}}
          {{on "click" this.toggleEnabled}}
        />
      </td>
    </tr>
  </template>
}
