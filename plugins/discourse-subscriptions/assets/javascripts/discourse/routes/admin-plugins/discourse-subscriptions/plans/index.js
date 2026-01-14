import Route from "@ember/routing/route";
import AdminPlan from "discourse/plugins/discourse-subscriptions/discourse/models/admin-plan";

export default class AdminPluginsDiscourseSubscriptionsPlansIndexRoute extends Route {
  model() {
    return AdminPlan.findAll();
  }
}
