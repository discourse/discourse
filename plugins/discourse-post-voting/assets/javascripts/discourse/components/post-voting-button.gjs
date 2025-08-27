import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class PostVotingButton extends Component {
  get buttonClasses() {
    let classes =
      this.args.direction === "up"
        ? "post-voting-button-upvote"
        : "post-voting-button-downvote";

    if (this.args.voted) {
      classes += " post-voting-button-voted";
    }

    return classes;
  }

  get disabled() {
    return this.args.disabled || this.args.loading;
  }

  get iconName() {
    return this.args.direction === "up" ? "caret-up" : "caret-down";
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
      class={{concatClass "btn-flat post-voting-button" this.buttonClasses}}
    />
  </template>
}
