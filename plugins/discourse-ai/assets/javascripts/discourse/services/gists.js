import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";

export default class Gists extends Service {
  @service router;

  @tracked preference = localStorage.getItem("topicListLayout");

  get shouldShow() {
    return this.router.currentRoute.attributes?.list?.topics?.some(
      (topic) => topic.ai_topic_gist
    );
  }

  setPreference(value) {
    this.preference = value;
    localStorage.setItem("topicListLayout", value);

    if (this.preference === "table-ai") {
      localStorage.setItem("aiPreferred", true);
    }
  }
}
