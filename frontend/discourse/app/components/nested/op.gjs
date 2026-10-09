import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ShareTopicModal from "discourse/components/modal/share-topic";
import PluginOutlet from "discourse/components/plugin-outlet";
import PostAvatar from "discourse/components/post/avatar";
import PostCookedHtml from "discourse/components/post/cooked-html";
import PostLinks from "discourse/components/post/links";
import PostMenu from "discourse/components/post/menu";
import PostMetaData from "discourse/components/post/meta-data";
import PostNotice from "discourse/components/post/notice";
import TopicMap from "discourse/components/topic-map";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse/lib/environment";
import { getAbsoluteURL } from "discourse/lib/get-url";
import nestedPostUrl from "discourse/lib/nested-post-url";
import postActionFeedback from "discourse/lib/post-action-feedback";
import { nativeShare } from "discourse/lib/pwa-utils";
import { clipboardCopy } from "discourse/lib/utilities";
import { and, or } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class NestedOp extends Component {
  @service capabilities;
  @service currentUser;
  @service modal;
  @service site;
  @service siteSettings;

  get nestedShareUrl() {
    return nestedPostUrl(this.args.topic, this.args.post.post_number);
  }

  get canCreatePost() {
    return this.currentUser && this.args.topic?.details?.can_create_post;
  }

  get selected() {
    return this.args.multiSelect && this.args.postSelected?.(this.args.post);
  }

  @action
  copyLink() {
    if (this.site.mobileView) {
      return this.share();
    }

    const post = this.args.post;

    let actionCallback = () =>
      clipboardCopy(getAbsoluteURL(this.nestedShareUrl));

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
        url: getAbsoluteURL(this.nestedShareUrl),
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
      try {
        await likeAction.togglePromise(post);
      } catch (e) {
        popupAjaxError(e);
      }
    }
  }

  @action
  togglePostSelection() {
    return this.args.togglePostSelection?.(this.args.post);
  }

  @action
  selectReplies() {
    return this.args.selectReplies?.(this.args.post);
  }

  @action
  selectBelow() {
    return this.args.selectBelow?.(this.args.post);
  }

  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  <template>
    {{#if @post}}
      <div class="nested-view__op">
        {{#let (lazyHash post=@post nestedReplyView=true) as |postOutletArgs|}}
          <PluginOutlet @name="post-article" @outletArgs={{postOutletArgs}}>
            <article
              class={{dConcatClass
                "nested-view__op-article"
                "boxed"
                (if this.selected "selected")
                (if @post.deleted "is-deleted deleted")
                (if
                  (or
                    @post.isModeratorAction
                    (and @post.isWarning @post.firstPost)
                  )
                  "post--moderator moderator"
                )
              }}
              data-post-id={{@post.id}}
              data-post-number={{@post.post_number}}
              data-topic-id={{@topic.id}}
              {{@registerPost @post}}
            >
              <PluginOutlet
                @name="post-article-content"
                @outletArgs={{postOutletArgs}}
              >
                {{#if (PostNotice.shouldRender @post this.siteSettings)}}
                  <PostNotice @post={{@post}} />
                {{/if}}
                <div class="nested-view__op-row">
                  <PostAvatar @post={{@post}} />
                  <div class="nested-view__op-body">
                    <PluginOutlet
                      @name="post-metadata"
                      @outletArgs={{postOutletArgs}}
                    >
                      <PostMetaData
                        @editPost={{fn @editPost @post}}
                        @multiSelect={{@multiSelect}}
                        @post={{@post}}
                        @selectBelow={{this.selectBelow}}
                        @selected={{this.selected}}
                        @selectReplies={{this.selectReplies}}
                        @showHistory={{fn @showHistory @post}}
                        @togglePostSelection={{this.togglePostSelection}}
                      />
                    </PluginOutlet>
                    <div class="nested-view__op-content regular">
                      <PluginOutlet
                        @name="post-content-cooked-html"
                        @outletArgs={{postOutletArgs}}
                      >
                        <PostCookedHtml @post={{@post}} />
                      </PluginOutlet>
                    </div>
                    {{#if @showPostMenu}}
                      <section
                        class="nested-view__op-menu post-menu-area clearfix"
                      >
                        <PostMenu
                          @canCreatePost={{this.canCreatePost}}
                          @changeNotice={{fn @changeNotice @post}}
                          @changePostOwner={{fn @changePostOwner @post}}
                          @copyLink={{this.copyLink}}
                          @deletePost={{fn @deletePost @post}}
                          @editPost={{fn @editPost @post}}
                          @grantBadge={{fn @grantBadge @post}}
                          @lockPost={{fn @lockPost @post}}
                          @nestedReplyView={{true}}
                          @permanentlyDeletePost={{fn
                            @permanentlyDeletePost
                            @post
                          }}
                          @post={{@post}}
                          @rebakePost={{fn @rebakePost @post}}
                          @recoverPost={{fn @recoverPost @post}}
                          @replyToPost={{@replyToPost}}
                          @share={{this.share}}
                          @showFlags={{fn @showFlags @post}}
                          @showLogin={{this.showLogin}}
                          @showPagePublish={{@showPagePublish}}
                          @toggleLike={{this.toggleLike}}
                          @togglePostType={{fn @togglePostType @post}}
                          @toggleWiki={{fn @toggleWiki @post}}
                          @unhidePost={{fn @unhidePost @post}}
                          @unlockPost={{fn @unlockPost @post}}
                        />
                      </section>
                    {{/if}}
                    <PluginOutlet
                      @name="post-links"
                      @outletArgs={{postOutletArgs}}
                    >
                      <PostLinks @post={{@post}} />
                    </PluginOutlet>
                  </div>
                </div>
              </PluginOutlet>
            </article>
          </PluginOutlet>
        {{/let}}

        <div class="nested-view__topic-map topic-map">
          <TopicMap
            @model={{@topic}}
            @showPMMap={{@topic.isPrivateMessage}}
            @topicDetails={{@topic.details}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
