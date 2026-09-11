import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { settingFieldTypeLabel } from "../../lib/workflows/setting-field-types";

export default class WorkflowSettingFieldDefinitions extends Component {
  @service dialog;

  get fields() {
    return this.args.workflow.settingFields;
  }

  @action
  async delete(field) {
    const confirmed = await this.dialog.confirm({
      message: i18n("discourse_workflows.settings.fields.delete_confirm", {
        label: field.label,
      }),
      confirmButtonLabel: "discourse_workflows.delete",
      cancelButtonLabel: "discourse_workflows.cancel",
    });

    if (!confirmed) {
      return;
    }

    try {
      const response = await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}/setting-fields/${field.id}.json`,
        { type: "DELETE" }
      );

      this.args.workflow.settingFields = this.fields.filter(
        (f) => f.id !== field.id
      );
      this.args.workflow.setProperties({
        versionId: response.workflow.version_id,
        activeVersionId: response.workflow.active_version_id,
        hasUnpublishedChanges: response.workflow.has_unpublished_changes,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    {{#if this.fields.length}}
      <table class="d-table workflows-setting-fields-table">
        <thead class="d-table__header">
          <tr class="d-table__row">
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.settings.fields.field_label"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.settings.fields.field_key"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.settings.fields.field_type"
              }}</th>
          </tr>
        </thead>
        <tbody class="d-table__body">
          {{#each this.fields as |field|}}
            <tr class="d-table__row workflows-setting-fields-table__row">
              <td class="d-table__cell --overview">
                <LinkTo
                  class="d-table__overview-link"
                  @model={{field.id}}
                  @route="adminPlugins.show.discourse-workflows.show.settings.fields.edit"
                >
                  <span class="d-table__overview-name">{{field.label}}</span>
                </LinkTo>
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">
                  {{i18n "discourse_workflows.settings.fields.field_key"}}
                </div>
                <code class="workflows-setting-field-key">{{field.key}}</code>
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">
                  {{i18n "discourse_workflows.settings.fields.field_type"}}
                </div>
                <span class="workflows-setting-fields-table__type">
                  {{settingFieldTypeLabel field.field_type}}
                </span>
              </td>
              <td class="d-table__cell --controls">
                <div class="d-table__cell-actions">
                  <DButton
                    class="btn-default btn-small workflows-setting-fields-table__edit"
                    @icon="pencil"
                    @route="adminPlugins.show.discourse-workflows.show.settings.fields.edit"
                    @routeModels={{field.id}}
                    @title="discourse_workflows.edit"
                  />
                  <DButton
                    class="btn-default btn-small btn-danger workflows-setting-fields-table__delete"
                    @action={{fn this.delete field}}
                    @icon="trash-can"
                    @title="discourse_workflows.delete"
                  />
                </div>
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
      <DButton
        class="btn-default workflows-settings__fields-add"
        @icon="plus"
        @label="discourse_workflows.settings.fields.add_field"
        @route="adminPlugins.show.discourse-workflows.show.settings.fields.new"
      />
    {{else}}
      <AdminConfigAreaEmptyList
        @ctaLabel="discourse_workflows.settings.fields.add_field"
        @ctaRoute="adminPlugins.show.discourse-workflows.show.settings.fields.new"
        @emptyLabel="discourse_workflows.settings.fields.no_fields"
      />
    {{/if}}
  </template>
}
