import Component from "@glimmer/component";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DButton from "discourse/ui-kit/d-button";

export default class WorkflowSettingFieldList extends Component {
  get fields() {
    return this.args.workflow.settingFields;
  }

  <template>
    {{#if this.fields.length}}
      <DButton
        class="btn-default workflows-settings__fields-manage"
        @icon="list"
        @label="discourse_workflows.settings.fields.manage_fields"
        @route="adminPlugins.show.discourse-workflows.show.settings.fields"
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
