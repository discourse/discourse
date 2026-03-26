import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ShareTopicModal from "discourse/components/modal/share-topic";
import PostAvatar from "discourse/components/post/avatar";
import PostCookedHtml from "discourse/components/post/cooked-html";
import PostMenu from "discourse/components/post/menu";
import PostMetaData from "discourse/components/post/meta-data";
import { isTesting } from "discourse/lib/environment";
import { getAbsoluteURL } from "discourse/lib/get-url";
import postActionFeedback from "discourse/lib/post-action-feedback";
import { nativeShare } from "discourse/lib/pwa-utils";
import { clipboardCopy } from "discourse/lib/utilities";

export default class NestedOp extends Component {
  @service capabilities;
  @service currentUser;
  @service modal;
  @service site;

  <template>
    {{#if @post}}
      <div class="nested-view__op">
        <article
          class="nested-view__op-article boxed"
          data-post-id={{@post.id}}
          data-post-number={{@post.post_number}}
          {{@registerPost @post}}
        >
          <div class="nested-view__op-row">
            <PostAvatar @post={{@post}} />
            <div class="nested-view__op-body">
              <PostMetaData
                @post={{@post}}
                @editPost={{fn @editPost @post}}
                @showHistory={{fn @showHistory @post}}
              />
              <div class="nested-view__op-content">
                <PostCookedHtml @post={{@post}} />
              </div>
              {{#if @showPostMenu}}
                <section class="nested-view__op-menu post-menu-area clearfix">
                  <PostMenu
                    @post={{@post}}
                    @canCreatePost={{this.canCreatePost}}
                    @copyLink={{this.copyLink}}
                    @replyToPost={{@replyToPost}}
                    @editPost={{fn @editPost @post}}
                    @share={{this.share}}
                    @toggleLike={{this.toggleLike}}
                    @showLogin={{this.showLogin}}
                  />
                </section>
              {{/if}}
            </div>
          </div>
        </article>
      </div>
    {{/if}}
  </template>

  @action
  copyLink() {
    if (this.site.mobileView) {
      return this.share();
    }

    const post = this.args.post;

    let actionCallback = () => clipboardCopy(getAbsoluteURL(post.shareUrl));

    if (isTesting()) {
      actionCallback = () => {};
    }

    postActionFeedback({
      postId: post.id,
      actionClass: "post-action-menu__copy-link",
      messageKey: "post.controls.link_copied",
      actionCallback,
      errorCallback: () => this.share(),
    });
  }

  @action
  async share() {
    const post = this.args.post;
    const topic = this.args.topic;

    try {
      await nativeShare(this.capabilities, {
        url: getAbsoluteURL(post.shareUrl),
      });
    } catch {
      this.modal.show(ShareTopicModal, {
        model: { category: topic.category, topic, post },
      });
    }
  }

  @action
  async toggleLike() {
    const post = this.args.post;
    const likeAction = post.likeAction;
    if (likeAction?.canToggle) {
      await likeAction.togglePromise(post);
    }
  }

  get canCreatePost() {
    return this.currentUser && this.args.topic?.details?.can_create_post;
  }

  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }
}
