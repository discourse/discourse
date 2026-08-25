import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import AdminUserFieldItem from "discourse/admin/components/admin-user-field-item";
import UserField from "discourse/admin/models/user-field";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreasUserFieldsList extends Component {
  @service dialog;
  @service toasts;
  @service adminUserFields;

  /** @type {any} */
  fieldTypes = UserField.fieldTypes();

  fieldLabel = (field) => field.name;

  get fields() {
    return this.adminUserFields.userFields;
  }

  get sortedFields() {
    return this.adminUserFields.sortedUserFields;
  }

  /**
   * Applies a committed move by renumbering every displaced field from its
   * new slot — a drag can jump several rows, which the old adjacent-swap
   * persistence could not express.
   *
   * @param {Object} move - The normalized move from the list.
   */
  @action
  async handleMove(move) {
    try {
      await Promise.all(
        move.proposedToItems.map((field, index) => {
          const position = index + 1;
          if (field.get("position") === position) {
            return null;
          }
          return field.update({ position });
        })
      );
    } catch (error) {
      popupAjaxError(error);
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
      removeValueFromArray(this.fields, field);
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
        {{! The reorderable list renders the tbody itself, which the static
            table-group rule cannot see from here. }}
        {{! eslint-disable-next-line ember/template-table-groups }}
        <table class="d-table user-fields">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell --reorder"></th>
              <th class="d-table__header-cell">{{i18n
                  "admin.config_areas.user_fields.field"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "admin.config_areas.user_fields.type"
                }}</th>
            </tr>
          </thead>
          <DReorderableList
            @items={{this.sortedFields}}
            @key="id"
            @label={{this.fieldLabel}}
            @onMove={{this.handleMove}}
            @controls="manual"
            @tag="tbody"
            @itemTag="tr"
            @rowClass="d-table__row admin-user_field-item"
            class="d-table__body"
          >
            <:row as |field controls|>
              <AdminUserFieldItem
                @controls={{controls}}
                @userField={{field}}
                @fieldTypes={{this.fieldTypes}}
                @destroyAction={{this.destroyField}}
              />
            </:row>
          </DReorderableList>
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
