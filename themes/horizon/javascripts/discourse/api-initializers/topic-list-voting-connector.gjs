import Component from "@glimmer/component";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import VoteBox from "discourse/plugins/discourse-topic-voting/discourse/components/vote-box";

class MobileTopicListVoting extends Component {
  @service siteSettings;

  get showVoting() {
    return (
      this.siteSettings.topic_voting_show_vote_in_topic_list &&
      this.args.outletArgs.topic.can_vote
    );
  }

  <template>
    {{#if this.showVoting}}
      <div class="voting mobile-list-voting">
        <VoteBox @topic={{@outletArgs.topic}} />
      </div>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  api.renderInOutlet("topic-list-before-link", MobileTopicListVoting);
});
