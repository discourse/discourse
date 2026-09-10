import DiscourseRoute from "discourse/routes/discourse";

const WORKFLOW_ROUTE = "adminPlugins.show.discourse-workflows.show";

export default class DiscourseWorkflowsShowSettingsFieldsEditRoute extends DiscourseRoute {
  model(params) {
    return {
      ...this.modelFor(WORKFLOW_ROUTE),
      settingFieldId: params.setting_field_id,
    };
  }
}
