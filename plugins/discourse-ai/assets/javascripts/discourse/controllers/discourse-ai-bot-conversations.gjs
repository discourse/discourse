import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class DiscourseAiBotConversations extends Controller {
  @tracked llm = null;
  @tracked persona = null;
  queryParams = ["llm", "persona"];
}
