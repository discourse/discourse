import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import PostCookedHtml from "discourse/components/post/cooked-html";
import UserAvatar from "discourse/components/user-avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import { applyValueTransformer } from "discourse/lib/transformer";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

// TODO (glimmer-post-stream) remove the export after removing the legacy widget code
export const GROUP_ACTION_CODES = ["invited_group", "removed_group"];
export const customGroupActionCodes = [];

export const ICONS = {
  "closed.enabled": "lock",
  "closed.disabled": "unlock-keyhole",
  "autoclosed.enabled": "lock",
  "autoclosed.disabled": "unlock-keyhole",
  "archived.enabled": "folder",
  "archived.disabled": "folder-open",
  "pinned.enabled": "thumbtack",
  "pinned.disabled": "thumbtack unpinned",
  "pinned_globally.enabled": "thumbtack",
  "pinned_globally.disabled": "thumbtack unpinned",
  "banner.enabled": "thumbtack",
  "banner.disabled": "thumbtack unpinned",
  "visible.enabled": "far-eye",
  "visible.disabled": "far-eye-slash",
  split_topic: "right-from-bracket",
  invited_user: "circle-plus",
  invited_group: "circle-plus",
  user_left: "circle-minus",
  removed_user: "circle-minus",
  removed_group: "circle-minus",
  public_topic: "comment",
  open_topic: "comment",
  private_topic: "envelope",
  autobumped: "hand-point-right",
};

export function addGroupPostSmallActionCode(actionCode) {
  customGroupActionCodes.push(actionCode);
}

// only for testing purposes
export function resetGroupPostSmallActionCodes() {
  customGroupActionCodes.length = 0;
}

export default class PostSmallAction extends Component {
  @cached
  get CustomComponent() {
    return applyValueTransformer("post-small-action-custom-component", null, {
      actionCode: this.code,
      post: this.post,
    });
  }

  get additionalClasses() {
    return applyValueTransformer("post-small-action-class", [], {
      post: this.args.post,
    });
  }

  get code() {
    return this.args.post.action_code;
  }

  @cached
  get createdAt() {
    return new Date(this.args.post.created_at);
  }

  get description() {
    const when = this.createdAt
      ? autoUpdatingRelativeAge(this.createdAt, {
          format: "medium-with-ago-and-on",
        })
      : "";

    let who = "";
    if (this.username) {
      if (this.isGroupAction) {
        who = `<a class="mention-group" href="/g/${this.username}">@${this.username}</a>`;
      } else {
        who = `<a class="mention" href="${userPath(this.username)}">@${
          this.username
        }</a>`;
      }
    }

    return htmlSafe(
      i18n(`action_codes.${this.code}`, { who, when, path: this.path })
    );
  }

  @cached
  get icon() {
    return applyValueTransformer(
      "post-small-action-icon",
      ICONS[this.code] || "exclamation",
      { code: this.code, post: this.args.post }
    );
  }

  get isGroupAction() {
    return (
      GROUP_ACTION_CODES.includes(this.code) ||
      customGroupActionCodes.includes(this.code)
    );
  }

  get path() {
    return getURL(
      this.args.post.action_code_path || `/t/${this.args.post.topic.id}`
    );
  }

  get username() {
    return this.args.post.action_code_who;
  }

  <template>
    <article
      ...attributes
      class={{unless
        @cloaked
        (concatClass
          "small-action"
          "onscreen-post"
          (if @post.deleted "deleted")
          this.additionalClasses
        )
      }}
      aria-label={{i18n
        "share.post"
        postNumber=@post.post_number
        username=@post.username
      }}
      role="region"
      data-post-number={{@post.post_number}}
    >
      {{#unless @cloaked}}
        <div class="topic-avatar">
          {{icon this.icon}}
        </div>
        <div class="small-action-desc">
          <div class="small-action-contents">
            <UserAvatar
              @ariaHidden={{false}}
              @size="small"
              @user={{@post.user}}
            />
            {{#if this.CustomComponent}}
              <this.CustomComponent
                @code={{this.code}}
                @post={{this.post}}
                @createdAt={{this.createdAt}}
                @path={{this.path}}
                @username={{this.username}}
              />
            {{else}}
              <p>{{htmlSafe this.description}}</p>
            {{/if}}
          </div>
          <div class="small-action-buttons">
            {{#if @post.canRecover}}
              <DButton
                class="btn-flat small-action-recover"
                @icon="arrow-rotate-left"
                @action={{@recoverPost}}
                @title="post.controls.undelete"
              />
            {{else if @post.can_edit}}
              <DButton
                class="btn-flat small-action-edit"
                @icon="pencil"
                @action={{@editPost}}
                @title="post.controls.edit"
              />
            {{/if}}
            {{#if @post.canDelete}}
              <DButton
                class="btn-flat btn-danger small-action-delete"
                @icon="trash-can"
                @action={{@deletePost}}
                @title="post.controls.delete"
              />
            {{/if}}
          </div>
          {{#unless this.CustomComponent}}
            {{#if @post.cooked}}
              <div class="small-action-custom-message">
                <PostCookedHtml @post={{@post}} />
              </div>
            {{/if}}
          {{/unless}}
        </div>
      {{/unless}}
    </article>
  </template>
}
