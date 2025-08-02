import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import PostActionDescription from "discourse/components/post-action-description";
import PostList from "discourse/components/post-list";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ClickTrack from "discourse/lib/click-track";
import DiscourseURL from "discourse/lib/url";
import Draft from "discourse/models/draft";
import Post from "discourse/models/post";
import { i18n } from "discourse-i18n";

export default class UserStreamComponent extends Component {
  @service dialog;
  @service composer;
  @service appEvents;
  @service currentUser;
  @service router;

  get filterClassName() {
    const filter = this.args.stream?.filter;

    if (filter) {
      return `filter-${filter.toString().replace(",", "-")}`;
    }
  }

  get usernamePath() {
    // We want the draft_username for the drafts route,
    // in-case you are editing a post that was created by another user
    // the draft usernmae will show the post item to show the editing user
    if (this.router.currentRouteName === "userActivity.drafts") {
      return "draft_username";
    }

    return "username";
  }

  @action
  async removeBookmark(userAction) {
    try {
      await Post.updateBookmark(userAction.get("post_id"), false);
      this.args.stream.remove(userAction);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async resumeDraft(item) {
    if (this.composer.get("model.viewOpen")) {
      this.composer.close();
    }
    if (item.get("postUrl")) {
      DiscourseURL.routeTo(item.get("postUrl"));
    } else {
      try {
        const draftData = await Draft.get(item.draft_key);
        const draft = draftData.draft || item.data;
        if (!draft) {
          return;
        }
        this.composer.open({
          draft,
          draftKey: item.draft_key,
          draftSequence: draftData.draft_sequence,
        });
      } catch (error) {
        popupAjaxError(error);
      }
    }
  }

  @action
  removeDraft(draft) {
    this.dialog.deleteConfirm({
      title: i18n("drafts.remove_confirmation"),
      didConfirm: async () => {
        try {
          await Draft.clear(draft.draft_key, draft.sequence);
          this.args.stream.remove(draft);
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  async loadMore() {
    await this.args.stream.findItems();

    if (this.args.stream.canLoadMore === false) {
      return [];
    }

    return this.args.stream.content;
  }

  @action
  handleClick(event) {
    if (event.target.matches("details.disabled")) {
      event.preventDefault();
      return;
    }

    if (event.target.matches(".excerpt a")) {
      return ClickTrack.trackClick(event, getOwner(this));
    }
  }

  <template>
    <PostList
      @posts={{@stream.content}}
      @idPath="post_id"
      @urlPath="postUrl"
      @usernamePath={{this.usernamePath}}
      @fetchMorePosts={{this.loadMore}}
      @titlePath="titleHtml"
      @additionalItemClasses="user-stream-item"
      @showUserInfo={{false}}
      @resumeDraft={{this.resumeDraft}}
      @removeDraft={{this.removeDraft}}
      class={{concatClass "user-stream" this.filterClassName}}
      {{on "click" this.handleClick}}
    >
      <:abovePostItemHeader as |post|>
        <PluginOutlet
          @name="user-stream-item-above"
          @outletArgs={{lazyHash item=post}}
        />
      </:abovePostItemHeader>
      <:belowPostItemMetaData as |post|>
        <span>
          <PluginOutlet
            @name="user-stream-item-header"
            @connectorTagName="div"
            @outletArgs={{lazyHash item=post}}
          />
        </span>
      </:belowPostItemMetaData>
      <:abovePostItemExcerpt as |post|>
        <PostActionDescription
          @actionCode={{post.action_code}}
          @username={{post.action_code_who}}
          @path={{post.action_code_path}}
        />

        {{#each post.children as |child|}}
          <div class="user-stream-item-actions">
            {{icon child.icon class="icon"}}
            {{#each child.items as |grandChild|}}
              <a
                href={{grandChild.userUrl}}
                data-user-card={{grandChild.username}}
                class="avatar-link"
              >
                <div class="avatar-wrapper">
                  {{avatar
                    grandChild
                    imageSize="tiny"
                    extraClasses="actor"
                    ignoreTitle="true"
                    avatarTemplatePath="acting_avatar_template"
                  }}
                </div>
              </a>
              {{#if grandChild.edit_reason}}
                &mdash;
                <span class="edit-reason">{{grandChild.edit_reason}}</span>
              {{/if}}
            {{/each}}
          </div>
        {{/each}}
      </:abovePostItemExcerpt>

      <:belowPostItem as |post|>
        {{yield post to="bottom"}}
      </:belowPostItem>
    </PostList>
  </template>
}
