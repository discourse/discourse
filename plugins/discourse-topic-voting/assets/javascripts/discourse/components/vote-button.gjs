import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { deferAnonymousAction } from "discourse/lib/anonymous-action";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class VoteButton extends Component {
  @service currentUser;

  @tracked hasVoted = false;
  @tracked hasSeenSuccessMenu = false;

  get topic() {
    return this.args.topic;
  }

  get buttonIcon() {
    return this.topic.user_voted ? "vote-up-filled" : "vote-up";
  }

  get isWatching() {
    return (
      this.topic.details?.notification_level === NotificationLevels.WATCHING
    );
  }

  get limitsEnabled() {
    return this.currentUser?.vote_limit != null;
  }

  get showVotedMenu() {
    return this.hasVoted && !this.hasSeenSuccessMenu;
  }

  get showVotedActions() {
    return this.showVotedMenu || this.topic.user_voted;
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

    applyBehaviorTransformer("topic-vote-button-click", async () => {
      if (!this.currentUser) {
        if (this.topic.archived || this.topic.closed) {
          return;
        }
        return deferAnonymousAction(this, "vote_topic", {
          topic_id: this.topic.id,
        });
      }

      if (this.currentUser.vote_limit === 0) {
        return;
      }

      if (
        !this.topic.closed &&
        !this.topic.user_voted &&
        !this.currentUser.votes_exceeded
      ) {
        this.args.addVote();
        this.hasVoted = true;
      }
    });
  }

  @action
  removeVote() {
    this.args.removeVote();
    this.hasVoted = false;
    this.hasSeenSuccessMenu = false;
    this.dMenu.close();
  }

  @action
  async toggleWatching() {
    const newLevel = this.isWatching
      ? NotificationLevels.REGULAR
      : NotificationLevels.WATCHING;
    await this.topic.details.updateNotifications(newLevel);
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
            @translatedAriaLabel={{this.ariaLabel}}
            class={{this.buttonClasses}}
          />
        </:trigger>
        <:content>
          {{i18n "topic_voting.voting_closed_description"}}
        </:content>
      </DTooltip>
    {{else if this.currentUser}}
      <DMenu
        @identifier="topic-voting-menu"
        @icon={{this.buttonIcon}}
        @onShow={{this.onShowMenu}}
        @onClose={{this.onCloseMenu}}
        @title={{this.ariaLabel}}
        @ariaLabel={{this.ariaLabel}}
        class={{this.buttonClasses}}
        @onRegisterApi={{this.onRegisterApi}}
        @placement="right"
      >
        <:content>
          <DDropdownMenu as |dropdown|>
            {{#if (eq this.currentUser.vote_limit 0)}}
              <dropdown.item class="topic-voting-menu__title --locked">
                {{dIcon "lock"}}
                <span>{{i18n "topic_voting.locked_description"}}</span>
              </dropdown.item>
            {{else}}
              {{#if this.limitsEnabled}}
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
              {{/if}}
              {{#if this.showVotedActions}}
                <dropdown.item class="topic-voting-menu__row">
                  <DButton
                    @translatedLabel={{i18n "topic_voting.remove_vote"}}
                    @action={{this.removeVote}}
                    @icon="arrow-rotate-left"
                    class="btn-transparent remove-vote topic-voting-menu__row-btn"
                  />
                </dropdown.item>
                <dropdown.item class="topic-voting-menu__watch-toggle">
                  <DButton
                    @translatedLabel={{i18n "topic_voting.watch_topic"}}
                    @action={{this.toggleWatching}}
                    @icon={{if this.isWatching "toggle-on" "toggle-off"}}
                    class="btn-transparent topic-voting-menu__row-btn"
                  />
                </dropdown.item>
              {{/if}}
            {{/if}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    {{else}}
      <DButton
        @icon={{this.buttonIcon}}
        @action={{this.onShowMenu}}
        @translatedTitle={{this.ariaLabel}}
        @translatedAriaLabel={{this.ariaLabel}}
        class={{this.buttonClasses}}
      />
    {{/if}}
  </template>
}
