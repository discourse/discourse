import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import PluginOutlet from "discourse/components/plugin-outlet";
import PrivateMessageMap from "discourse/components/topic-map/private-message-map";
import TopicMapExpanded from "discourse/components/topic-map/topic-map-expanded";
import TopicMapSummary from "discourse/components/topic-map/topic-map-summary";
import concatClass from "discourse/helpers/concat-class";

export default class TopicMap extends Component {
  @tracked collapsed = !this.args.model.has_summary;

  get userFilters() {
    return this.args.postStream.userFilters || [];
  }

  @action
  toggleMap() {
    this.collapsed = !this.collapsed;
  }

  <template>
    <section class={{concatClass "map" (if this.collapsed "map-collapsed")}}>
      <TopicMapSummary
        @topic={{@model}}
        @topicDetails={{@topicDetails}}
        @toggleMap={{this.toggleMap}}
        @collapsed={{this.collapsed}}
        @userFilters={{this.userFilters}}
      />
    </section>
    {{#unless this.collapsed}}
      <section
        class="topic-map-expanded"
        id="topic-map-expanded__aria-controls"
      >
        <TopicMapExpanded
          @topicDetails={{@topicDetails}}
          @userFilters={{this.userFilters}}
        />
      </section>
    {{/unless}}

    <PluginOutlet
      @name="topic-map-expanded-after"
      @connectorTagName="span"
      @outletArgs={{hash
        topic=@model
        postStream=@postStream
        cancelFilter=@cancelFilter
        showTopReplies=@showTopReplies
      }}
    />

    {{#if @showPMMap}}
      <section class="information private-message-map">
        <PrivateMessageMap
          @topicDetails={{@topicDetails}}
          @showInvite={{@showInvite}}
          @removeAllowedGroup={{@removeAllowedGroup}}
          @removeAllowedUser={{@removeAllowedUser}}
        />
      </section>
    {{/if}}
  </template>
}
