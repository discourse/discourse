import Component from "@glimmer/component";
import { action } from "@ember/object";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export const ORDER_BY_ACTIVITY_FILTER = "activity";

export default class PostVotingAnswerHeader extends Component {
  static shouldRender(args) {
    const post = args.post;

    if (!post?.topic?.is_post_voting) {
      return false;
    }

    const repliesToPostNumber =
      args.topicPageQueryParams.replies_to_post_number;
    const positionInStream =
      repliesToPostNumber && parseInt(repliesToPostNumber, 10) !== 1 ? 2 : 1;
    const answersCount = post.topic.posts_count - 1;

    return (
      answersCount > 0 &&
      post.id === post.topic.postStream.stream[positionInStream]
    );
  }

  get post() {
    return this.args.outletArgs.post;
  }

  get answersCount() {
    return this.post.topic.posts_count - 1;
  }

  get sortedByActivity() {
    return (
      this.args.outletArgs.topicPageQueryParams.filter ===
      ORDER_BY_ACTIVITY_FILTER
    );
  }

  @action
  async orderByVotes() {
    await this.post.topic.postStream.orderStreamByVotes();
    this.args.outletArgs.actions.updateTopicPageQueryParams();
  }

  @action
  async orderByActivity() {
    await this.post.topic.postStream.orderStreamByActivity();
    this.args.outletArgs.actions.updateTopicPageQueryParams();
  }

  <template>
    <div class="post-voting-answers-header small-action">
      <span class="post-voting-answers-headers-count">
        {{i18n "post_voting.topic.answer_count" count=this.answersCount}}
      </span>
      <span class="post-voting-answers-headers-sort">
        <span>
          {{i18n "post_voting.topic.activity"}}
        </span>
        <DButton
          class={{concatClass
            "post-voting-answers-headers-sort-votes"
            (unless this.sortedByActivity "active")
          }}
          @disabled={{not this.sortedByActivity}}
          @label="post_voting.topic.votes"
          @action={{this.orderByVotes}}
        />
        <DButton
          class={{concatClass
            "post-voting-answers-headers-sort-activity"
            (if this.sortedByActivity "active")
          }}
          @disabled={{this.sortedByActivity}}
          @label="post_voting.topic.activity"
          @action={{this.orderByActivity}}
        />
      </span>
    </div>
  </template>
}
