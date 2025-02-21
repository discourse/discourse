import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and, eq, or } from "truth-helpers";
import PostArticle from "discourse/components/post/article";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

export default class Post extends Component {
  @service appEvents;
  @service currentUser;
  @service dialog;
  @service keyValueStore;

  get id() {
    return `post_${this.args.post.post_number}`;
  }

  get staged() {
    return (
      this.args.post.id === -1 ||
      this.args.post.isSaving ||
      this.args.post.staged
    );
  }

  get additionalClasses() {
    return applyValueTransformer("post-class", [], {
      post: this.args.post,
    });
  }

  @action
  async toggleLike() {
    const post = this.args.post;
    const likeAction = post.likeAction;

    if (likeAction?.canToggle) {
      const result = await likeAction.togglePromise(post);

      this.appEvents.trigger("page:like-toggled", post, likeAction);
      return this.#warnIfClose(result);
    }
  }

  #warnIfClose(result) {
    if (!result || !result.acted) {
      return;
    }

    const lastWarnedLikes = this.keyValueStore.get("lastWarnedLikes");

    // only warn once per day
    const yesterday = Date.now() - 1000 * 60 * 60 * 24;
    if (lastWarnedLikes && parseInt(lastWarnedLikes, 10) > yesterday) {
      return;
    }

    const { remaining, max } = result;
    const threshold = Math.ceil(max * 0.1);

    if (remaining === threshold) {
      this.dialog.alert(i18n("post.few_likes_left"));
      this.keyValueStore.set({ key: "lastWarnedLikes", value: Date.now() });
    }
  }

  <template>
    <div
      class={{concatClass
        "topic-post"
        "clearfix"
        (if this.staged "staged")
        (if @post.selected "selected")
        (if @post.topicOwner "topic-owner")
        (if (eq this.currentUser.id @post.user_id) "current-user-post")
        (if @post.group_moderator "category-moderator")
        (if @post.hidden "post-hidden")
        (if @post.deleted "deleted")
        (if @post.primary_group_name (concat "group-" @post.primary_group_name))
        (if @post.wiki "wiki")
        (if @post.isWhisper "whisper")
        (if
          (or @post.isModeratorAction (and @post.isWarning @post.firstPost))
          "moderator"
          "regular"
        )
        (if @post.userSuspended "user-suspended")
        this.additionalClasses
      }}
    >
      {{#unless @cloaked}}
        <PostArticle id={{this.id}} @post={{@post}} />
      {{/unless}}
    </div>
  </template>
}
