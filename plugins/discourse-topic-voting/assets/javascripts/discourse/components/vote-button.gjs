import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

export default class VoteBox extends Component {
  @service siteSettings;
  @service currentUser;

  get wrapperClasses() {
    const classes = [];
    const { topic } = this.args;
    if (topic.closed) {
      classes.push("voting-closed");
    } else {
      if (!topic.user_voted) {
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
    const { topic } = this.args;
    if (this.currentUser) {
      if (topic.closed) {
        return i18n("topic_voting.voting_closed_title");
      }

      if (topic.user_voted) {
        return i18n("topic_voting.voted_title");
      }

      if (this.currentUser.votes_exceeded) {
        return i18n("topic_voting.voting_limit");
      }

      return i18n("topic_voting.vote_title");
    }

    if (topic.vote_count) {
      return i18n("topic_voting.anonymous_button", {
        count: topic.vote_count,
      });
    }

    return i18n("topic_voting.anonymous_button", { count: 1 });
  }

  @action
  click() {
    applyBehaviorTransformer("topic-vote-button-click", () => {
      if (!this.currentUser) {
        return this.args.showLogin();
      }

      const { topic } = this.args;

      if (
        !topic.closed &&
        !topic.user_voted &&
        !this.currentUser.votes_exceeded
      ) {
        this.args.addVote();
      }

      if (topic.user_voted || this.currentUser.votes_exceeded) {
        this.args.showVoteOptions();
      }
    });
  }

  <template>
    <div class={{this.wrapperClasses}}>
      <DButton
        @translatedTitle={{if
          this.currentUser
          (i18n
            "topic_voting.votes_left_button_title"
            count=this.currentUser.votes_left
          )
          ""
        }}
        @translatedLabel={{this.buttonContent}}
        class="btn-primary vote-button"
        @action={{this.click}}
      />
    </div>
  </template>
}
