import Component from "@glimmer/component";
import { service } from "@ember/service";
import VoteBox from "../../components/vote-box";

export default class TopicListVoting extends Component {
  @service capabilities;
  @service siteSettings;

  get showVoting() {
    return (
      this.siteSettings.topic_voting_show_vote_in_topic_list &&
      this.capabilities.viewport.sm &&
      this.args.outletArgs.topic.can_vote
    );
  }

  <template>
    {{#if this.showVoting}}
      <div class="voting list-voting">
        <VoteBox @topic={{@outletArgs.topic}} />
      </div>
    {{/if}}
  </template>
}
