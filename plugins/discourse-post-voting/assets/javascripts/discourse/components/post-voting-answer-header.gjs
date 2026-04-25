import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
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

  get votesUrl() {
    return this.post.topic.url;
  }

  get activityUrl() {
    return `${this.post.topic.url}?filter=${ORDER_BY_ACTIVITY_FILTER}`;
  }

  @action
  async orderByVotes(event) {
    event.preventDefault();
    await this.post.topic.postStream.orderStreamByVotes();
    this.args.outletArgs.actions.updateTopicPageQueryParams();
  }

  @action
  async orderByActivity(event) {
    event.preventDefault();
    await this.post.topic.postStream.orderStreamByActivity();
    this.args.outletArgs.actions.updateTopicPageQueryParams();
  }

  <template>
    <nav
      class="post-voting-answers-header"
      aria-label={{i18n "post_voting.topic.sort_by"}}
    >
      <h5 class="post-voting-answers-header__count">
        {{i18n "post_voting.topic.answer_count" count=this.answersCount}}
      </h5>
      <ul class="nav-pills post-voting-answers-header__sort">
        <li>
          <a
            href={{this.votesUrl}}
            class={{concatClass
              "--votes"
              (unless this.sortedByActivity "active")
            }}
            aria-current={{unless this.sortedByActivity "true"}}
            {{on "click" this.orderByVotes}}
          >
            {{i18n "post_voting.topic.votes"}}
          </a>
        </li>
        <li>
          <a
            href={{this.activityUrl}}
            class={{concatClass
              "--activity"
              (if this.sortedByActivity "active")
            }}
            aria-current={{if this.sortedByActivity "true"}}
            {{on "click" this.orderByActivity}}
          >
            {{i18n "post_voting.topic.activity"}}
          </a>
        </li>
      </ul>
    </nav>
  </template>
}
