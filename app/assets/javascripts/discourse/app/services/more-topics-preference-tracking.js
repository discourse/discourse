import Service, { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

const TOPIC_LIST_PREFERENCE_KEY = "more-topics-list-preference";

export default class MoreTopicsPreferenceTracking extends Service {
  @service keyValueStore;

  @tracked selectedTab = null;
  @tracked topicLists = [];

  memoryTab = null;

  init() {
    super.init(...arguments);
    this.memoryTab = this.keyValueStore.get(TOPIC_LIST_PREFERENCE_KEY);
  }

  updatePreference(value) {
    // Don't change the preference when selecting related PMs.
    // It messes with the topics pref.
    const rememberPref = value !== "related-messages";

    if (rememberPref) {
      this.keyValueStore.set({ key: TOPIC_LIST_PREFERENCE_KEY, value });
      this.memoryTab = value;
    }

    this.selectedTab = value;
  }

  registerTopicList(item) {
    // We have a preference stored and the list exists.
    if (this.memoryTab && this.memoryTab === item.id) {
      this.selectedTab = item.id;
    }

    // Use the first list as a default. Future lists may override this
    // if they match the stored preference.
    if (!this.selectedTab) {
      this.selectedTab = item.id;
    }

    this.topicLists = [...this.topicLists, item];
  }

  removeTopicList(itemId) {
    this.topicLists = this.topicLists.filter((item) => item.id !== itemId);

    if (this.selectedTab === itemId) {
      this.selectedTab = this.topicLists[0]?.id;
    }
  }
}
