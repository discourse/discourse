import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class VoteBox extends Component {
  @service currentUser;

  <template>
    <div class="vote-options voting-popup-menu popup-menu" ...attributes>
      {{#if @topic.user_voted}}
        <div
          role="button"
          class="remove-vote vote-option"
          {{on "click" @removeVote}}
        >
          {{icon "xmark"}}
          {{i18n "topic_voting.remove_vote"}}
        </div>
      {{else if this.currentUser.votes_exceeded}}
        <div>{{i18n "topic_voting.reached_limit"}}</div>
        <p>
          <a href="/my/activity/votes">{{i18n "topic_voting.list_votes"}}</a>
        </p>
      {{/if}}
    </div>
  </template>
}
