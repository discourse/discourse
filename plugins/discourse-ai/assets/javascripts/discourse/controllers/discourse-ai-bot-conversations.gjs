import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class DiscourseAiBotConversations extends Controller {
  @service currentUser;

  @tracked llm = null;
  @tracked agent = null;
  queryParams = ["llm", "agent"];

  get showPreview() {
    return !this.currentUser;
  }
}
