import Component from "@glimmer/component";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { USER_FIELD_FLAGS } from "discourse/admin/lib/constants";
import UserField from "discourse/admin/models/user-field";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

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
        <LinkTo
          class="d-table__overview-link"
          @model={{@userField}}
          @route="adminUserFields.edit"
        >
          <div class="d-table__overview-name admin-user_field-item__name">
            {{@userField.name}}
          </div>
          <div class="d-table__overview-about">{{trustHTML
              @userField.description
            }}</div>
        </LinkTo>
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
            @icon="ellipsis-vertical"
            @identifier="user_field-menu"
            @onRegisterApi={{this.onRegisterApi}}
            @title={{i18n "admin.config_areas.user_fields.more_options.title"}}
            @triggerClass="btn-default"
          >
            <:content>
              <DDropdownMenu as |dropdown|>
                {{#unless this.cantMoveUp}}
                  <dropdown.item>
                    <DButton
                      class="btn-transparent admin-user_field-item__move-up"
                      @action={{this.moveUp}}
                      @icon="arrow-up"
                      @label="admin.config_areas.user_fields.more_options.move_up"
                    />
                  </dropdown.item>
                {{/unless}}
                {{#unless this.cantMoveDown}}
                  <dropdown.item>
                    <DButton
                      class="btn-transparent admin-user_field-item__move-down"
                      @action={{this.moveDown}}
                      @icon="arrow-down"
                      @label="admin.config_areas.user_fields.more_options.move_down"
                    />
                  </dropdown.item>
                {{/unless}}

                <dropdown.item>
                  <DButton
                    class="btn-transparent --danger admin-user_field-item__delete"
                    @action={{this.destroy}}
                    @icon="trash-can"
                    @label="admin.config_areas.user_fields.delete"
                  />
                </dropdown.item>
              </DDropdownMenu>
            </:content>
          </DMenu>
        </div>
      </td>
    </tr>
  </template>
}
