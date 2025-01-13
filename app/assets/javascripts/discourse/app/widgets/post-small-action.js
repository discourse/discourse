import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { h } from "virtual-dom";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import { iconNode } from "discourse/lib/icon-library";
import { userPath } from "discourse/lib/url";
import DecoratorHelper from "discourse/widgets/decorator-helper";
import { avatarFor } from "discourse/widgets/post";
import PostCooked from "discourse/widgets/post-cooked";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";
import { i18n } from "discourse-i18n";

export function actionDescriptionHtml(actionCode, createdAt, username, path) {
  const dt = new Date(createdAt);
  const when = autoUpdatingRelativeAge(dt, {
    format: "medium-with-ago-and-on",
  });

  let who = "";
  if (username) {
    if (groupActionCodes.includes(actionCode)) {
      who = `<a class="mention-group" href="/g/${username}">@${username}</a>`;
    } else {
      who = `<a class="mention" href="${userPath(username)}">@${username}</a>`;
    }
  }
  return htmlSafe(i18n(`action_codes.${actionCode}`, { who, when, path }));
}

export function actionDescription(
  actionCode,
  createdAt,
  username,
  path = null
) {
  return computed(actionCode, createdAt, function () {
    const ac = this.get(actionCode);
    if (ac) {
      return actionDescriptionHtml(
        ac,
        this.get(createdAt),
        this.get(username),
        path ? this.get(path) : null
      );
    }
  });
}

const addPostSmallActionClassesCallbacks = [];

const groupActionCodes = ["invited_group", "removed_group"];

const icons = {
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

export function addPostSmallActionIcon(key, icon) {
  icons[key] = icon;
}

export function addGroupPostSmallActionCode(actionCode) {
  groupActionCodes.push(actionCode);
}

export function addPostSmallActionClassesCallback(callback) {
  addPostSmallActionClassesCallbacks.push(callback);
}

export function resetPostSmallActionClassesCallbacks() {
  addPostSmallActionClassesCallbacks.length = 0;
}

export default createWidget("post-small-action", {
  buildKey: (attrs) => `post-small-act-${attrs.id}`,
  tagName: "article.small-action.onscreen-post",

  buildAttributes(attrs) {
    return {
      "aria-label": i18n("share.post", {
        postNumber: attrs.post_number,
        username: attrs.username,
      }),
      role: "region",
    };
  },

  buildId(attrs) {
    return `post_${attrs.post_number}`;
  },

  buildClasses(attrs) {
    let classNames = [];

    if (attrs.deleted) {
      classNames.push("deleted");
    }

    if (addPostSmallActionClassesCallbacks.length > 0) {
      addPostSmallActionClassesCallbacks.forEach((callback) => {
        const additionalClasses = callback.call(this, attrs);

        if (additionalClasses) {
          classNames.push(...additionalClasses);
        }
      });
    }

    return classNames;
  },

  html(attrs) {
    const contents = [];
    const buttons = [];

    contents.push(
      avatarFor.call(this, "small", {
        template: attrs.avatar_template,
        username: attrs.username,
        url: attrs.usernameUrl,
        ariaHidden: false,
      })
    );

    if (attrs.actionDescriptionWidget) {
      contents.push(this.attach(attrs.actionDescriptionWidget, attrs));
    } else {
      const description = actionDescriptionHtml(
        attrs.actionCode,
        new Date(attrs.created_at),
        attrs.actionCodeWho,
        attrs.actionCodePath
      );
      contents.push(new RawHtml({ html: `<p>${description}</p>` }));
    }

    if (attrs.canRecover) {
      buttons.push(
        this.attach("button", {
          className: "btn-flat small-action-recover",
          icon: "arrow-rotate-left",
          action: "recoverPost",
          title: "post.controls.undelete",
        })
      );
    }

    if (attrs.canEdit && !attrs.canRecover) {
      buttons.push(
        this.attach("button", {
          className: "btn-flat small-action-edit",
          icon: "pencil",
          action: "editPost",
          title: "post.controls.edit",
        })
      );
    }

    if (attrs.canDelete) {
      buttons.push(
        this.attach("button", {
          className: "btn-flat btn-danger small-action-delete",
          icon: "trash-can",
          action: "deletePost",
          title: "post.controls.delete",
        })
      );
    }

    return [
      h("div.topic-avatar", iconNode(icons[attrs.actionCode] || "exclamation")),
      h("div.small-action-desc", [
        h("div.small-action-contents", contents),
        h("div.small-action-buttons", buttons),
        !attrs.actionDescriptionWidget && attrs.cooked
          ? h("div.small-action-custom-message", [
              new PostCooked(
                attrs,
                new DecoratorHelper(this),
                this.currentUser
              ),
            ])
          : null,
      ]),
    ];
  },
});
