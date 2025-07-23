import Component from "@glimmer/component";
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

  get showLabel() {
    return this.currentUser?.id === this.args.post.topicCreatedById;
  }

  @action
  acceptAnswer() {
    const post = this.args.post;

    acceptPost(post, this.currentUser);

    this.appEvents.trigger("discourse-solved:solution-toggled", post);

    post.get("topic.postStream.posts").forEach((p) => {
      p.set("topic_accepted_answer", true);
      this.appEvents.trigger("post-stream:refresh", { id: p.id });
    });
  }

  <template>
    <DButton
      class="post-action-menu__solved-unaccepted unaccepted"
      ...attributes
      @action={{this.acceptAnswer}}
      @icon="far-square-check"
      @label={{if this.showLabel "solved.solution"}}
      @title="solved.accept_answer"
    />
  </template>
}

function acceptPost(post, acceptingUser) {
  const topic = post.topic;

  clearAccepted(topic);

  post.setProperties({
    can_unaccept_answer: true,
    can_accept_answer: false,
    accepted_answer: true,
  });

  topic.set("accepted_answer", {
    username: post.username,
    name: post.name,
    post_number: post.post_number,
    excerpt: post.cooked,
    accepter_username: acceptingUser.username,
    accepter_name: acceptingUser.name,
  });

  ajax("/solution/accept", {
    type: "POST",
    data: { id: post.id },
  }).catch(popupAjaxError);
}

function clearAccepted(topic) {
  const posts = topic.get("postStream.posts");
  posts.forEach((post) => {
    if (post.get("post_number") > 1) {
      post.setProperties({
        accepted_answer: false,
        can_accept_answer: true,
        can_unaccept_answer: false,
        topic_accepted_answer: false,
      });
    }
  });
}
