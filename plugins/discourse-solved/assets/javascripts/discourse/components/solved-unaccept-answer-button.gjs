import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import InterpolatedTranslation from "discourse/components/interpolated-translation";
import UserLink from "discourse/components/user-link";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class SolvedUnacceptAnswerButton extends Component {
  @service appEvents;
  @service siteSettings;

  @tracked saving = false;

  @action
  async unacceptAnswer() {
    const post = this.args.post;

    this.saving = true;
    try {
      await unacceptPost(post);

      this.appEvents.trigger("discourse-solved:solution-toggled", post);

      // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
      post.get("topic.postStream.posts").forEach((p) => {
        this.appEvents.trigger("post-stream:refresh", { id: p.id });
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  get showAcceptedBy() {
    return !(
      !this.siteSettings.show_who_marked_solved ||
      !this.args.post.topic.accepted_answer.accepter_username
    );
  }

  get acceptedByUsername() {
    return this.args.post.topic.accepted_answer.accepter_username;
  }

  get acceptedByDisplayName() {
    const username = this.args.post.topic.accepted_answer.accepter_username;
    const name = this.args.post.topic.accepted_answer.accepter_name;
    return this.siteSettings.display_name_on_posts && name ? name : username;
  }

  <template>
    <span class="extra-buttons">
      {{#if (and @post.can_accept_answer @post.accepted_answer)}}
        {{#if this.showAcceptedBy}}
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
              <InterpolatedTranslation
                @key="solved.marked_solved_by"
                as |Placeholder|
              >
                <Placeholder @name="user">
                  <UserLink @username={{this.acceptedByUsername}}>
                    {{this.acceptedByDisplayName}}
                  </UserLink>
                </Placeholder>
              </InterpolatedTranslation>
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
