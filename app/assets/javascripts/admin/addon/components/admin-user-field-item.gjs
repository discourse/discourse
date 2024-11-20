import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import UserField from "admin/models/user-field";

@tagName("")
export default class AdminUserFieldItem extends Component {
  @service adminUserFields;
  @service adminCustomUserFields;
  @service dialog;
  @service router;

  get fieldName() {
    return UserField.fieldTypeById(this.fieldType)?.name;
  }

  get cantMoveUp() {
    return this.args.userField.id === this.adminUserFields.firstField?.id;
  }

  get cantMoveDown() {
    return this.args.userField.id === this.adminUserFields.lastField?.id;
  }

  get flags() {
    const flags = [
      "editable",
      "show_on_profile",
      "show_on_user_card",
      "searchable",
    ];

    return flags
      .map((flag) => {
        if (this.args.userField[flag]) {
          return i18n(`admin.user_fields.${flag}.enabled`);
        }
      })
      .filter(Boolean)
      .join(", ");
  }

  @action
  edit() {
    this.router.transitionTo("adminUserFields.edit", this.args.userField);
  }

  <template>
    <div class="user-field">
      <div class="row">
        <div class="form-display">
          <b class="name">{{@userField.name}}</b>
          <br />
          <span class="description">{{htmlSafe @userField.description}}</span>
        </div>
        <div class="form-display field-type">{{@userField.fieldTypeName}}</div>
        <div class="form-element controls">
          <DButton
            @action={{this.edit}}
            @icon="pencil"
            @label="admin.user_fields.edit"
            class="btn-default edit"
          />
          <DButton
            @action={{fn @destroyAction @userField}}
            @icon="trash-can"
            @label="admin.user_fields.delete"
            class="btn-danger cancel"
          />
          <DButton
            @action={{fn @moveUpAction @userField}}
            @icon="arrow-up"
            @disabled={{this.cantMoveUp}}
            class="btn-default"
          />
          <DButton
            @action={{fn @moveDownAction @userField}}
            @icon="arrow-down"
            @disabled={{this.cantMoveDown}}
            class="btn-default"
          />
        </div>
      </div>
      <div class="row user-field-flags">{{this.flags}}</div>
    </div>
  </template>
}
