import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class SolvedAcceptAnswerButton extends Component {
  static hidden(args) {
    return args.post.topic_accepted_answer;
  }

  @service appEvents;
  @service currentUser;

  @tracked saving = false;

  get showLabel() {
    return this.currentUser?.id === this.args.post.topicCreatedById;
  }

  @action
  async acceptAnswer() {
    const post = this.args.post;

    this.saving = true;
    try {
      await acceptPost(post, this.currentUser);
      this.appEvents.trigger("discourse-solved:solution-toggled", post);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DButton
      class="post-action-menu__solved-unaccepted unaccepted"
      ...attributes
      @action={{this.acceptAnswer}}
      @disabled={{this.saving}}
      @icon="far-square-check"
      @label={{if this.showLabel "solved.solution"}}
      @title="solved.accept_answer"
    />
  </template>
}

async function acceptPost(post) {
  if (!post.can_accept_answer || post.accepted_answer) {
    return;
  }

  const topic = post.topic;

  try {
    const acceptedAnswer = await ajax("/solution/accept", {
      type: "POST",
      data: { id: post.id },
    });

    topic.setAcceptedSolution(acceptedAnswer);
  } catch (e) {
    popupAjaxError(e);
  }
}
