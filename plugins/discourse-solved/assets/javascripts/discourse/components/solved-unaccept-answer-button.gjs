import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class SolvedUnacceptAnswerButton extends Component {
  @service appEvents;
  @service siteSettings;

  @tracked saving = false;

  get solvedBy() {
    if (!this.siteSettings.show_who_marked_solved) {
      return;
    }

    const username = this.args.post.topic.accepted_answer.accepter_username;
    const name = this.args.post.topic.accepted_answer.accepter_name;
    const displayedName =
      this.siteSettings.display_name_on_posts && name
        ? name
        : formatUsername(username);
    if (this.args.post.topic.accepted_answer.accepter_username) {
      return i18n("solved.marked_solved_by", {
        username: displayedName,
        username_lower: username,
      });
    }
  }

  @action
  async unacceptAnswer() {
    const post = this.args.post;

    this.saving = true;
    try {
      await unacceptPost(post);
    } finally {
      this.saving = false;
    }

    this.appEvents.trigger("discourse-solved:solution-toggled", post);

    // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
    post.get("topic.postStream.posts").forEach((p) => {
      this.appEvents.trigger("post-stream:refresh", { id: p.id });
    });
  }

  <template>
    <span class="extra-buttons">
      {{#if (and @post.can_accept_answer @post.accepted_answer)}}
        {{#if this.solvedBy}}
          <DTooltip @identifier="post-action-menu__solved-accepted-tooltip">
            <:trigger>
              <DButton
                class="post-action-menu__solved-accepted accepted fade-out"
                ...attributes
                @action={{this.unacceptAnswer}}
                @icon="square-check"
                @label="solved.solution"
                @title="solved.unaccept_answer"
              />
            </:trigger>
            <:content>
              {{htmlSafe this.solvedBy}}
            </:content>
          </DTooltip>
        {{else}}
          <DButton
            class="post-action-menu__solved-accepted accepted fade-out"
            ...attributes
            @action={{this.unacceptAnswer}}
            @disabled={{this.saving}}
            @icon="square-check"
            @label="solved.solution"
            @title="solved.unaccept_answer"
          />
        {{/if}}
      {{else}}
        <span
          class="accepted-text"
          title={{i18n "solved.accepted_description"}}
        >
          <span>{{icon "check"}}</span>
          <span class="accepted-label">
            {{i18n "solved.solution"}}
          </span>
        </span>
      {{/if}}
    </span>
  </template>
}

async function unacceptPost(post) {
  if (!post.can_accept_answer || !post.accepted_answer) {
    return;
  }

  const topic = post.topic;

  try {
    await ajax("/solution/unaccept", {
      type: "POST",
      data: { id: post.id },
    });

    topic.setAcceptedSolution(undefined);
  } catch (e) {
    popupAjaxError(e);
  }
}
