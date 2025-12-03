import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import DSelect from "discourse/components/d-select";
import GroupSelector from "discourse/components/group-selector";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";
import lightbox from "discourse/lib/lightbox";
import Group from "discourse/models/group";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class UpcomingChangeItem extends Component {
  @service toasts;

  @tracked bufferedGroups = this.args.change.groups;
  @tracked bufferedEnabledFor = this.args.change.upcoming_change.enabled_for;
  @tracked savingEnabledFor = false;
  @tracked bufferedGroupsDirty = false;

  registeredMenu = null;

  applyLightbox = modifier((element) => lightbox(element));

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this._savingEnabledForTimeout);
  }

  impactRoleIcon(impactRole) {
    switch (impactRole) {
      case "admins":
        return "shield-halved";
      case "moderators":
        return "shield-halved";
      case "staff":
        return "shield-halved";
      case "all_members":
        return "users";
      case "developers":
        return "code";
    }
  }

  get enabledForOptions() {
    return [
      {
        label: i18n("admin.upcoming_changes.enabled_for_options.no_one"),
        value: "no_one",
      },
      {
        label: i18n("admin.upcoming_changes.enabled_for_options.everyone"),
        value: "everyone",
      },
      {
        label: i18n("admin.upcoming_changes.enabled_for_options.staff"),
        value: "staff",
      },
      {
        label: i18n(
          "admin.upcoming_changes.enabled_for_options.specific_groups"
        ),
        value: "groups",
      },
    ];
  }

  get enabledForDisabled() {
    return (
      this.args.change.upcoming_change.status === "permanent" ||
      this.savingEnabledFor
    );
  }

  @action
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: false });
  }

  @action
  async saveGroups(opts = {}) {
    const silenceToast =
      this.bufferedEnabledFor === "groups" || opts.silenceToast;
    let newEnabledFor = this.bufferedEnabledFor;

    // If all groups have been removed switch to "no one" on save
    const isGroupsMode = newEnabledFor === "groups";
    let groupNames;
    let toggleValue;

    if (!this.bufferedGroups.length && isGroupsMode) {
      this.groupsChanged("");
      groupNames = [];
      newEnabledFor = "no_one";
      toggleValue = false;
    } else {
      groupNames = this.bufferedGroups.length
        ? this.bufferedGroups.split(",")
        : [];
      if (isGroupsMode) {
        toggleValue = true;
      }
    }

    try {
      await ajax("/admin/config/upcoming-changes/groups", {
        type: "PUT",
        data: {
          setting: this.args.change.setting,
          group_names: groupNames,
        },
      });

      this.bufferedGroups = groupNames.join(",");
      this.bufferedGroupsDirty = false;

      if (newEnabledFor !== this.bufferedEnabledFor) {
        this.bufferedEnabledFor = newEnabledFor;
      }

      // We do this because in the case where the admin is selecting
      // "staff", "everyone", or "no one", we don't want to show
      // a toast for saving groups, we only want to show the enabled/disabled
      // toast, groups in this case are "behind the scenes".
      if (!silenceToast) {
        this.toasts.success({
          duration: "short",
          data: {
            message: i18n("admin.upcoming_changes.groups_updated"),
          },
        });
      }

      // If we are saving groups when the admin has selected "Specific groups",
      // it means we also need to enable the change, since we do not automatically
      // do this when the dropdown option changes to "groups" (groups need to be selected first).
      if (toggleValue !== undefined) {
        await this.toggleChange(toggleValue, newEnabledFor);
      }
    } catch (err) {
      popupAjaxError(err);
    }
  }

  @action
  async toggleChange(enabled, enabledFor) {
    await ajax("/admin/config/upcoming-changes/toggle", {
      type: "PUT",
      data: {
        enabled,
        setting_name: this.args.change.setting,
      },
    });

    let enabledForLabel;
    if (enabledFor === "no_one") {
      enabledForLabel = i18n(
        "admin.upcoming_changes.enabled_for_options.no_one"
      );
    } else if (enabledFor === "everyone") {
      enabledForLabel = i18n(
        "admin.upcoming_changes.enabled_for_options.everyone"
      );
    } else if (enabledFor === "staff") {
      enabledForLabel = i18n(
        "admin.upcoming_changes.enabled_for_options.staff"
      );
    } else if (enabledFor === "groups") {
      const groupNames = this.bufferedGroups.split(",");
      enabledForLabel = i18n(
        "admin.upcoming_changes.enabled_for_options.specific_groups_with_group_names",
        {
          groupNames: groupNames.join(", "),
          count: groupNames.length,
        }
      );
    }

    this.toasts.success({
      duration: "short",
      data: {
        message: enabled
          ? i18n("admin.upcoming_changes.change_enabled_for_success", {
              enabledFor: enabledForLabel.toLowerCase(),
            })
          : i18n("admin.upcoming_changes.change_disabled"),
      },
    });
  }

  @bind
  onRegisterMenuForRow(menuApi) {
    this.registeredMenu = menuApi;
  }

  @action
  groupsChanged(newGroups) {
    this.bufferedGroupsDirty = true;
    this.bufferedGroups = newGroups;
  }

  @action
  async enabledForChanged(newValue) {
    const oldValue = this.args.change.upcoming_change.enabled_for;
    this.bufferedEnabledFor = newValue;

    // When enabling for specific groups, we need to toggle the change
    // when the groups are selected and saved, otherwise it will get
    // enabled with no groups selected.
    if (newValue === "groups") {
      return;
    }

    this.savingEnabledFor = true;
    const isEnabled = newValue !== "no_one";

    try {
      await this.toggleChange(isEnabled, newValue);

      if (newValue === "staff") {
        this.groupsChanged(AUTO_GROUPS.staff.name);
      } else if (newValue === "everyone" || newValue === "no_one") {
        this.groupsChanged("");
      }

      await this.saveGroups({ silenceToast: true });
    } catch (error) {
      this.bufferedEnabledFor = oldValue;
      popupAjaxError(error);
    } finally {
      // We prevent rapid changes because on the server-side
      // we may have on(:setting_name) events for the site
      // setting changing, and we want to make sure we don't
      // cause rapid unnecessary work.
      this._savingEnabledForTimeout = discourseLater(() => {
        this.savingEnabledFor = false;
      }, 2000);
    }
  }

  <template>
    <tr
      class="d-table__row upcoming-change-row"
      data-upcoming-change={{@change.setting}}
    >
      <td class="d-table__cell --overview">
        {{#if @change.plugin}}
          <span class="upcoming-change__plugin">
            {{icon "plug"}}
            {{@change.plugin}}
          </span>
        {{/if}}

        <div class="d-table__overview-name">
          {{@change.humanized_name}}
        </div>

        {{#if @change.description}}
          <div class="d-table__overview-about upcoming-change__description">
            {{@change.description}}

            <div
              class="upcoming-change__description-details"
              {{this.applyLightbox}}
            >
              {{#if @change.upcoming_change.image.url}}
                <a
                  href={{@change.upcoming_change.image.url}}
                  class="lightbox upcoming-change__image-preview"
                  rel="nofollow ugc noopener"
                  data-target-width={{@change.upcoming_change.image.width}}
                  data-target-height={{@change.upcoming_change.image.height}}
                  data-large-src={{@change.upcoming_change.image.url}}
                >{{icon "far-image"}}
                  {{i18n "admin.upcoming_changes.preview"}}</a>
              {{/if}}

              {{#if @change.upcoming_change.learn_more_url}}
                <span class="upcoming-change__learn-more">
                  {{htmlSafe
                    (i18n
                      "learn_more_with_link"
                      url=@change.upcoming_change.learn_more_url
                    )
                  }}
                </span>
              {{/if}}
            </div>
          </div>
        {{/if}}

        {{#if (eq @change.upcoming_change.status "permanent")}}
          <div class="upcoming-change__permanent-notice">
            {{icon "triangle-exclamation"}}
            {{i18n "admin.upcoming_changes.permanent_notice"}}
          </div>
        {{/if}}

        <div class="upcoming-change__badges">
          <span
            title={{i18n
              (concat
                "admin.upcoming_changes.statuses."
                @change.upcoming_change.status
              )
            }}
            class={{concatClass
              "upcoming-change__badge"
              (concat "--status-" @change.upcoming_change.status)
            }}
          >
            {{icon
              (if
                (eq @change.upcoming_change.status "permanent")
                "lock"
                "far-circle-dot"
              )
            }}
            {{i18n
              (concat
                "admin.upcoming_changes.statuses."
                @change.upcoming_change.status
              )
            }}
          </span>

          <span
            title={{i18n
              (concat
                "admin.upcoming_changes.impact_roles."
                @change.upcoming_change.impact_role
              )
            }}
            class={{concatClass
              "upcoming-change__badge"
              (concat "--impact-role-" @change.upcoming_change.impact_role)
            }}
          >
            {{icon (this.impactRoleIcon @change.upcoming_change.impact_role)}}
            {{i18n
              (concat
                "admin.upcoming_changes.impact_roles."
                @change.upcoming_change.impact_role
              )
            }}
          </span>
        </div>
      </td>
      <td class="d-table__cell --detail upcoming-change__toggle-cell">
        <div class="d-table__mobile-label">
          {{i18n "admin.upcoming_changes.enabled_for"}}
        </div>

        <DSelect
          @value={{this.bufferedEnabledFor}}
          @onChange={{this.enabledForChanged}}
          @includeNone={{false}}
          class="upcoming-change__enabled-for"
          disabled={{this.enabledForDisabled}}
          as |select|
        >
          {{#each this.enabledForOptions as |option|}}
            <select.Option @value={{option.value}}>
              {{option.label}}</select.Option>
          {{/each}}
        </DSelect>

        {{#if (eq this.bufferedEnabledFor "groups")}}
          <div class="upcoming-change__group-selection-wrapper">
            {{#if (eq @change.upcoming_change.status "permanent")}}
              {{i18n "admin.upcoming_changes.permanent_no_group_selection"}}
            {{else}}
              <GroupSelector
                @groupFinder={{this.groupFinder}}
                @groupNames={{this.bufferedGroups}}
                @onChange={{this.groupsChanged}}
                @placeholderKey="admin.upcoming_changes.select_groups"
              />
            {{/if}}

            {{#if this.bufferedGroupsDirty}}
              <DButton
                class="upcoming-change__save-groups btn-primary"
                @icon="check"
                @size="small"
                @title="admin.upcoming_changes.save_groups"
                {{on "click" this.saveGroups}}
              />
            {{else}}
              <DTooltip
                @content={{if
                  this.bufferedGroups
                  (i18n "admin.upcoming_changes.no_changes_to_save")
                  (i18n "admin.upcoming_changes.add_groups_to_enable")
                }}
              >
                <:trigger>
                  <DButton
                    class="upcoming-change__save-groups btn-primary"
                    @icon="check"
                    @size="small"
                    @disabled={{true}}
                    {{on "click" this.saveGroups}}
                  />
                </:trigger>
              </DTooltip>
            {{/if}}
          </div>
        {{/if}}
      </td>
    </tr>
  </template>
}
