import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import BrowseMore from "discourse/components/more-topics/browse-more";
import { eq } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export {
  clearRegisteredTabs,
  registeredTabs,
} from "discourse/lib/plugin-registries/more-topics-tabs";

export default class MoreTopics extends Component {
  @service moreTopicsTabs;

  syncTopic = modifier((_, [topic]) => {
    this.moreTopicsTabs.setup(topic);
    return () => this.moreTopicsTabs.teardown();
  });

  // A tab registered with an import thunk loads its component on first show.
  get tabComponent() {
    const component = this.moreTopicsTabs.selectedTab?.component;

    if (typeof component === "function" && !component.prototype) {
      return component().then((module) => module.default);
    }

    return component;
  }

  <template>
    <div class="more-topics__container" {{this.syncTopic @topic}}>
      {{#if this.moreTopicsTabs.selectedTab}}
        <div
          class={{dConcatClass
            "more-topics__lists"
            (if (eq this.moreTopicsTabs.tabs.length 1) "single-list")
          }}
        >
          <DAsyncContent @asyncData={{this.tabComponent}}>
            <:loading></:loading>
            <:content as |Tab|><Tab @topic={{@topic}} /></:content>
          </DAsyncContent>
        </div>

        {{#if @topic.suggestedTopics.length}}
          <BrowseMore @topic={{@topic}} />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
