import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import { eq, notEq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import GroupSelector from "discourse/components/group-selector";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import lightbox from "discourse/lib/lightbox";
import Group from "discourse/models/group";
import { i18n } from "discourse-i18n";

export default class UpcomingChangeItem extends Component {
  @service toasts;
  @service siteSettings;

  @tracked toggleSettingDisabled = false;
  @tracked bufferedGroups = this.args.change.groups;

  registeredMenu = null;

  // TODO (martin) We need a better system to get the width + height of the image.
  applyLightbox = modifier((element) => lightbox(element, this.siteSettings));

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

  @action
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: false });
  }

  @action
  async saveGroups() {
    try {
      await ajax("/admin/config/upcoming-changes/groups", {
        type: "PUT",
        data: {
          setting: this.args.change.setting,
          group_names: this.args.change.groups.split(","),
        },
      });
      this.bufferedGroups = this.args.change.groups;
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("admin.upcoming_changes.groups_updated"),
        },
      });
    } catch (err) {
      popupAjaxError(err);
    }
  }

  @action
  async toggleChange() {
    if (this.toggleSettingDisabled) {
      this.toasts.error({
        duration: "short",
        data: {
          message: i18n("admin.upcoming_changes.toggled_too_fast"),
        },
      });
      return;
    }

    this.args.change.value = !this.args.change.value;
    this.toggleSettingDisabled = true;

    setTimeout(() => {
      this.toggleSettingDisabled = false;
    }, 5000);

    try {
      await ajax("/admin/config/upcoming-changes/toggle", {
        type: "POST",
        data: {
          setting_name: this.args.change.setting,
        },
      });

      this.toasts.success({
        duration: "short",
        data: {
          message: this.args.change.value
            ? i18n("admin.upcoming_changes.change_enabled")
            : i18n("admin.upcoming_changes.change_disabled"),
        },
      });
    } catch (error) {
      this.args.change.value = !this.args.change.value;
      return popupAjaxError(error);
    }
  }

  @bind
  onRegisterMenuForRow(menuApi) {
    this.registeredMenu = menuApi;
  }

  @action
  groupsChanged(newGroups) {
    this.args.change.groups = newGroups;
  }

  <template>
    <tr class="d-table__row upcoming-change-row">
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
              {{#if @change.upcoming_change.image_url}}
                <a
                  href={{@change.upcoming_change.image_url}}
                  class="lightbox upcoming-change__image-preview"
                  rel="nofollow ugc noopener"
                  data-target-width="1280"
                  data-target-height="720"
                  data-large-src={{@change.upcoming_change.image_url}}
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
            class="upcoming-change__badge"
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
      <td class="d-table__cell --detail upcoming-change__groups">
        <div class="d-table__mobile-label">
          {{i18n "admin.upcoming_changes.opt_in_groups"}}
        </div>

        {{#if (eq @change.upcoming_change.status "permanent")}}
          {{i18n "admin.upcoming_changes.permanent_no_group_selection"}}
        {{else}}
          <GroupSelector
            @groupFinder={{this.groupFinder}}
            @groupNames={{@change.groups}}
            @onChange={{this.groupsChanged}}
            @placeholderKey="admin.upcoming_changes.select_groups"
          />
        {{/if}}

        {{#if (notEq @change.groups this.bufferedGroups)}}
          <DButton
            class="upcoming-change__save-groups btn-primary"
            @icon="check"
            @size="small"
            @title="admin.upcoming_changes.save_groups"
            {{on "click" this.saveGroups}}
          />
        {{/if}}
      </td>
      <td class="d-table__cell --detail upcoming-change__toggle-cell">
        <div class="d-table__mobile-label">
          {{i18n "admin.upcoming_changes.enabled"}}
        </div>
        <DToggleSwitch
          @state={{@change.value}}
          class="upcoming-change__toggle"
          {{on "click" this.toggleChange}}
          disabled={{eq @change.upcoming_change.status "permanent"}}
        />
      </td>
    </tr>
  </template>
}
