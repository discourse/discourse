import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { h } from "virtual-dom";
import {
  customGroupActionCodes,
  GROUP_ACTION_CODES,
  ICONS,
} from "discourse/components/post/small-action";
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
  const when = createdAt
    ? autoUpdatingRelativeAge(new Date(createdAt), {
        format: "medium-with-ago-and-on",
      })
    : "";

  let who = "";
  if (username) {
    if (
      GROUP_ACTION_CODES.includes(actionCode) ||
      customGroupActionCodes.includes(actionCode)
    ) {
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

export function addPostSmallActionIcon(key, icon) {
  ICONS[key] = icon;
}

export function addPostSmallActionClassesCallback(callback) {
  addPostSmallActionClassesCallbacks.push(callback);
}

export function resetPostSmallActionClassesCallbacks() {
  addPostSmallActionClassesCallbacks.length = 0;
}

// glimmer-post-stream: has glimmer version
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
      h("div.topic-avatar", iconNode(ICONS[attrs.actionCode] || "exclamation")),
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
