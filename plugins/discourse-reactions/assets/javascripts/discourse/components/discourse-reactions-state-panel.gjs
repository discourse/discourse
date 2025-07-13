import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { and, eq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import DiscourseReactionsStatePanelReaction from "./discourse-reactions-state-panel-reaction";

export default class DiscourseReactionsStatePanel extends Component {
  @tracked displayedReactionId;

  get classes() {
    const classes = [];

    const { post } = this.args;
    if (post?.reactions) {
      const maxCount = Math.max(...post.reactions.mapBy("count"));
      const charsCount = maxCount.toString().length;
      classes.push(`max-length-${charsCount}`);
    }

    if (this.args.statePanelExpanded) {
      classes.push("is-expanded");
    }

    return classes;
  }

  @action
  pointerOut(event) {
    if (event.pointerType !== "mouse") {
      return;
    }

    this.args.scheduleCollapse("collapseStatePanel");
  }

  @action
  pointerOver(event) {
    if (event.pointerType !== "mouse") {
      return;
    }

    this.args.cancelCollapse();
  }

  @action
  showUsers(reactionId) {
    if (!this.displayedReactionId) {
      this.displayedReactionId = reactionId;
    } else if (this.displayedReactionId === reactionId) {
      this.hideUsers();
    } else if (this.displayedReactionId !== reactionId) {
      this.displayedReactionId = reactionId;
    }
  }

  @action
  hideUsers() {
    this.displayedReactionId = null;
  }

  get hasReactionData() {
    return !!Object.keys(this.args.reactionsUsers).length;
  }

  <template>
    <div
      class={{concatClass "discourse-reactions-state-panel" this.classes}}
      {{on "pointerout" this.pointerOut}}
      {{on "pointerover" this.pointerOver}}
    >
      {{#if (and @statePanelExpanded @post.reactions.length)}}
        <div class="container">
          {{#if this.hasReactionData}}
            <div class="counters">
              {{#each @post.reactions key="id" as |reaction|}}
                <DiscourseReactionsStatePanelReaction
                  @reaction={{reaction}}
                  @users={{get @reactionsUsers reaction.id}}
                  @post={{@post}}
                  @isDisplayed={{eq reaction.id this.displayedReactionId}}
                  @showUsers={{this.showUsers}}
                />
              {{/each}}
            </div>
          {{else}}
            <div class="spinner-container">
              <div class="spinner small"></div>
            </div>
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
