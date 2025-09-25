import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DMenu from "discourse/components/d-menu";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

export default class VoteBox extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked hasVoted = false;
  @tracked hasSeenSuccessMenu = false;
  topic = this.args.topic;

  alreadyVoted = this.topic.user_voted;

  get buttonContent() {
    const content = {};
    if (this.currentUser) {
      if (this.topic.closed) {
        content.label = i18n("topic_voting.voting_closed_title");
        content.title = i18n("topic_voting.voting_closed_title");
      } else if (this.topic.user_voted) {
        content.label = i18n("topic_voting.voted_title");
        content.title = i18n("topic_voting.voted_title");
      } else if (this.currentUser.vote_limit_0) {
        content.label = i18n("topic_voting.not_allowed_to_vote");
        content.title = i18n("topic_voting.not_allowed_to_vote_title");
      } else if (this.currentUser.votes_exceeded) {
        content.label = i18n("topic_voting.voting_limit");
        content.title = i18n("topic_voting.reached_limit");
      } else {
        content.label = i18n("topic_voting.vote_title");
        content.title = i18n("topic_voting.vote_title");
      }
    } else {
      content.label = i18n("topic_voting.anonymous_button", { count: 1 });
      content.title = i18n("topic_voting.anonymous_button", { count: 1 });
    }

    return content;
  }

  get userHasExceededVotingLimit() {
    return this.currentUser.votes_exceeded && !this.topic.user_voted;
  }

  get showVotedMenu() {
    return this.hasVoted && !this.hasSeenSuccessMenu;
  }

  @action
  onShowMenu() {
    applyBehaviorTransformer("topic-vote-button-click", () => {
      if (!this.currentUser) {
        return this.args.showLogin();
      }

      // If user has already voted and seen the success menu, don't do anything
      // The menu will show with the "remove vote" option
      if (this.topic.user_voted && this.hasSeenSuccessMenu) {
        return;
      }

      // If user hasn't voted yet, add vote and show success menu
      if (!this.topic.closed && !this.topic.user_voted) {
        this.args.addVote();
        this.hasVoted = true;
        // Don't set hasSeenSuccessMenu yet - it will be set when menu closes
      }
    });
  }

  @action
  addVote() {
    this.args.addVote();
    this.hasVoted = true;
  }

  @action
  removeVote() {
    this.args.removeVote();
    this.hasVoted = false;
    this.hasSeenSuccessMenu = false;
    this.dMenu.close();
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  onCloseMenu() {
    // Mark that user has seen the success menu
    if (this.hasVoted && !this.hasSeenSuccessMenu) {
      this.hasSeenSuccessMenu = true;
    }
  }

  <template>
    <DMenu
      @identifier="topic-voting-menu"
      @title={{this.buttonContent.title}}
      @label={{this.buttonContent.label}}
      @onShow={{this.onShowMenu}}
      @onClose={{this.onCloseMenu}}
      class="btn-primary vote-button topic-voting-menu__trigger"
      @disabled={{this.userHasExceededVotingLimit}}
      @onRegisterApi={{this.onRegisterApi}}
    >
      <:content>
        <DropdownMenu as |dropdown|>
          {{#if this.showVotedMenu}}
            <dropdown.item class="topic-voting-menu__title">
              {{icon "circle-check"}}
              <span>{{i18n "topic_voting.voted_title"}}</span>
            </dropdown.item>
            <dropdown.item class="topic-voting-menu__row-title">
              {{htmlSafe
                (i18n
                  "topic_voting.votes_left"
                  count=this.currentUser.votes_left
                  path="/my/activity/votes"
                )
              }}
            </dropdown.item>
          {{else}}
            <dropdown.item>
              <DButton
                @translatedLabel={{i18n "topic_voting.remove_vote"}}
                @action={{this.removeVote}}
                @icon="xmark"
                class="btn-transparent topic-voting-menu__row-btn --danger"
              />
            </dropdown.item>
            <dropdown.item class="topic-voting-menu__row">
              <DButton
                @translatedLabel={{i18n "topic_voting.see_votes"}}
                @href="/my/activity/votes"
                @icon="list"
              />
            </dropdown.item>
          {{/if}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
