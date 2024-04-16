import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import SummaryBox from "discourse/components/summary-box";
import PrivateMessageMap from "discourse/components/topic-map/private-message-map";
import TopicMapExpanded from "discourse/components/topic-map/topic-map-expanded";
import TopicMapSummary from "discourse/components/topic-map/topic-map-summary";
import concatClass from "discourse/helpers/concat-class";
import or from "truth-helpers/helpers/or";

export default class TopicMap extends Component {
  @tracked collapsed = !this.args.model.has_summary;
  topicDetails = this.args.model.get("details");
  postStream = this.args.model.postStream;
  userFilters = this.postStream.userFilters || [];

  @action
  toggleMap() {
    this.collapsed = !this.collapsed;
  }

  <template>
    <section class={{concatClass "map" (if this.collapsed "map-collapsed")}}>
      <TopicMapSummary
        @topic={{@model}}
        @topicDetails={{this.topicDetails}}
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
          @topicDetails={{this.topicDetails}}
          @userFilters={{this.userFilters}}
        />
      </section>
    {{/unless}}
    {{#if (or @model.has_summary @model.summarizable)}}
      <section class="information toggle-summary">
        <SummaryBox
          @topic={{@model}}
          @postStream={{this.postStream}}
          @cancelFilter={{@cancelFilter}}
          @showTopReplies={{@showTopReplies}}
          @collapseSummary={{@collapseSummary}}
          @showSummary={{@showSummary}}
        />
      </section>
    {{/if}}
    {{#if @showPMMap}}
      <section class="information private-message-map">
        <PrivateMessageMap
          @topicDetails={{this.topicDetails}}
          @showInvite={{@showInvite}}
          @removeAllowedGroup={{@removeAllowedGroup}}
          @removeAllowedUser={{@removeAllowedUser}}
        />
      </section>
    {{/if}}
  </template>
}
