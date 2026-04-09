import Component from "@glimmer/component";
import { service } from "@ember/service";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import { i18n } from "discourse-i18n";
import VoteBox from "../../components/vote-box";

export default class MobileTopicVoting extends Component {
  @service siteSettings;

  get showVoting() {
    return (
      this.siteSettings.topic_voting_show_vote_in_topic_list &&
      this.args.outletArgs.topic.can_vote
    );
  }

  <template>
    {{#if this.showVoting}}
      <div class="voting mobile-voting">
        <VoteBox @topic={{@outletArgs.topic}} />
      </div>
    {{else}}
      <UserLink
        @ariaLabel={{i18n
          "latest_poster_link"
          username=@outletArgs.topic.lastPosterUser.username
        }}
        @username={{@outletArgs.topic.lastPosterUser.username}}
      >
        {{avatar @outletArgs.topic.lastPosterUser imageSize="large"}}
      </UserLink>
    {{/if}}
  </template>
}
