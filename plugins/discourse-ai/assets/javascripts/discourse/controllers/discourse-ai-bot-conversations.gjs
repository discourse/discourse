import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class DiscourseAiBotConversations extends Controller {
  @tracked llm = null;
  @tracked agent = null;
  @tracked preserveSidebar = null;
  queryParams = ["llm", "agent", "preserveSidebar"];
}
