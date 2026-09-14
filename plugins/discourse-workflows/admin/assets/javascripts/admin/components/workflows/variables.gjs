import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import SiteSettingComponent from "discourse/admin/components/site-setting";
import SiteSetting from "discourse/admin/models/site-setting";
import { ajax } from "discourse/lib/ajax";
import { escapeExpression } from "discourse/lib/utilities";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import WorkflowVariableList from "./variable-list";
import VariablesPublishNotice from "./variables-publish-notice";

const VARIABLE_TYPE_TO_SITE_SETTING_TYPE = {
  string: { type: "string" },
  integer: { type: "integer" },
  boolean: { type: "bool" },
  enum: { type: "enum" },
  category: { type: "category" },
  category_list: { type: "list", list_type: "category" },
  group: { type: "group" },
  group_list: { type: "list", list_type: "group" },
  tag_list: { type: "list", list_type: "tag" },
  simple_list: { type: "simple_list" },
};

// trackChanges = false keeps these rows out of the global unsaved-changes
// banner used by the real site settings page, since they aren't site settings.
class WorkflowVariableRow extends SiteSettingComponent {
  @service toasts;

  trackChanges = false;

  // These rows have no "default" concept to compare against (buildVariableSetting
  // always sets default: ""), so the inherited overridden/reset UI is meaningless.
  get groupedOverridden() {
    return false;
  }

  get overridden() {
    return false;
  }

  get staffLogFilter() {
    return null;
  }

  async _save(settings) {
    const setting = settings[0];
    const wasPublished = Boolean(setting.workflow.activeVersionId);

    const response = await ajax(
      `/admin/plugins/discourse-workflows/workflows/${setting.workflow.id}/variables/${setting.workflowVariableId}/value.json`,
      { type: "PUT", data: { value: setting.buffered.get("value") } }
    );

    // Mutated in place (not reassigned) so other rows' @cached SiteSetting
    // wrappers aren't rebuilt, discarding their own in-progress edits.
    const savedVariable = setting.workflow.variables.find(
      (variable) => variable.id === setting.workflowVariableId
    );
    if (savedVariable) {
      Object.assign(savedVariable, response.variable);
    }

    setting.workflow.setProperties({
      versionId: response.workflow.version_id,
      activeVersionId: response.workflow.active_version_id,
      hasUnpublishedChanges: response.workflow.has_unpublished_changes,
    });

    if (
      wasPublished &&
      response.workflow.active_version_id &&
      !response.workflow.has_unpublished_changes
    ) {
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            "discourse_workflows.workflow_variables.value_published"
          ),
        },
      });
    }

    return response;
  }
}

function buildVariableSetting(variable, workflow) {
  const { type, list_type } =
    VARIABLE_TYPE_TO_SITE_SETTING_TYPE[variable.variable_type] ??
    VARIABLE_TYPE_TO_SITE_SETTING_TYPE.string;

  return SiteSetting.create({
    setting: variable.key,
    humanized_name: variable.label,
    description: escapeExpression(variable.description),
    type,
    list_type,
    valid_values: variable.type_options?.choices,
    value: variable.value ?? "",
    default: "",
    workflow,
    workflowVariableId: variable.id,
  });
}

export default class WorkflowVariables extends Component {
  get description() {
    const workflow = this.args.workflow;
    const willAutoPublish =
      Boolean(workflow.activeVersionId) && !workflow.hasUnpublishedChanges;

    return i18n(
      willAutoPublish
        ? "discourse_workflows.workflow_variables.description_will_publish"
        : "discourse_workflows.workflow_variables.description_will_draft"
    );
  }

  @cached
  get variableSettings() {
    return this.args.workflow.variables.map((variable) =>
      buildVariableSetting(variable, this.args.workflow)
    );
  }

  <template>
    {{#if @workflow.variables.length}}
      <VariablesPublishNotice @workflow={{@workflow}} />
    {{/if}}

    <DPageSubheader
      @descriptionLabel={{this.description}}
      @titleLabel={{i18n "discourse_workflows.workflow_variables.title"}}
    />

    <section class="form-horizontal settings workflows-variables__field-values">
      {{#each this.variableSettings as |setting|}}
        <WorkflowVariableRow @setting={{setting}} />
      {{/each}}
    </section>

    <WorkflowVariableList @workflow={{@workflow}} />
  </template>
}
