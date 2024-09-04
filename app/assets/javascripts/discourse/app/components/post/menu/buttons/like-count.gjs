import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";

export default class PostMenuLikeCountButton extends Component {
  get icon() {
    if (!this.args.post.showLike) {
      return this.args.post.yours ? "d-liked" : "d-unliked";
    }

    if (this.args.post.yours) {
      return "d-liked";
    }
  }

  get translatedTitle() {
    let label;

    if (this.args.post.liked) {
      label =
        this.args.post.likeCount === 1
          ? "post.has_likes_title_only_you"
          : "post.has_likes_title_you";
    } else {
      label = "post.has_likes_title";
    }

    return i18n(label, {
      count: this.args.post.liked
        ? this.args.post.likeCount - 1
        : this.args.post.likeCount,
    });
  }

  <template>
    {{#if @post.likeCount}}
      <DButton
        class={{concatClass
          "button-count"
          "like-count"
          "highlight-action"
          (if @post.yours "my-likes" "regular-likes")
        }}
        ...attributes
        @ariaPressed={{@likedUsers}}
        @icon={{this.icon}}
        @translatedAriaLabel={{i18n
          "post.sr_post_like_count_button"
          count=@post.likeCount
        }}
        @translatedTitle={{this.translatedTitle}}
        @action={{@action}}
      >
        {{@post.likeCount}}
      </DButton>
    {{/if}}
  </template>
}
