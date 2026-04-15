import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import icon from "discourse/helpers/d-icon";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import { and, eq, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class VoteBox extends Component {
  @service currentUser;
  @service router;

  @tracked hasVoted = false;
  @tracked hasSeenSuccessMenu = false;

  get topic() {
    return this.args.topic;
  }

  get buttonIcon() {
    return this.topic.user_voted ? "vote-up-filled" : "vote-up";
  }

  get limitsEnabled() {
    return this.currentUser?.vote_limit != null;
  }

  get showVotedMenu() {
    return this.hasVoted && !this.hasSeenSuccessMenu;
  }

  get buttonClasses() {
    if (this.currentUser?.vote_limit === 0) {
      return "btn-default btn-small voting-wrapper__button";
    }

    return this.topic.user_voted
      ? "btn-success btn-small voting-wrapper__button"
      : "btn-default btn-small voting-wrapper__button";
  }

  get ariaLabel() {
    if (this.topic.closed) {
      return i18n("topic_voting.voting_closed_description");
    }
    if (this.currentUser?.vote_limit === 0) {
      return i18n("topic_voting.locked_description");
    }
    return this.topic.user_voted
      ? i18n("topic_voting.remove_vote")
      : i18n("topic_voting.vote_title");
  }

  @action
  onShowMenu() {
    if (!this.topic.user_voted) {
      this.hasVoted = false;
      this.hasSeenSuccessMenu = false;
    }

    applyBehaviorTransformer("topic-vote-button-click", () => {
      if (!this.currentUser) {
        return this.router.transitionTo("login");
      }

      if (this.currentUser.vote_limit === 0) {
        return;
      }

      // When limits are disabled and user has voted, toggle off
      if (!this.limitsEnabled && this.topic.user_voted) {
        this.args.removeVote();
        this.hasVoted = false;
        this.hasSeenSuccessMenu = false;
        return;
      }

      // If user has already voted and seen the success menu, don't do anything
      // The menu will show with the "remove vote" option
      if (this.topic.user_voted && this.hasSeenSuccessMenu) {
        return;
      }

      if (
        !this.topic.closed &&
        !this.topic.user_voted &&
        !this.currentUser.votes_exceeded
      ) {
        this.args.addVote();

        // When limits are disabled, no menu needed
        if (!this.limitsEnabled) {
          return;
        }

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
    if (this.hasVoted && !this.hasSeenSuccessMenu) {
      this.hasSeenSuccessMenu = true;
    }
  }

  <template>
    {{#if this.topic.closed}}
      <DTooltip @identifier="vote-closed-tooltip" @placement="right">
        <:trigger>
          <DButton
            @icon={{this.buttonIcon}}
            @disabled={{true}}
            @ariaLabel={{this.ariaLabel}}
            class={{this.buttonClasses}}
          />
        </:trigger>
        <:content>
          {{i18n "topic_voting.voting_closed_description"}}
        </:content>
      </DTooltip>
    {{else if this.limitsEnabled}}
      <DMenu
        @identifier="topic-voting-menu"
        @icon={{this.buttonIcon}}
        @onShow={{this.onShowMenu}}
        @onClose={{this.onCloseMenu}}
        @ariaLabel={{this.ariaLabel}}
        class={{this.buttonClasses}}
        @onRegisterApi={{this.onRegisterApi}}
        @placement="right"
      >
        <:content>
          <DropdownMenu as |dropdown|>
            {{#if this.showVotedMenu}}
              <dropdown.item class="topic-voting-menu__votes-left">
                <DButton
                  @translatedLabel={{i18n
                    "topic_voting.see_votes"
                    count=this.currentUser.votes_left
                    max=this.currentUser.vote_limit
                  }}
                  @href="/my/activity/votes"
                  @icon="check-to-slot"
                  class="btn-transparent see-votes topic-voting-menu__row-btn"
                />
              </dropdown.item>
              <dropdown.item class="topic-voting-menu__row">
                <DButton
                  @translatedLabel={{i18n "topic_voting.remove_vote"}}
                  @action={{this.removeVote}}
                  @icon="arrow-rotate-left"
                  class="btn-transparent remove-vote topic-voting-menu__row-btn"
                />
              </dropdown.item>
            {{else if (eq this.currentUser.vote_limit 0)}}
              <dropdown.item class="topic-voting-menu__title --locked">
                {{icon "lock"}}
                <span>{{i18n "topic_voting.locked_description"}}</span>
              </dropdown.item>
            {{else if
              (and this.currentUser.votes_exceeded (not this.topic.user_voted))
            }}
              <dropdown.item class="topic-voting-menu__row">
                <DButton
                  @translatedLabel={{i18n
                    "topic_voting.see_votes"
                    count=this.currentUser.votes_left
                    max=this.currentUser.vote_limit
                  }}
                  @href="/my/activity/votes"
                  @icon="check-to-slot"
                  class="btn-transparent see-votes topic-voting-menu__row-btn"
                />
              </dropdown.item>
            {{else}}
              <dropdown.item class="topic-voting-menu__row">
                <DButton
                  @translatedLabel={{i18n
                    "topic_voting.see_votes"
                    count=this.currentUser.votes_left
                    max=this.currentUser.vote_limit
                  }}
                  @href="/my/activity/votes"
                  @icon="check-to-slot"
                  class="btn-transparent see-votes topic-voting-menu__row-btn"
                />
              </dropdown.item>
              {{#if this.topic.user_voted}}
                <dropdown.item class="topic-voting-menu__row">
                  <DButton
                    @translatedLabel={{i18n "topic_voting.remove_vote"}}
                    @action={{this.removeVote}}
                    @icon="arrow-rotate-left"
                    class="btn-transparent remove-vote topic-voting-menu__row-btn"
                  />
                </dropdown.item>
              {{/if}}
            {{/if}}
          </DropdownMenu>
        </:content>
      </DMenu>
    {{else}}
      <DButton
        @icon={{this.buttonIcon}}
        @action={{this.onShowMenu}}
        @ariaLabel={{this.ariaLabel}}
        class={{this.buttonClasses}}
      />
    {{/if}}
  </template>
}
