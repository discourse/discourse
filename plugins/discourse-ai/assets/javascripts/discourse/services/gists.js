import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";

const TOPIC_LIST_LAYOUT_KEY = "topicListLayout";
const PM_TOPIC_LIST_LAYOUT_KEY = "pmTopicListLayout";

export const TABLE_LAYOUT = "table";
export const TABLE_AI_LAYOUT = "table-ai";

export default class Gists extends Service {
  @service router;

  @tracked preference = localStorage.getItem(TOPIC_LIST_LAYOUT_KEY);
  @tracked pmPreference = localStorage.getItem(PM_TOPIC_LIST_LAYOUT_KEY);

  get routerAttributes() {
    return this.router.currentRoute.attributes;
  }

  get publicTopics() {
    return this.routerAttributes?.list?.topics;
  }

  get pmTopics() {
    return this.routerAttributes?.topics;
  }

  get isPm() {
    return !this.publicTopics && this.pmTopics;
  }

  get showToggle() {
    const topicList = this.publicTopics ?? this.pmTopics;
    return topicList?.some((topic) => topic.ai_topic_gist);
  }

  get currentPreference() {
    return this.isPm ? this.pmPreference : this.preference;
  }

  setPreference(value, isPm = false) {
    if (isPm) {
      this.pmPreference = value;
      localStorage.setItem(PM_TOPIC_LIST_LAYOUT_KEY, value);
    } else {
      this.preference = value;
      localStorage.setItem(TOPIC_LIST_LAYOUT_KEY, value);
    }
  }
}
