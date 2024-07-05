import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { SYSTEM_FLAG_IDS } from "discourse/lib/constants";
import i18n from "discourse-common/helpers/i18n";
import DMenu from "float-kit/components/d-menu";

export default class AdminFlagItem extends Component {
  @service dialog;
  @service router;

  @tracked enabled = this.args.flag.enabled;
  @tracked isSaving = false;

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
    this.isSaving = true;

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
        this.isSaving = false;
      });
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  moveUp() {
    this.isSaving = true;
    this.dMenu.close();
    this.args.moveFlagCallback(this.args.flag, "up").finally(() => {
      this.isSaving = false;
    });
  }

  @action
  moveDown() {
    this.isSaving = true;
    this.dMenu.close();
    this.args.moveFlagCallback(this.args.flag, "down").finally(() => {
      this.isSaving = false;
    });
  }
  @action
  edit() {
    this.router.transitionTo("adminConfig.flags.edit", this.args.flag);
  }

  @action
  delete() {
    this.isSaving = true;
    this.dialog.yesNoConfirm({
      message: i18n("admin.config_areas.flags.delete_confirm", {
        name: this.args.flag.name,
      }),
      didConfirm: () => {
        this.args.deleteFlagCallback(this.args.flag).finally(() => {
          this.isSaving = false;
        });
      },
      didCancel: () => {
        this.isSaving = false;
      },
    });
    this.dMenu.close();
  }

  <template>
    <tr
      class={{concatClass
        "admin-flag-item"
        @flag.name_key
        (if this.isSaving "saving")
      }}
    >
      <td>
        <p class="admin-flag-item__name">{{@flag.name}}</p>
        <p class="admin-flag-item__description">{{htmlSafe
            @flag.description
          }}</p>
      </td>
      <td>
        <div class="admin-flag-item__options">
          <DToggleSwitch
            @state={{this.enabled}}
            class="admin-flag-item__toggle {{@flag.name_key}}"
            {{on "click" (fn this.toggleFlagEnabled @flag)}}
          />

          <DButton
            class="btn btn-secondary admin-flag-item__edit"
            @action={{this.edit}}
            @label="admin.config_areas.flags.edit"
            @disabled={{not this.canEdit}}
            @title={{this.editTitle}}
          />

          {{#if this.canMove}}
            <DMenu
              @identifier="flag-menu"
              @title={{i18n "admin.config_areas.flags.more_options.title"}}
              @icon="ellipsis-v"
              @onRegisterApi={{this.onRegisterApi}}
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  {{#unless @isFirstFlag}}
                    <dropdown.item>
                      <DButton
                        @label="admin.config_areas.flags.more_options.move_up"
                        @icon="arrow-up"
                        @class="btn-transparent admin-flag-item__move-up"
                        @action={{this.moveUp}}
                      />
                    </dropdown.item>
                  {{/unless}}
                  {{#unless @isLastFlag}}
                    <dropdown.item>
                      <DButton
                        @label="admin.config_areas.flags.more_options.move_down"
                        @icon="arrow-down"
                        @class="btn-transparent admin-flag-item__move-down"
                        @action={{this.moveDown}}
                      />
                    </dropdown.item>
                  {{/unless}}

                  <dropdown.item>
                    <DButton
                      @label="admin.config_areas.flags.delete"
                      @icon="trash-alt"
                      class="btn-transparent admin-flag-item__delete"
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
