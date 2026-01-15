import Controller from "@ember/controller";
import { action } from "@ember/object";
import DiscourseURL from "discourse/lib/url";

export default class AdminPluginsDiscourseSubscriptionsPlansIndexController extends Controller {
  @action
  editPlan(id) {
    return DiscourseURL.redirectTo(
      `/admin/plugins/discourse-subscriptions/plans/${id}`
    );
  }
}
