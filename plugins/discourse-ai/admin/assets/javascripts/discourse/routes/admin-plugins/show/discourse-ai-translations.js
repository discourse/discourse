import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiTranslationsRoute extends DiscourseRoute {
  @service store;

  model() {
    return ajax("/admin/plugins/discourse-ai/ai-translations.json");
  }
}
