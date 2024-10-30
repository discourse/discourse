import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq, gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import BrowseMore from "discourse/components/more-topics/browse-more";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";

export let registeredTabs = [];

export function clearRegisteredTabs() {
  registeredTabs.length = 0;
}

export default class MoreTopics extends Component {
  @service currentUser;
  @service keyValueStore;

  @tracked selectedTab = this.initialTab;

  get initialTab() {
    let savedId = this.keyValueStore.get(
      `more-topics-preference-${this.context}`
    );

    // Fallback to the old setting
    savedId ||= this.keyValueStore.get("more-topics-list-preference");

    return (
      (savedId && this.tabs.find((tab) => tab.id === savedId)) || this.tabs[0]
    );
  }

  get activeTab() {
    return this.tabs.find((tab) => tab === this.selectedTab) || this.tabs[0];
  }

  get context() {
    return this.args.topic.get("isPrivateMessage") ? "pm" : "topic";
  }

  @cached
  get tabs() {
    const defaultTabs = registeredTabs.filter((tab) =>
      tab.condition({ topic: this.args.topic, context: this.context })
    );

    return applyValueTransformer("more-topics-tabs", defaultTabs, {
      currentContext: this.context,
      user: this.currentUser,
      topic: this.args.topic,
    });
  }

  @action
  selectTab(tab) {
    this.selectedTab = tab;
    this.keyValueStore.set({
      key: `more-topics-preference-${this.context}`,
      value: tab.id,
    });
  }

  <template>
    <div class="more-topics__container">
      {{#if (gt this.tabs.length 1)}}
        <div class="row">
          <ul class="nav nav-pills">
            {{#each this.tabs as |tab|}}
              <li>
                <DButton
                  @action={{fn this.selectTab tab}}
                  @translatedLabel={{tab.name}}
                  @translatedTitle={{tab.name}}
                  @icon={{tab.icon}}
                  class={{if (eq tab.id this.activeTab.id) "active"}}
                />
              </li>
            {{/each}}
          </ul>
        </div>
      {{/if}}

      {{#if this.activeTab}}
        <div
          class={{concatClass
            "more-topics__lists"
            (if (eq this.tabs.length 1) "single-list")
          }}
        >
          <this.activeTab.component @topic={{@topic}} />
        </div>

        {{#if @topic.suggestedTopics.length}}
          <BrowseMore @topic={{@topic}} />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
