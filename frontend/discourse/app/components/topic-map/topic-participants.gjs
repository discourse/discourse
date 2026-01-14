import Component from "@glimmer/component";
import TopicParticipant from "discourse/components/topic-map/topic-participant";

export default class TopicParticipants extends Component {
  toggledUsers = new Set(this.args.userFilters);

  <template>
    {{#if @title}}
      <h3>{{@title}}</h3>
    {{/if}}
    <div class="topic-map__users-list {{unless @title '--users-summary'}}">
      {{#each @participants as |participant|}}
        <TopicParticipant
          @participant={{participant}}
          @toggledUsers={{this.toggledUsers}}
        />
      {{/each}}
    </div>
  </template>
}
