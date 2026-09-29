import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class DiscourseAiSearchController extends Controller {
  @tracked q = null;
  @tracked topic = null;
  @tracked scope = null;

  queryParams = ["q", "topic", "scope"];

  @action
  updateQuery(query) {
    this.q = query;
  }
}
