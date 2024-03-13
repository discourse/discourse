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
  @tracked collapsed = !this.args.postAttrs.hasTopRepliesSummary;

  @action
  toggleMap() {
    this.collapsed = !this.collapsed;
  }

  <template>
    <section class={{concatClass "map" (if this.collapsed "map-collapsed")}}>
      <TopicMapSummary
        @postAttrs={{@postAttrs}}
        @toggleMap={{this.toggleMap}}
        @collapsed={{this.collapsed}}
      />
    </section>
    {{#unless this.collapsed}}
      <section class="topic-map-expanded">
        <TopicMapExpanded @postAttrs={{@postAttrs}} />
      </section>
    {{/unless}}
    {{#if (or @postAttrs.hasTopRepliesSummary @postAttrs.summarizable)}}
      <section class="information toggle-summary">
        <SummaryBox
          @postAttrs={{@postAttrs}}
          @cancelFilter={{@cancelFilter}}
          @showTopReplies={{@showTopReplies}}
          @collapseSummary={{@collapseSummary}}
          @showSummary={{@showSummary}}
        />
      </section>
    {{/if}}
    {{#if @postAttrs.showPMMap}}
      <section class="information private-message-map">
        <PrivateMessageMap
          @postAttrs={{@postAttrs}}
          @showInvite={{@showInvite}}
          @removeAllowedGroup={{@removeAllowedGroup}}
          @removeAllowedUser={{@removeAllowedUser}}
        />
      </section>
    {{/if}}
  </template>
}
