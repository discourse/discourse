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
import UpcomingChangeGroupControl from "discourse/admin/components/admin-config-areas/upcoming-change-group-control";
import AdminSiteSetting from "discourse/admin/models/site-setting";
import linkifySettingLinks from "discourse/admin/modifiers/linkify-setting-links";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import lightbox from "discourse/lib/lightbox";
import { sanitize } from "discourse/lib/text";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class UpcomingChangeItem extends Component {
  @service site;
  @service toasts;
  @service siteSettingChangeTracker;

  @tracked
  bufferedGroups = this.args.change.groups?.split(",").filter(Boolean) || [];
  @tracked bufferedEnabledFor = this.args.change.upcoming_change.enabled_for;
  @tracked savingEnabledFor = false;
  @tracked showGroups = false;
  @tracked enableAfterSelection = false;
  @tracked groupsInitialized = false;
  groupSelectionId = `${guidFor(this)}-groups`;

  applyLightbox = modifier((element) => lightbox(element));

  @tracked _linkedGroupSetting = this.args.change.group_setting;

  get allowEnabledFor() {
    return this.args.change.upcoming_change.allow_enabled_for;
  }

  get canRefineGroups() {
    return (
      this._linkedGroupSetting ||
      !this.allowEnabledFor ||
      this.allowEnabledFor.includes("specific_groups")
    );
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
    if (this.requiresStaff) {
      return i18n("admin.upcoming_changes.staff_always_included");
    }
    if (this.enableAfterSelection || !this.bufferedGroups.length) {
      return i18n("admin.upcoming_changes.add_groups_to_enable");
    }
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

    if (this._linkedGroupSetting) {
      await this.#save(true);
      return;
    }
    this.#initializeGroups();
    const groups = this.bufferedGroups;
    if (this.allowEnabledFor?.includes("specific_groups") && !groups.length) {
      this.showGroups = true;
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
    if (await this.#save(enabled, groups)) {
      this.bufferedGroups = groups;
      return true;
    }
    return false;
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

  #initializeGroups() {
    if (this.groupsInitialized) {
      return;
    }
    if (this._linkedGroupSetting) {
      this.groupsInitialized = true;
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
    this.groupsInitialized = true;
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

        {{#if this.groupsInitialized}}
          <UpcomingChangeGroupControl
            @description={{this.groupsDescription}}
            @disabled={{this.savingEnabledFor}}
            @disallowedGroups={{this.disallowedGroups}}
            @emptySelectionMessage={{this.emptySelectionMessage}}
            @expanded={{this.showGroups}}
            @groups={{this.bufferedGroups}}
            @id={{this.groupSelectionId}}
            @includeEveryone={{this.includeEveryone}}
            @lockedGroups={{this.lockedGroups}}
            @onSave={{this.saveGroups}}
            @preventEmpty={{this.preventEmptyGroups}}
          />
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
