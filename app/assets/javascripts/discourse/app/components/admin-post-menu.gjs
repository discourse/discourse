import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";

export default class AdminPostMenu extends Component {
  @service currentUser;
  @service siteSettings;
  @service store;
  @service adminPostMenuButtons;

  get reviewUrl() {
    return `/review?topic_id=${this.args.data.transformedPost.id}&status=all`;
  }

  get extraButtons() {
    return this.adminPostMenuButtons.callbacks
      .map((callback) => {
        return callback(this.args.data.transformedPost);
      })
      .filter(Boolean);
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
    <DropdownMenu as |dropdown|>
      {{#if this.currentUser.staff}}
        <dropdown.item>
          <DButton
            @label="review.moderation_history"
            @icon="list"
            class="btn btn-transparent moderation-history"
            @href={{this.reviewUrl}}
          />
        </dropdown.item>
      {{/if}}

      {{#if (and this.currentUser.staff (not @data.transformedPost.isWhisper))}}
        <dropdown.item>
          <DButton
            @label={{if
              @data.transformedPost.isModeratorAction
              "post.controls.revert_to_regular"
              "post.controls.convert_to_moderator"
            }}
            @icon="shield-halved"
            class={{concatClass
              "btn btn-transparent toggle-post-type"
              (if @data.transformedPost.isModeratorAction "btn-success")
            }}
            @action={{fn this.topicAction "togglePostType"}}
          />
        </dropdown.item>
      {{/if}}

      {{#if @data.transformedPost.canEditStaffNotes}}
        <dropdown.item>
          <DButton
            @icon="user-shield"
            @label={{if
              @data.transformedPost.notice
              "post.controls.change_post_notice"
              "post.controls.add_post_notice"
            }}
            @title="post.controls.unhide"
            class={{concatClass
              "btn btn-transparent"
              (if @data.transformedPost.notice "change-notice" "add-notice")
              (if @data.transformedPost.notice "btn-success")
            }}
            @action={{fn this.topicAction "changeNotice"}}
          />
        </dropdown.item>
      {{/if}}

      {{#if (and this.currentUser.staff @data.transformedPost.hidden)}}
        <dropdown.item>
          <DButton
            @label="post.controls.unhide"
            @icon="far-eye"
            class="btn btn-transparent unhide-post"
            @action={{fn this.topicAction "unhidePost"}}
          />
        </dropdown.item>
      {{/if}}

      {{#if
        (or
          this.currentUser.admin
          (and
            this.siteSettings.moderators_change_post_ownership
            this.currentUser.staff
          )
        )
      }}
        <dropdown.item>
          <DButton
            @label="post.controls.change_owner"
            @icon="user"
            @title="post.controls.lock_post_description"
            class="btn btn-transparent change-owner"
            @action={{fn this.topicAction "changePostOwner"}}
          />
        </dropdown.item>
      {{/if}}

      {{#if (and @data.transformedPost.user_id this.currentUser.staff)}}
        {{#if this.siteSettings.enable_badges}}
          <dropdown.item>
            <DButton
              @label="post.controls.grant_badge"
              @icon="certificate"
              class="btn btn-transparent grant-badge"
              @action={{fn this.topicAction "grantBadge"}}
            />
          </dropdown.item>
        {{/if}}

        {{#if @data.transformedPost.locked}}
          <dropdown.item>
            <DButton
              @label="post.controls.unlock_post"
              @icon="unlock"
              @title="post.controls.unlock_post_description"
              class={{concatClass
                "btn btn-transparent unlock-post"
                (if @data.post.locked "btn-success")
              }}
              @action={{fn this.topicAction "unlockPost"}}
            />
          </dropdown.item>
        {{else}}
          <dropdown.item>
            <DButton
              @label="post.controls.lock_post"
              @icon="lock"
              @title="post.controls.lock_post_description"
              class="btn btn-transparent lock-post"
              @action={{fn this.topicAction "lockPost"}}
            />
          </dropdown.item>
        {{/if}}
      {{/if}}

      {{#if @data.transformedPost.canPermanentlyDelete}}
        <dropdown.item>
          <DButton
            @label="post.controls.permanently_delete"
            @icon="trash-can"
            class="btn btn-transparent permanently-delete"
            @action={{fn this.topicAction "permanentlyDeletePost"}}
          />
        </dropdown.item>
      {{/if}}

      {{#if (or @data.transformedPost.canManage @data.transformedPost.canWiki)}}
        {{#if @data.transformedPost.wiki}}
          <dropdown.item>
            <DButton
              @label="post.controls.unwiki"
              @icon="far-pen-to-square"
              class={{concatClass
                "btn btn-transparent wiki wikied"
                (if @data.transformedPost.wiki "btn-success")
              }}
              @action={{fn this.topicAction "toggleWiki"}}
            />
          </dropdown.item>
        {{else}}
          <dropdown.item>
            <DButton
              @label="post.controls.wiki"
              @icon="far-pen-to-square"
              class="btn btn-transparent wiki"
              @action={{fn this.topicAction "toggleWiki"}}
            />
          </dropdown.item>
        {{/if}}
      {{/if}}

      {{#if @data.transformedPost.canPublishPage}}
        <dropdown.item>
          <DButton
            @label="post.controls.publish_page"
            @icon="file"
            class="btn btn-transparent publish-page"
            @action={{fn this.topicAction "showPagePublish"}}
          />
        </dropdown.item>
      {{/if}}

      {{#if @data.transformedPost.canManage}}
        <dropdown.item>
          <DButton
            @label="post.controls.rebake"
            @icon="rotate"
            class="btn btn-transparent rebuild-html"
            @action={{fn this.topicAction "rebakePost"}}
          />
        </dropdown.item>
      {{/if}}

      {{#each this.extraButtons as |button|}}
        <dropdown.item>
          <DButton
            @label={{button.label}}
            @translatedLabel={{button.translatedLabel}}
            @icon={{button.icon}}
            class={{concatClass "btn btn-transparent" button.className}}
            @action={{fn this.extraAction button}}
          />
        </dropdown.item>
      {{/each}}
    </DropdownMenu>
  </template>
}
