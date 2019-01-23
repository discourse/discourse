import { createWidget } from "discourse/widgets/widget";
import RawHtml from "discourse/widgets/raw-html";
import { iconNode } from "discourse-common/lib/icon-library";
import { h } from "virtual-dom";
import { avatarFor } from "discourse/widgets/post";
import { userPath } from "discourse/lib/url";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export function actionDescriptionHtml(actionCode, createdAt, username) {
  const dt = new Date(createdAt);
  const when = autoUpdatingRelativeAge(dt, { format: "medium-with-ago" });

  var who = "";
  if (username) {
    if (actionCode === "invited_group" || actionCode === "removed_group") {
      who = `<a class="mention-group" href="/groups/${username}">@${username}</a>`;
    } else {
      who = `<a class="mention" href="${userPath(username)}">@${username}</a>`;
    }
  }
  return I18n.t(`action_codes.${actionCode}`, { who, when }).htmlSafe();
}

export function actionDescription(actionCode, createdAt, username) {
  return function() {
    const ac = this.get(actionCode);
    if (ac) {
      return actionDescriptionHtml(ac, this.get(createdAt), this.get(username));
    }
  }.property(actionCode, createdAt);
}

const icons = {
  "closed.enabled": "lock",
  "closed.disabled": "unlock-alt",
  "autoclosed.enabled": "lock",
  "autoclosed.disabled": "unlock-alt",
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
  split_topic: "sign-out-alt",
  invited_user: "plus-circle",
  invited_group: "plus-circle",
  user_left: "minus-circle",
  removed_user: "minus-circle",
  removed_group: "minus-circle",
  public_topic: "comment",
  private_topic: "envelope",
  autobumped: "hand-point-right"
};

export function addPostSmallActionIcon(key, icon) {
  icons[key] = icon;
}

export default createWidget("post-small-action", {
  buildKey: attrs => `post-small-act-${attrs.id}`,
  tagName: "div.small-action.onscreen-post",

  buildId(attrs) {
    return `post_${attrs.post_number}`;
  },

  buildClasses(attrs) {
    if (attrs.deleted) {
      return "deleted";
    }
  },

  html(attrs) {
    const contents = [];

    if (attrs.canDelete) {
      contents.push(
        this.attach("button", {
          className: "small-action-delete",
          icon: "trash-alt",
          action: "deletePost",
          title: "post.controls.delete"
        })
      );
    }

    if (attrs.canEdit) {
      contents.push(
        this.attach("button", {
          className: "small-action-edit",
          icon: "pencil-alt",
          action: "editPost",
          title: "post.controls.edit"
        })
      );
    }

    contents.push(
      avatarFor.call(this, "small", {
        template: attrs.avatar_template,
        username: attrs.avatar,
        url: attrs.usernameUrl
      })
    );

    const description = actionDescriptionHtml(
      attrs.actionCode,
      attrs.created_at,
      attrs.actionCodeWho
    );
    contents.push(new RawHtml({ html: `<p>${description}</p>` }));

    if (attrs.cooked) {
      contents.push(
        new RawHtml({
          html: `<div class='custom-message'>${attrs.cooked}</div>`
        })
      );
    }

    return [
      h("div.topic-avatar", iconNode(icons[attrs.actionCode] || "exclamation")),
      h("div.small-action-desc", contents)
    ];
  }
});
