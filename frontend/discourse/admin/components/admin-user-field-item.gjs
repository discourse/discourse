import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { i18n } from "discourse-i18n";
import { USER_FIELD_FLAGS } from "admin/lib/constants";
import UserField from "admin/models/user-field";
import DMenu from "float-kit/components/d-menu";

export default class AdminUserFieldItem extends Component {
  @service adminUserFields;
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
    return USER_FIELD_FLAGS.map((flag) => {
      if (this.args.userField[flag]) {
        return i18n(`admin.user_fields.${flag}.enabled`);
      }
    })
      .filter(Boolean)
      .join(", ");
  }

  get editUrl() {
    return this.router.urlFor("adminUserFields.edit", this.args.userField);
  }

  @action
  moveUp() {
    this.args.moveUpAction(this.args.userField);
    this.dMenu.close();
  }

  @action
  moveDown() {
    this.args.moveDownAction(this.args.userField);
    this.dMenu.close();
  }

  @action
  destroy() {
    this.args.destroyAction(this.args.userField);
    this.dMenu.close();
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  edit() {
    this.router.transitionTo("adminUserFields.edit", this.args.userField);
  }

  <template>
    <tr class="d-table__row admin-user_field-item">
      <td class="d-table__cell --overview">
        <a
          class="d-table__overview-name admin-user_field-item__name"
          href={{this.editUrl}}
        >
          {{@userField.name}}
        </a>
        <div class="d-table__overview-about">{{htmlSafe
            @userField.description
          }}</div>
        <div class="d-table__overview-flags">{{this.flags}}</div>
      </td>
      <td class="d-table__cell --detail">
        {{@userField.fieldTypeName}}
      </td>
      <td class="d-table__cell --controls">
        <div class="d-table__cell-actions">
          <DButton
            class="btn-default btn-small admin-user_field-item__edit"
            @action={{this.edit}}
            @label="admin.user_fields.edit"
          />

          <DMenu
            @identifier="user_field-menu"
            @title={{i18n "admin.config_areas.user_fields.more_options.title"}}
            @icon="ellipsis-vertical"
            @onRegisterApi={{this.onRegisterApi}}
          >
            <:content>
              <DropdownMenu as |dropdown|>
                {{#unless this.cantMoveUp}}
                  <dropdown.item>
                    <DButton
                      @label="admin.config_areas.user_fields.more_options.move_up"
                      @icon="arrow-up"
                      class="btn-transparent admin-user_field-item__move-up"
                      @action={{this.moveUp}}
                    />
                  </dropdown.item>
                {{/unless}}
                {{#unless this.cantMoveDown}}
                  <dropdown.item>
                    <DButton
                      @label="admin.config_areas.user_fields.more_options.move_down"
                      @icon="arrow-down"
                      class="btn-transparent admin-user_field-item__move-down"
                      @action={{this.moveDown}}
                    />
                  </dropdown.item>
                {{/unless}}

                <dropdown.item>
                  <DButton
                    @label="admin.config_areas.user_fields.delete"
                    @icon="trash-can"
                    class="btn-transparent btn-danger admin-user_field-item__delete"
                    @action={{this.destroy}}
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
