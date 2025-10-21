import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import AdminUserFieldItem from "admin/components/admin-user-field-item";
import UserField from "admin/models/user-field";

export default class AdminConfigAreasUserFieldsList extends Component {
  @service dialog;
  @service toasts;
  @service adminUserFields;

  /** @type {any} */
  fieldTypes = UserField.fieldTypes();

  get fields() {
    return this.adminUserFields.userFields;
  }

  get sortedFields() {
    return this.adminUserFields.sortedUserFields;
  }

  @action
  moveUp(field) {
    const idx = this.sortedFields.indexOf(field);
    if (idx) {
      const prev = this.sortedFields.objectAt(idx - 1);
      const prevPos = prev.get("position");

      prev.update({ position: field.get("position") });
      field.update({ position: prevPos });
    }
  }

  @action
  moveDown(field) {
    const idx = this.sortedFields.indexOf(field);
    if (idx > -1) {
      const next = this.sortedFields.objectAt(idx + 1);
      const nextPos = next.get("position");

      next.update({ position: field.get("position") });
      field.update({ position: nextPos });
    }
  }

  @action
  destroyField(field) {
    this.dialog.deleteConfirm({
      title: i18n("admin.user_fields.delete_confirm"),
      didConfirm: () => {
        this.#deleteField(field);
      },
    });
  }

  async #deleteField(field) {
    try {
      await field.destroyRecord();
      this.fields.removeObject(field);
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("admin.config_areas.user_fields.delete_successful"),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="container admin-user_fields">
      {{#if this.fields}}
        <table class="d-table user-fields">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell">{{i18n
                  "admin.config_areas.user_fields.field"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "admin.config_areas.user_fields.type"
                }}</th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each this.sortedFields as |field|}}
              <AdminUserFieldItem
                @userField={{field}}
                @fieldTypes={{this.fieldTypes}}
                @destroyAction={{this.destroyField}}
                @moveUpAction={{this.moveUp}}
                @moveDownAction={{this.moveDown}}
              />
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <AdminConfigAreaEmptyList
          @ctaLabel="admin.user_fields.add"
          @ctaRoute="adminUserFields.new"
          @ctaClass="admin-user_fields__add-emoji"
          @emptyLabel="admin.user_fields.no_user_fields"
        />
      {{/if}}
    </div>
  </template>
}
