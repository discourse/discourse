import Service, { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

const TOPIC_LIST_PREFERENCE_KEY = "more-topics-list-preference";

export default class MoreTopicsPreferenceTracking extends Service {
  @service keyValueStore;

  @tracked preference;

  init() {
    super.init(...arguments);
    this.preference = this.keyValueStore.get(TOPIC_LIST_PREFERENCE_KEY);
  }

  updatePreference(value, rememberPref = false) {
    if (!rememberPref) {
      this.keyValueStore.set({ key: TOPIC_LIST_PREFERENCE_KEY, value });
    }

    this.preference = value;
  }
}
