import Component from "@glimmer/component";
import TopicParticipant from "discourse/components/topic-map/topic-participant";

export default class TopicParticipants extends Component {
  // prettier-ignore
  toggledUsers = new Set(this.args.userFilters);

  <template>
    {{@title}}
    {{#each @participants as |participant|}}
      <TopicParticipant
        @participant={{participant}}
        @toggledUsers={{this.toggledUsers}}
      />
    {{/each}}
  </template>
}
