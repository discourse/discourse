import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { SYSTEM_FLAG_IDS } from "discourse/lib/constants";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class AdminFlagItem extends Component {
  @service dialog;
  @service router;

  @tracked enabled = this.args.flag.enabled;
  @tracked isSaved = true;

  get canMove() {
    return this.args.flag.id !== SYSTEM_FLAG_IDS.notify_user;
  }

  get canEdit() {
    return (
      !Object.values(SYSTEM_FLAG_IDS).includes(this.args.flag.id) &&
      !this.args.flag.is_used
    );
  }

  get editTitle() {
    return this.canEdit
      ? "admin.config_areas.flags.form.edit_flag"
      : "admin.config_areas.flags.form.non_editable";
  }

  get deleteTitle() {
    return this.canEdit
      ? "admin.config_areas.flags.form.edit_flag"
      : "admin.config_areas.flags.form.non_editable";
  }

  @action
  toggleFlagEnabled(flag) {
    this.enabled = !this.enabled;
    this.isSaved = false;

    return ajax(`/admin/config/flags/${flag.id}/toggle`, {
      type: "PUT",
    })
      .then(() => {
        this.args.flag.enabled = this.enabled;
      })
      .catch((error) => {
        this.enabled = !this.enabled;
        return popupAjaxError(error);
      })
      .finally(() => {
        this.isSaved = true;
      });
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  moveUp() {
    this.isSaved = false;
    this.args.moveFlagCallback(this.args.flag, "up").finally(() => {
      this.isSaved = true;
      this.dMenu.close();
    });
  }

  @action
  moveDown() {
    this.isSaved = false;
    this.args.moveFlagCallback(this.args.flag, "down").finally(() => {
      this.isSaved = true;
      this.dMenu.close();
    });
  }

  @action
  edit() {
    this.router.transitionTo("adminConfig.flags.edit", this.args.flag);
  }

  @action
  delete() {
    this.isSaved = false;
    this.dialog.yesNoConfirm({
      message: i18n("admin.config_areas.flags.delete_confirm", {
        name: this.args.flag.name,
      }),
      didConfirm: async () => {
        try {
          await this.args.deleteFlagCallback(this.args.flag);
          this.isSaved = true;
          this.dMenu.close();
        } catch (error) {
          popupAjaxError(error);
        }
      },
      didCancel: () => {
        this.isSaved = true;
        this.dMenu.close();
      },
    });
  }

  <template>
    <tr
      class={{concatClass
        "d-admin-row__content admin-flag-item"
        @flag.name_key
        (if this.isSaved "saved")
      }}
    >
      <td class="d-admin-row__overview">
        <div
          class="d-admin-row__overview-name admin-flag-item__name"
        >{{@flag.name}}</div>
        <div class="d-admin-row__overview-about">{{htmlSafe
            @flag.description
          }}</div>
      </td>
      <td class="d-admin-row__detail">
        <div class="d-admin-row__mobile-label">
          {{i18n "admin.config_areas.flags.enabled"}}
        </div>
        <DToggleSwitch
          @state={{this.enabled}}
          class="admin-flag-item__toggle {{@flag.name_key}}"
          {{on "click" (fn this.toggleFlagEnabled @flag)}}
        />
      </td>
      <td class="d-admin-row__controls">
        <div class="d-admin-row__controls-options">

          <DButton
            class="btn-small admin-flag-item__edit"
            @action={{this.edit}}
            @label="admin.config_areas.flags.edit"
            @disabled={{not this.canEdit}}
            @title={{this.editTitle}}
          />

          {{#if this.canMove}}
            <DMenu
              @identifier="flag-menu"
              @title={{i18n "admin.config_areas.flags.more_options.title"}}
              @icon="ellipsis-vertical"
              @onRegisterApi={{this.onRegisterApi}}
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  {{#unless @isFirstFlag}}
                    <dropdown.item>
                      <DButton
                        @label="admin.config_areas.flags.more_options.move_up"
                        @icon="arrow-up"
                        class="btn-transparent admin-flag-item__move-up"
                        @action={{this.moveUp}}
                      />
                    </dropdown.item>
                  {{/unless}}
                  {{#unless @isLastFlag}}
                    <dropdown.item>
                      <DButton
                        @label="admin.config_areas.flags.more_options.move_down"
                        @icon="arrow-down"
                        class="btn-transparent admin-flag-item__move-down"
                        @action={{this.moveDown}}
                      />
                    </dropdown.item>
                  {{/unless}}

                  <dropdown.item>
                    <DButton
                      @label="admin.config_areas.flags.delete"
                      @icon="trash-can"
                      class="btn-transparent admin-item__delete"
                      @action={{this.delete}}
                      @disabled={{not this.canEdit}}
                      @title={{this.deleteTitle}}
                    />
                  </dropdown.item>
                </DropdownMenu>
              </:content>
            </DMenu>
          {{/if}}
        </div>
      </td>
    </tr>
  </template>
}
