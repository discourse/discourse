import Component from "@glimmer/component";
import { service } from "@ember/service";
import VoteBox from "../../components/vote-box";

export default class TopicListVoting extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.topic_voting_show_vote_in_topic_list}}
      {{#if @outletArgs.topic.can_vote}}
        <div class="voting list-voting">
          <VoteBox @topic={{@outletArgs.topic}} />
        </div>
      {{/if}}
    {{/if}}
  </template>
}
