import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";

export default class PostMenuLikeCountButton extends Component {
  get icon() {
    if (!this.args.transformedPost.showLike) {
      return this.args.transformedPost.yours ? "d-liked" : "d-unliked";
    }

    if (this.args.transformedPost.yours) {
      return "d-liked";
    }
  }

  get translatedTitle() {
    let label;

    if (this.args.transformedPost.liked) {
      label =
        this.args.transformedPost.likeCount === 1
          ? "post.has_likes_title_only_you"
          : "post.has_likes_title_you";
    } else {
      label = "post.has_likes_title";
    }

    return i18n(label, {
      count: this.args.transformedPost.liked
        ? this.args.transformedPost.likeCount - 1
        : this.args.transformedPost.likeCount,
    });
  }

  <template>
    {{#if @transformedPost.likeCount}}
      <DButton
        class={{concatClass
          "button-count"
          "like-count"
          "highlight-action"
          (if @transformedPost.yours "my-likes" "regular-likes")
        }}
        aria-pressed={{if @likedUsers "true" "false"}}
        @icon={{this.icon}}
        @translatedAriaLabel={{i18n
          "post.sr_post_like_count_button"
          count=@transformedPost.likeCount
        }}
        @translatedTitle={{this.translatedTitle}}
        @action={{@action}}
      >
        {{@transformedPost.likeCount}}
      </DButton>
    {{/if}}
  </template>
}
