import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import $ from "jquery";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import PostActionDescription from "discourse/components/post-action-description";
import PostList from "discourse/components/post-list";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ClickTrack from "discourse/lib/click-track";
import DiscourseURL from "discourse/lib/url";
import { NEW_TOPIC_KEY } from "discourse/models/composer";
import Draft from "discourse/models/draft";
import Post from "discourse/models/post";
import dIcon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class UserStreamComponent extends Component {
  @service dialog;
  @service composer;
  @service appEvents;
  @service currentUser;
  @tracked lastDecoratedElement;
  @tracked filterClassName = "";

  eventListeners = modifier((element) => {
    $(element).on("click.details-disabled", "details.disabled", () => false);
    $(element).on("click.discourse-redirect", ".excerpt a", (e) => {
      return ClickTrack.trackClick(e, getOwner(this));
    });
    later(() => {
      this.updateLastDecoratedElement();
      this.appEvents.trigger("decorate-non-stream-cooked-element", element);
    });

    return () => {
      $(element).off("click.details-disabled", "details.disabled");
      // Unbind link tracking
      $(element).off("click.discourse-redirect", ".excerpt a");
    };
  });

  constructor() {
    super(...arguments);
    this.setFilterClassName();
  }

  setFilterClassName() {
    const filter = this.args.stream?.filter;
    if (filter) {
      this.filterClassName = `filter-${filter.toString().replace(",", "-")}`;
    }
  }

  @action
  updateLastDecoratedElement() {
    const nodes = document.querySelectorAll(".user-stream-item");
    if (!nodes || nodes.length === 0) {
      return;
    }

    const lastElement = nodes[nodes.length - 1];
    if (lastElement === this.lastDecoratedElement) {
      return;
    }
    this.lastDecoratedElement = lastElement;
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
    this.dialog.yesNoConfirm({
      message: i18n("drafts.remove_confirmation"),
      didConfirm: async () => {
        try {
          await Draft.clear(draft.draft_key, draft.sequence);
          this.args.stream.remove(draft);

          if (draft.draft_key === NEW_TOPIC_KEY) {
            this.currentUser.has_topic_draft = false;
          }
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

    later(() => {
      let element = this.lastDecoratedElement?.nextElementSibling;
      while (element) {
        this.appEvents.trigger("user-stream:new-item-inserted", element);
        this.appEvents.trigger("decorate-non-stream-cooked-element", element);
        element = element.nextElementSibling;
      }
      this.updateLastDecoratedElement();
    });

    return this.args.stream.content;
  }

  <template>
    <PostList
      @posts={{@stream.content}}
      @fetchMorePosts={{this.loadMore}}
      @additionalItemClasses="user-stream-item"
      @showUserInfo={{false}}
      class={{concatClass "user-stream" this.filterClassName}}
      {{this.eventListeners this.args.stream}}
    >
      <:abovePostItemHeader as |post|>
        <PluginOutlet
          @name="user-stream-item-above"
          @outletArgs={{hash item=post}}
        />
      </:abovePostItemHeader>
      <:belowPostItemMetaData as |post|>
        <span>
          <PluginOutlet
            @name="user-stream-item-header"
            @connectorTagName="div"
            @outletArgs={{hash item=post}}
          />
        </span>
      </:belowPostItemMetaData>
      <:abovePostItemExcerpt as |post|>
        <PostActionDescription
          @actionCode={{post.action_code}}
          @createdAt={{post.created_at}}
          @username={{post.action_code_who}}
          @path={{post.action_code_path}}
        />

        {{#each post.children as |child|}}
          <div class="user-stream-item-actions">
            {{dIcon child.icon class="icon"}}
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

        {{#if post.editableDraft}}
          <div class="user-stream-item-draft-actions">
            <DButton
              @action={{fn this.resumeDraft post}}
              @icon="pencil"
              @label="drafts.resume"
              class="btn-default resume-draft"
            />
            <DButton
              @action={{fn this.removeDraft post}}
              @icon="trash-can"
              @title="drafts.remove"
              class="btn-danger remove-draft"
            />
          </div>
        {{/if}}
      </:abovePostItemExcerpt>

      <:belowPostItem as |post|>
        {{yield post to="bottom"}}
      </:belowPostItem>
    </PostList>
  </template>
}
