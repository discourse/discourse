import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { fn } from "@ember/helper";
import and from "truth-helpers/helpers/and";
import or from "truth-helpers/helpers/or";
import not from "truth-helpers/helpers/not";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";

export default class AdminPostMenu extends Component {
  @service currentUser;
  @service siteSettings;
  @service store;
  @service adminPostMenuButtons;

  <template>
    <ul>
      {{#if this.currentUser.staff}}
        <li>
          <DButton
            @label="review.moderation_history"
            @icon="list"
            class="btn btn-transparent moderation-history"
            @href={{this.reviewUrl}}
          />
        </li>
      {{/if}}

      {{#if (and this.currentUser.staff (not @data.transformedPost.isWhisper))}}
        <li>
          <DButton
            @label={{if
              @data.transformedPost.isModeratorAction
              "post.controls.revert_to_regular"
              "post.controls.convert_to_moderator"
            }}
            @icon="shield-alt"
            class={{concatClass
              "btn btn-transparent toggle-post-type"
              (if @data.transformedPost.isModeratorAction "btn-success")
            }}
            @action={{fn this.topicAction "togglePostType"}}
          />
        </li>
      {{/if}}

      {{#if @data.transformedPost.canEditStaffNotes}}
        <li>
          <DButton
            @icon="user-shield"
            @label={{if
              @data.transformedPost.notice
              "post.controls.change_post_notice"
              "post.controls.add_post_notice"
            }}
            title="post.controls.unhide"
            class={{concatClass
              "btn btn-transparent"
              (if @data.transformedPost.notice "change-notice" "add-notice")
              (if @data.transformedPost.notice "btn-success")
            }}
            @action={{fn this.topicAction "changeNotice"}}
          />
        </li>
      {{/if}}

      {{#if (and this.currentUser.staff @data.transformedPost.hidden)}}
        <li>
          <DButton
            @label="post.controls.unhide"
            @icon="far-eye"
            class="btn btn-transparent unhide-post"
            @action={{fn this.topicAction "unhidePost"}}
          />
        </li>
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
        <li>
          <DButton
            @label="post.controls.change_owner"
            @icon="user"
            title="post.controls.lock_post_description"
            class="btn btn-transparent change-owner"
            @action={{fn this.topicAction "changePostOwner"}}
          />
        </li>
      {{/if}}

      {{#if (and @data.transformedPost.user_id this.currentUser.staff)}}
        {{#if this.siteSettings.enable_badges}}
          <li>
            <DButton
              @label="post.controls.grant_badge"
              @icon="certificate"
              class="btn btn-transparent grant-badge"
              @action={{fn this.topicAction "grantBadge"}}
            />
          </li>
        {{/if}}

        {{#if @data.transformedPost.locked}}
          <li>
            <DButton
              @label="post.controls.unlock_post"
              @icon="unlock"
              title="post.controls.unlock_post_description"
              class={{concatClass
                "btn btn-transparent unlock-post"
                (if @data.post.locked "btn-success")
              }}
              @action={{fn this.topicAction "unlockPost"}}
            />
          </li>
        {{else}}
          <li>
            <DButton
              @label="post.controls.lock_post"
              @icon="lock"
              title="post.controls.lock_post_description"
              class="btn btn-transparent lock-post"
              @action={{fn this.topicAction "lockPost"}}
            />
          </li>
        {{/if}}
      {{/if}}

      {{#if @data.transformedPost.canPermanentlyDelete}}
        <li>
          <DButton
            @label="post.controls.permanently_delete"
            @icon="trash-alt"
            class="btn btn-transparent permanently-delete"
            @action={{fn this.topicAction "permanentlyDeletePost"}}
          />
        </li>
      {{/if}}

      {{#if (or @data.transformedPost.canManage @data.transformedPost.canWiki)}}
        {{#if @data.transformedPost.wiki}}
          <li>
            <DButton
              @label="post.controls.unwiki"
              @icon="far-edit"
              class={{concatClass
                "btn btn-transparent wiki wikied"
                (if @data.transformedPost.wiki "btn-success")
              }}
              @action={{fn this.topicAction "toggleWiki"}}
            />
          </li>
        {{else}}
          <li>
            <DButton
              @label="post.controls.wiki"
              @icon="far-edit"
              class="btn btn-transparent wiki"
              @action={{fn this.topicAction "toggleWiki"}}
            />
          </li>
        {{/if}}
      {{/if}}

      {{#if @data.transformedPost.canPublishPage}}
        <li>
          <DButton
            @label="post.controls.publish_page"
            @icon="file"
            class="btn btn-transparent publish-page"
            @action={{fn this.topicAction "showPagePublish"}}
          />
        </li>
      {{/if}}

      {{#if @data.transformedPost.canManage}}
        <li>
          <DButton
            @label="post.controls.rebake"
            @icon="sync-alt"
            class="btn btn-transparent rebuild-html"
            @action={{fn this.topicAction "rebakePost"}}
          />
        </li>
      {{/if}}

      {{#each this.extraButtons as |button|}}
        <li>
          <DButton
            @label={{button.label}}
            @translatedLabel={{button.translatedLabel}}
            @icon={{button.icon}}
            class={{concatClass "btn btn-transparent" button.className}}
            @action={{fn this.extraAction button}}
          />
        </li>
      {{/each}}
    </ul>
  </template>

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

    await this.args.data.scheduleRerender();
  }

  @action
  async extraAction(button) {
    await this.args.close();
    await button.action(this.args.data.post);
    await this.args.data.scheduleRerender();
  }
}
