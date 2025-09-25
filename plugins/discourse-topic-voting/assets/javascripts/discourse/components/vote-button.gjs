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

  get wrapperClasses() {
    const classes = [];
    if (this.topic.closed) {
      classes.push("voting-closed");
    } else {
      if (!this.topic.user_voted) {
        classes.push("nonvote");
      } else {
        if (this.currentUser && this.currentUser.votes_exceeded) {
          classes.push("vote-limited nonvote");
        } else {
          classes.push("vote");
        }
      }
    }
    if (this.siteSettings.topic_voting_show_who_voted) {
      classes.push("show-pointer");
    }
    return classes.join(" ");
  }

  get buttonContent() {
    if (this.currentUser) {
      if (this.topic.closed) {
        return i18n("topic_voting.voting_closed_title");
      }

      if (this.topic.user_voted) {
        return i18n("topic_voting.voted_title");
      }

      if (this.currentUser.votes_exceeded) {
        return i18n("topic_voting.voting_limit");
      }

      return i18n("topic_voting.vote_title");
    }

    if (this.topic.vote_count) {
      return i18n("topic_voting.anonymous_button", {
        count: this.topic.vote_count,
      });
    }

    return i18n("topic_voting.anonymous_button", { count: 1 });
  }

  get userHasVoted() {
    return this.topic.user_voted;
  }

  get userHasNotVoted() {
    return !this.topic.user_voted;
  }

  get userHasExceededVotingLimit() {
    return this.currentUser.votes_exceeded;
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
      if (
        !this.topic.closed &&
        !this.topic.user_voted &&
        !this.currentUser.votes_exceeded
      ) {
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

  @action
  click() {
    applyBehaviorTransformer("topic-vote-button-click", () => {
      if (!this.currentUser) {
        return this.args.showLogin();
      }

      if (
        !this.topic.closed &&
        !this.topic.user_voted &&
        !this.currentUser.votes_exceeded
      ) {
        this.args.addVote();
      }

      if (this.topic.user_voted || this.currentUser.votes_exceeded) {
        this.args.showVoteOptions();
      }
    });
  }

  <template>
    <div class={{this.wrapperClasses}}>
      <DMenu
        @identifier="topic-voting-menu"
        @title={{this.buttonContent}}
        @label={{this.buttonContent}}
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
              {{#if this.userHasNotVoted}}
                <dropdown.item>
                  <DButton
                    @translatedLabel={{this.buttonContent}}
                    @action={{this.addVote}}
                    class="btn-transparent"
                  />
                </dropdown.item>
              {{/if}}
              {{#if this.userHasVoted}}
                <dropdown.item>
                  <DButton
                    @translatedLabel={{i18n "topic_voting.remove_vote"}}
                    @action={{this.removeVote}}
                    @icon="xmark"
                    class="btn-transparent topic-voting-menu__row-btn --danger"
                  />
                </dropdown.item>
              {{/if}}
            {{/if}}
          </DropdownMenu>
        </:content>
      </DMenu>
    </div>
  </template>
}
