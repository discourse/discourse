import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";

const TOPIC_LIST_LAYOUT_KEY = "topicListLayout";
const DEPRECATED_PM_TOPIC_LIST_LAYOUT_KEY = "pmTopicListLayout";

export const TABLE_LAYOUT = "table";
export const TABLE_AI_LAYOUT = "table-ai";

export default class Gists extends Service {
  @service router;

  @tracked preference = this.#loadPreference();

  #loadPreference() {
    // Migrate from old PM-specific key if it exists and main key doesn't
    const oldPmPreference = localStorage.getItem(
      DEPRECATED_PM_TOPIC_LIST_LAYOUT_KEY
    );
    const currentPreference = localStorage.getItem(TOPIC_LIST_LAYOUT_KEY);

    if (oldPmPreference && !currentPreference) {
      // Migrate the PM preference to the unified key
      localStorage.setItem(TOPIC_LIST_LAYOUT_KEY, oldPmPreference);
      localStorage.removeItem(DEPRECATED_PM_TOPIC_LIST_LAYOUT_KEY);
      return oldPmPreference;
    } else if (oldPmPreference) {
      // Just clean up the old key if main key exists
      localStorage.removeItem(DEPRECATED_PM_TOPIC_LIST_LAYOUT_KEY);
    }

    return currentPreference;
  }

  get routerAttributes() {
    return this.router.currentRoute.attributes;
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
    return this.preference;
  }

  setPreference(value) {
    this.preference = value;
    localStorage.setItem(TOPIC_LIST_LAYOUT_KEY, value);
  }
}
