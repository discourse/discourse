import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PostMetaDataPosterName from "discourse/components/post/meta-data/poster-name";
import UserAvatar from "discourse/components/user-avatar";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class PostFilteredNotice extends Component {
  get isViewingPostsByUsername() {
    return this.args.streamFilters.username_filters?.length;
  }

  get isViewingRepliesToPostNumber() {
    return !!this.args.streamFilters.replies_to_post_number;
  }

  get isViewingSubset() {
    return (
      this.args.streamFilters.filter_upwards_post_id ||
      this.args.streamFilters.mixedHiddenPosts
    );
  }

  get isViewingSummary() {
    return this.args.streamFilters.filter === "summary";
  }

  get firstUserPost() {
    return this.args.posts[1];
  }

  get sourcePost() {
    return this.args.posts.find(
      (post) =>
        post.post_number === this.args.streamFilters.replies_to_post_number
    );
  }

  get userPostsCount() {
    return parseInt(this.args.filteredPostsCount, 10) - 1;
  }

  @action
  jumpToPost() {
    DiscourseURL.jumpToPost(this.args.streamFilters.replies_to_post_number);
  }

  <template>
    <div class="posts-filtered-notice">
      {{#if this.isViewingSubset}}
        <span class="filtered-replies-viewing">
          {{i18n "post.filtered_replies.viewing_subset"}}
          <FilterShowAllBtn
            @streamFilters={{@streamFilters}}
            @cancelFilter={{@cancelFilter}}
          />
        </span>
      {{else if this.isViewingRepliesToPostNumber}}
        <span class="filtered-replies-viewing">
          {{i18n
            "post.filtered_replies_viewing"
            count=this.sourcePost.reply_count
          }}
        </span>
        <span class="filtered-user-row">
          <span class="filtered-avatar">
            <UserAvatar @size="small" @user={{this.sourcePost}} />
          </span>
          <DButton
            class="filtered-jump-to-post"
            @translatedLabel={{i18n
              "post.filtered_replies.post_number"
              username=this.sourcePost.username
              post_number=@streamFilters.replies_to_post_number
            }}
            @action={{this.jumpToPost}}
          />
          <FilterShowAllBtn
            @streamFilters={{@streamFilters}}
            @cancelFilter={{@cancelFilter}}
          />
        </span>
      {{else if this.isViewingSummary}}
        <span class="filtered-replies-viewing">
          {{i18n "post.filtered_replies.viewing_summary"}}
        </span>
        <FilterShowAllBtn
          @streamFilters={{@streamFilters}}
          @cancelFilter={{@cancelFilter}}
        />
      {{else if this.isViewingPostsByUsername}}
        <span class="filtered-replies-viewing">
          {{i18n
            "post.filtered_replies.viewing_posts_by"
            post_count=this.userPostsCount
          }}
        </span>
        <span class="filtered-avatar">
          <UserAvatar @size="small" @user={{this.firstUserPost}} />
        </span>
        <PostMetaDataPosterName @post={{this.firstUserPost}} />
        <FilterShowAllBtn
          @streamFilters={{@streamFilters}}
          @cancelFilter={{@cancelFilter}}
        />
      {{/if}}
    </div>
  </template>
}

class FilterShowAllBtn extends Component {
  @service appEvents;

  @action
  showAll() {
    this.args.cancelFilter();
    this.appEvents.trigger(
      "post-stream:filter-show-all",
      this.args.streamFilters
    );
  }

  <template>
    <DButton
      class="btn-primary filtered-replies-show-all"
      @icon="up-down"
      @label="post.filtered_replies.show_all"
      @action={{this.showAll}}
    />
  </template>
}
