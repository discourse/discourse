import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminReportsIndexController extends Controller {
  queryParams = ["group"];
  group = null;

  @action
  updateGroupFilter(groupKey) {
    this.set("group", groupKey === "all" ? null : groupKey);
  }
}
