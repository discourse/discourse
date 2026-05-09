import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class PostVotingButton extends Component {
  get buttonClasses() {
    let classes = this.args.direction === "up" ? "--upvote" : "--downvote";

    if (this.args.voted) {
      classes += " --voted";
    }

    return classes;
  }

  get disabled() {
    return this.args.disabled || this.args.loading;
  }

  get iconName() {
    return this.args.voted ? "vote-up-filled" : "vote-up";
  }

  get ariaLabel() {
    if (this.args.direction === "up") {
      return this.args.voted
        ? "vote.button.remove_upvote"
        : "vote.button.upvote";
    }

    return this.args.voted
      ? "vote.button.remove_downvote"
      : "vote.button.downvote";
  }

  @action
  onClick() {
    if (this.args.loading) {
      return false;
    }

    if (this.args.voted) {
      this.args.removeVote(this.args.direction);
    } else {
      this.args.vote(this.args.direction);
    }
  }

  <template>
    <DButton
      {{on "click" this.onClick}}
      @disabled={{this.disabled}}
      @icon={{this.iconName}}
      @title={{this.ariaLabel}}
      @ariaLabel={{this.ariaLabel}}
      class={{concatClass
        "btn-transparent post-voting-button"
        this.buttonClasses
      }}
    />
  </template>
}
