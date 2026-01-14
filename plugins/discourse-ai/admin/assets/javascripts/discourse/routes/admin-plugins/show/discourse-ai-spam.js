import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiSpamRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/plugins/discourse-ai/ai-spam.json");
  }
}
