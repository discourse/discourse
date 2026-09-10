import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigMcpAccessEditRoute extends DiscourseRoute {
  model({ group_id }) {
    const model = this.modelFor("adminConfig.mcp.access");
    model.access_rule = model.access_rules.find(
      (rule) => rule.group_id.toString() === group_id
    );
    return model;
  }
}
