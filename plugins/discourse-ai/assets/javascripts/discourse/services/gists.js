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

  get isPm() {
    const routeName = this.router.currentRouteName;
    return routeName?.startsWith("userPrivateMessages");
  }

  get topics() {
    // covers discovery, filter, and pm routes
    const listTopics = this.routerAttributes?.list?.topics;
    if (listTopics) {
      return listTopics;
    }

    const directTopics = this.routerAttributes?.topics;
    if (directTopics) {
      return directTopics;
    }

    const topic = this.routerAttributes?.topic;
    if (!topic) {
      return null;
    }

    const relatedTopics = topic.relatedTopics;
    if (relatedTopics?.length) {
      return relatedTopics;
    }

    const suggestedTopics = topic.suggestedTopics;
    if (suggestedTopics?.length) {
      return suggestedTopics;
    }

    return null;
  }

  get showToggle() {
    return this.topics?.some((topic) => topic.ai_topic_gist);
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
