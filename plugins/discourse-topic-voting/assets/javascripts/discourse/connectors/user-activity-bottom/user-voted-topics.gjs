import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class UserVotedTopics extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.topic_voting_show_votes_on_profile}}
      <li class="user-nav__activity-votes">

        <LinkTo @route="userActivity.votes">
          {{icon "heart"}}
          {{i18n "topic_voting.vote_title_plural"}}
        </LinkTo>
      </li>
    {{/if}}
  </template>
}
