import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { registeredTabs } from "discourse/components/more-topics";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { applyValueTransformer } from "discourse/lib/transformer";

@disableImplicitInjections
export default class MoreTopicsTabsService extends Service {
  @service currentUser;
  @service keyValueStore;

  @tracked topic = null;
  @tracked preferredTab = null;

  get context() {
    return this.topic?.get("isPrivateMessage") ? "pm" : "topic";
  }

  get tabs() {
    if (!this.topic) {
      return [];
    }
    const defaultTabs = registeredTabs.filter((tab) =>
      tab.condition({ topic: this.topic, context: this.context })
    );
    return applyValueTransformer("more-topics-tabs", defaultTabs, {
      currentContext: this.context,
      user: this.currentUser,
      topic: this.topic,
    });
  }

  get selectedTab() {
    return this.tabs.find((tab) => tab === this.preferredTab) || this.tabs[0];
  }

  setup(topic) {
    this.topic = topic;
    let savedId = this.keyValueStore.get(
      `more-topics-preference-${this.context}`
    );
    savedId ||= this.keyValueStore.get("more-topics-list-preference");
    this.preferredTab =
      (savedId && this.tabs.find((tab) => tab.id === savedId)) || null;
  }

  teardown() {
    this.topic = null;
    this.preferredTab = null;
  }

  @action
  selectTab(tab) {
    this.preferredTab = tab;
    this.keyValueStore.set({
      key: `more-topics-preference-${this.context}`,
      value: tab.id,
    });
  }

  @action
  isActiveTab(tab) {
    return tab?.id === this.selectedTab?.id;
  }
}
