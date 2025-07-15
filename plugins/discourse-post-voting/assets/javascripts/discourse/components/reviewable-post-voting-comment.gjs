import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewablePostHeader from "discourse/components/reviewable-post-header";
import categoryBadge from "discourse/helpers/category-badge";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default class ReviewablePostVotingComment extends Component {
  @service store;

  @tracked post;

  constructor() {
    super(...arguments);
    this.fetchPost();
  }

  async fetchPost() {
    const post = await this.store.find("post", this.args.reviewable.post_id);
    this.post = post;
  }

  <template>
    <div class="post-topic">
      <a class="title-text" href={{this.post.url}}>
        {{htmlSafe @reviewable.topic.fancyTitle}}</a>
      {{categoryBadge @reviewable.category}}
    </div>

    <div class="post-contents-wrapper">
      <ReviewableCreatedBy
        @user={{@reviewable.target_created_by}}
        @tagName=""
      />
      <div class="post-contents">
        <ReviewablePostHeader
          @reviewable={{@reviewable}}
          @createdBy={{@reviewable.target_created_by}}
          @tagName=""
        />

        <div class="post-body">
          {{htmlSafe
            (or @reviewable.payload.comment_cooked @reviewable.cooked)
          }}
        </div>

        {{#if @reviewable.payload.transcript_topic_id}}
          <div class="transcript">
            <LinkTo
              @route="topic"
              @models={{array "-" @reviewable.payload.transcript_topic_id}}
              class="btn btn-small"
            >
              {{i18n "review.transcript.view"}}
            </LinkTo>
          </div>
        {{/if}}

        {{yield}}
      </div>
    </div>
  </template>
}
