import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { and, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class AdminPostMenu extends Component {
  @service currentUser;
  @service siteSettings;
  @service adminPostMenuButtons;

  get reviewUrl() {
    return `/review?topic_id=${this.args.data.post.id}&status=all`;
  }

  get extraButtons() {
    return this.adminPostMenuButtons.callbacks
      .map((callback) => {
        return callback(this.args.data.post);
      })
      .filter(Boolean);
  }

  get canChangePostOwner() {
    return this.currentUser?.canChangePostOwner;
  }

  get nestedPinButton() {
    if (!this.siteSettings.nested_replies_enabled) {
      return null;
    }
    const topicController = getOwner(this).lookup("controller:topic");
    if (!topicController?.shouldRenderNestedView) {
      return null;
    }

    const post = this.args.data.post;
    if (post.post_number === 1) {
      return null;
    }
    if (post.reply_to_post_number && post.reply_to_post_number !== 1) {
      return null;
    }

    const nestedController = getOwner(this).lookup("controller:nested");
    const isPinned = nestedController?.pinnedPostIds?.includes(post.id);

    return {
      isPinned,
      label: isPinned
        ? "nested_replies.unpin_reply"
        : "nested_replies.pin_reply",
      action: () => nestedController?.togglePinPost(post),
    };
  }

  @action
  async topicAction(actionName) {
    await this.args.close();

    try {
      await this.args.data[actionName]?.();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(`Unknown error while attempting \`${actionName}\`:`, error);
    }

    await this.args.data.scheduleRerender?.();
  }

  @action
  async extraAction(button) {
    await this.args.close();
    await button.action(this.args.data.post);
    await this.args.data.scheduleRerender?.();
  }

  <template>
    <DDropdownMenu as |dropdown|>
      {{#if this.currentUser.staff}}
        <dropdown.item>
          <DButton
            class="btn btn-transparent moderation-history"
            @href={{this.reviewUrl}}
            @icon="list"
            @label="review.moderation_history"
          />
        </dropdown.item>
      {{/if}}

      {{#if (and this.currentUser.staff (not @data.post.isWhisper))}}
        <dropdown.item>
          <DButton
            class={{dConcatClass
              "btn btn-transparent toggle-post-type"
              (if @data.post.isModeratorAction "btn-success")
            }}
            @action={{fn this.topicAction "togglePostType"}}
            @icon="shield-halved"
            @label={{if
              @data.post.isModeratorAction
              "post.controls.revert_to_regular"
              "post.controls.convert_to_moderator"
            }}
            @title={{if
              @data.post.isModeratorAction
              ""
              "post.controls.convert_to_moderator_description"
            }}
          />
        </dropdown.item>
      {{/if}}

      {{#if @data.post.canEditStaffNotes}}
        <dropdown.item>
          <DButton
            class={{dConcatClass
              "btn btn-transparent"
              (if @data.post.notice "change-notice" "add-notice")
              (if @data.post.notice "btn-success")
            }}
            @action={{fn this.topicAction "changeNotice"}}
            @icon="user-shield"
            @label={{if
              @data.post.notice
              "post.controls.change_post_notice"
              "post.controls.add_post_notice"
            }}
            @title="post.controls.add_post_notice_description"
          />
        </dropdown.item>
      {{/if}}

      {{#if (and this.currentUser.staff @data.post.hidden)}}
        <dropdown.item>
          <DButton
            class="btn btn-transparent unhide-post"
            @action={{fn this.topicAction "unhidePost"}}
            @icon="far-eye"
            @label="post.controls.unhide"
          />
        </dropdown.item>
      {{/if}}

      {{#if this.canChangePostOwner}}
        <dropdown.item>
          <DButton
            class="btn btn-transparent change-owner"
            @action={{fn this.topicAction "changePostOwner"}}
            @icon="user"
            @label="post.controls.change_owner"
          />
        </dropdown.item>
      {{/if}}

      {{#if (and @data.post.user_id this.currentUser.staff)}}
        {{#if this.siteSettings.enable_badges}}
          <dropdown.item>
            <DButton
              class="btn btn-transparent grant-badge"
              @action={{fn this.topicAction "grantBadge"}}
              @icon="certificate"
              @label="post.controls.grant_badge"
            />
          </dropdown.item>
        {{/if}}

        {{#if @data.post.locked}}
          <dropdown.item>
            <DButton
              class={{dConcatClass
                "btn btn-transparent unlock-post"
                (if @data.post.locked "btn-success")
              }}
              @action={{fn this.topicAction "unlockPost"}}
              @icon="unlock"
              @label="post.controls.unlock_post"
              @title="post.controls.unlock_post_description"
            />
          </dropdown.item>
        {{else}}
          <dropdown.item>
            <DButton
              class="btn btn-transparent lock-post"
              @action={{fn this.topicAction "lockPost"}}
              @icon="lock"
              @label="post.controls.lock_post"
              @title="post.controls.lock_post_description"
            />
          </dropdown.item>
        {{/if}}
      {{/if}}

      {{#if @data.post.canPermanentlyDelete}}
        <dropdown.item>
          <DButton
            class="btn btn-transparent permanently-delete"
            @action={{fn this.topicAction "permanentlyDeletePost"}}
            @icon="trash-can"
            @label="post.controls.permanently_delete"
          />
        </dropdown.item>
      {{/if}}

      {{#if (or @data.post.canManage @data.post.can_wiki)}}
        {{#if @data.post.wiki}}
          <dropdown.item>
            <DButton
              class={{dConcatClass
                "btn btn-transparent wiki wikied"
                (if @data.post.wiki "btn-success")
              }}
              @action={{fn this.topicAction "toggleWiki"}}
              @icon="far-pen-to-square"
              @label="post.controls.unwiki"
            />
          </dropdown.item>
        {{else}}
          <dropdown.item>
            <DButton
              class="btn btn-transparent wiki"
              @action={{fn this.topicAction "toggleWiki"}}
              @icon="far-pen-to-square"
              @label="post.controls.wiki"
              @title="post.controls.wiki_description"
            />
          </dropdown.item>
        {{/if}}
      {{/if}}

      {{#if @data.post.canPublishPage}}
        <dropdown.item>
          <DButton
            class="btn btn-transparent publish-page"
            @action={{fn this.topicAction "showPagePublish"}}
            @icon="file"
            @label="post.controls.publish_page"
            @title="post.controls.publish_page_description"
          />
        </dropdown.item>
      {{/if}}

      {{#if @data.post.canManage}}
        <dropdown.item>
          <DButton
            class="btn btn-transparent rebuild-html"
            @action={{fn this.topicAction "rebakePost"}}
            @icon="rotate"
            @label="post.controls.rebake"
            @title="post.controls.rebake_description"
          />
        </dropdown.item>
      {{/if}}

      {{#if this.nestedPinButton}}
        <dropdown.item>
          <DButton
            class="btn btn-transparent pin-reply"
            @action={{fn this.extraAction this.nestedPinButton}}
            @icon="thumbtack"
            @label={{this.nestedPinButton.label}}
          />
        </dropdown.item>
      {{/if}}

      {{#each this.extraButtons as |button|}}
        <dropdown.item>
          <DButton
            class={{dConcatClass "btn btn-transparent" button.className}}
            @action={{fn this.extraAction button}}
            @icon={{button.icon}}
            @label={{button.label}}
            @title={{button.title}}
            @translatedLabel={{button.translatedLabel}}
            @translatedTitle={{button.translatedTitle}}
          />
        </dropdown.item>
      {{/each}}
    </DDropdownMenu>
  </template>
}
