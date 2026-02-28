import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import BrowseMore from "discourse/components/more-topics/browse-more";
import concatClass from "discourse/helpers/concat-class";
import { eq } from "discourse/truth-helpers";

export let registeredTabs = [];

export function clearRegisteredTabs() {
  registeredTabs.length = 0;
}

export default class MoreTopics extends Component {
  @service moreTopicsTabs;

  syncTopic = modifier((_, [topic]) => {
    this.moreTopicsTabs.setup(topic);
    return () => this.moreTopicsTabs.teardown();
  });

  <template>
    <div class="more-topics__container" {{this.syncTopic @topic}}>
      {{#if this.moreTopicsTabs.selectedTab}}
        <div
          class={{concatClass
            "more-topics__lists"
            (if (eq this.moreTopicsTabs.tabs.length 1) "single-list")
          }}
        >
          <this.moreTopicsTabs.selectedTab.component @topic={{@topic}} />
        </div>

        {{#if @topic.suggestedTopics.length}}
          <BrowseMore @topic={{@topic}} />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
