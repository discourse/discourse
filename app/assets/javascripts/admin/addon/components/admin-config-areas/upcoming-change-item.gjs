import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import UpcomingChangeEditGroups from "admin/components/admin-config-areas/upcoming-change-edit-groups";
import DMenu from "float-kit/components/d-menu";

export default class UpcomingChangeItem extends Component {
  @service modal;

  registeredMenu = null;

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
  toggleChange() {
    this.args.change.value = !this.args.change.value;
  }

  @action
  showImage() {
    if (this.args.change.upcoming_change.image_url) {
      window.open(this.args.change.upcoming_change.image_url, "_blank");
      this.registeredMenu?.close();
    }
  }

  @action
  async editGroups() {
    const closeData = await this.modal.show(UpcomingChangeEditGroups, {
      model: {
        setting: this.args.change.setting,
        groups: this.args.change.groups || [],
      },
    });
    this.args.change.groups = closeData?.groups;
  }

  @bind
  onRegisterMenuForRow(menuApi) {
    this.registeredMenu = menuApi;
  }

  <template>
    <tr class="d-table__row upcoming-change-row">
      <td class="d-table__cell --overview">
        <div class="d-table__overview-name">
          {{@change.humanized_name}}
        </div>
        {{#if @change.description}}
          <div class="d-table__overview-about upcoming-change__description">
            {{@change.description}}

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

            {{#if @change.groups}}
              <span class="upcoming-change__opt-in-groups-label">
                {{i18n "admin.upcoming_changes.opt_in_groups"}}:
                {{@change.groups}}
              </span>
            {{/if}}
          </div>
        {{/if}}

        {{#if @change.plugin}}
          <span class="upcoming-change__plugin upcoming-change__badge --plugin">
            {{icon "plug"}}
            {{@change.plugin}}
          </span>
        {{/if}}
      </td>
      <td class="d-table__cell --detail upcoming-change__labels">
        <div class="d-table__mobile-label">
          {{i18n "admin.upcoming_changes.labels"}}
        </div>
        <div class="upcoming-change__badges">
          <span
            title={{i18n
              (concat
                "admin.upcoming_changes.statuses."
                @change.upcoming_change.status
              )
            }}
            class="upcoming-change__badge"
          >
            {{icon "far-circle-dot"}}
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
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">
          {{i18n "admin.upcoming_changes.enabled"}}
        </div>
        <DToggleSwitch
          @state={{@change.value}}
          class="upcoming-change__toggle"
          {{on "click" this.toggleChange}}
        />
      </td>
      <td class="d-table__cell --controls">
        <div class="d-table__cell-actions">
          <DMenu
            @identifier="upcoming-change-menu"
            @icon="ellipsis"
            @class="btn-default upcoming-change__more-actions"
            @onRegisterApi={{this.onRegisterMenuForRow}}
          >
            <:content>
              <DropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    class="btn-transparent upcoming-change__show-image"
                    @label="admin.upcoming_changes.show_image"
                    @icon="image"
                    @action={{this.showImage}}
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    class="btn-transparent edit-groups"
                    @label="admin.upcoming_changes.edit_groups"
                    @icon="users"
                    @action={{this.editGroups}}
                  />
                </dropdown.item>
              </DropdownMenu>
            </:content>
          </DMenu>
        </div>
      </td>
    </tr>
  </template>
}
