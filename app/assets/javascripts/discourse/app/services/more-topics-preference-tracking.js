import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

const TOPIC_LIST_PREFERENCE_KEY = "more-topics-list-preference";

@disableImplicitInjections
export default class MoreTopicsPreferenceTracking extends Service {
  @service keyValueStore;

  @tracked selectedTab = null;
  topicLists = new TrackedMap();
  memoryTab = this.keyValueStore.get(TOPIC_LIST_PREFERENCE_KEY);

  selectTab(value) {
    this.selectedTab = value;

    // Don't change the preference when selecting related PMs.
    // It messes with the topics pref.
    const rememberPref = value !== "related-messages";

    if (rememberPref) {
      this.keyValueStore.set({ key: TOPIC_LIST_PREFERENCE_KEY, value });
      this.memoryTab = value;
    }
  }

  registerTopicList(item) {
    // We have a preference stored and the list exists.
    if (this.memoryTab === item.id) {
      this.selectedTab = item.id;
    }

    // Use the first list as a default. Future lists may override this
    // if they match the stored preference.
    this.selectedTab ??= item.id;

    this.topicLists.set(item.id, item);
  }

  removeTopicList(itemId) {
    this.topicLists.delete(itemId);

    if (this.selectedTab === itemId) {
      this.selectedTab = this.topicLists.keys().next();
    }
  }
}
