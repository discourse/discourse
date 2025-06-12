import Service, { service } from "@ember/service";
import { ForesightManager } from "js.foresight";
import { ajax } from "discourse/lib/ajax";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import PreloadStore from "discourse/lib/preload-store";

@disableImplicitInjections
export default class PrefetchService extends Service {
  @service currentUser;
  @service siteSettings;

  init() {
    super.init(...arguments);

    if (!this.isEnabled) {
      return;
    }

    ForesightManager.initialize({
      enableMousePrediction: true,
      enableTabPrediction: true,
      tabOffset: 3,
      defaultHitSlop: 10,
      debug: false,
      debuggerSettings: {
        isControlPanelDefaultMinimized: true,
        showNameTags: false,
      },
    });
  }

  get isEnabled() {
    if (!this.currentUser) {
      return;
    }

    // TODO: Ensure we track visits to topics properly if/when dropping the experimental site setting
    if (this.siteSettings.experimental_prefetch_allowed_groups === "") {
      return;
    }

    const userGroupIds = this.currentUser.groups.map((g) => g.id);
    const allowedGroups = this.siteSettings.experimental_prefetch_allowed_groups
      .split("|")
      .map((g) => parseInt(g, 10));

    if (
      !allowedGroups.length ||
      !userGroupIds.some((g) => allowedGroups.includes(g))
    ) {
      return;
    }

    return true;
  }

  async register(topicId, lastReadPostNumber) {
    if (!this.isEnabled) {
      return;
    }

    const element = document.querySelector(`a[data-topic-id="${topicId}"]`);
    if (!element) {
      return;
    }

    ForesightManager.instance.register({
      element,
      callback: async () => {
        const data = {
          forceLoad: true,
          // TODO: We're not tracking the vist here because it is just preloading
          // but we should track it properly if/when user loads the topic
          track_visit: false,
        };

        const url = `/t/${topicId}`;
        const jsonUrl =
          (lastReadPostNumber ? `${url}/${lastReadPostNumber}` : url) + ".json";
        const result = await ajax(jsonUrl, { data });

        PreloadStore.store(`topic_${topicId}`, result);
      },
      unregisterOnCallback: true,
    });
  }

  clearPrefetchedTopics() {
    if (!this.isEnabled) {
      return;
    }

    PreloadStore.clearTopicsPastLimit();
  }
}
