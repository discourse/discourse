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

/**
 * The reordering surface behind `enable_new_reordering_controls`. Mirrors
 * `admin-user-field-item.gjs`, over the shared reorderable list.
 *
 * TODO (ui-kit-reorderable-list-cleanup) rename this over `admin-user-field-item.gjs`
 * and drop the branch in user-fields-list-reorderable.gjs.
 */
export default class AdminUserFieldItem extends Component {
  @service router;

  get fieldName() {
    return UserField.fieldTypeById(this.fieldType)?.name;
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
    <td class="d-table__cell --drag-handle">
      <@controls.handle />
    </td>
    <td class="d-table__cell --overview">
      <LinkTo
        class="d-table__overview-link"
        @route="adminUserFields.edit"
        @model={{@userField}}
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
          @identifier="user_field-menu"
          @title={{i18n "admin.config_areas.user_fields.more_options.title"}}
          @icon="ellipsis-vertical"
          @onRegisterApi={{this.onRegisterApi}}
          @triggerClass="btn-default"
        >
          <:content>
            <DDropdownMenu as |dropdown|>
              <dropdown.item>
                <DButton
                  @label="admin.config_areas.user_fields.delete"
                  @icon="trash-can"
                  class="btn-transparent --danger admin-user_field-item__delete"
                  @action={{this.destroy}}
                />
              </dropdown.item>
            </DDropdownMenu>
          </:content>
        </DMenu>
      </div>
    </td>
  </template>
}
