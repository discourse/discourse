import I18n from "I18n";
import { avatarFor } from "discourse/widgets/post";
import { createWidget } from "discourse/widgets/widget";
import getURL from "discourse-common/lib/get-url";
import { h } from "virtual-dom";
import hbs from "discourse/widgets/hbs-compiler";
import { userPath } from "discourse/lib/url";

export function smallUserAtts(user) {
  return {
    template: user.avatar_template,
    username: user.username,
    post_url: user.post_url,
    url: userPath(user.username_lower),
    unknown: user.unknown,
  };
}

createWidget("small-user-list", {
  tagName: "div.clearfix.small-user-list",

  buildClasses(attrs) {
    return attrs.listClassName;
  },

  html(attrs) {
    let users = attrs.users;
    if (users) {
      const currentUser = this.currentUser;
      if (
        attrs.addSelf &&
        !users.some((u) => u.username === currentUser.username)
      ) {
        users = users.concat(smallUserAtts(currentUser));
      }

      let description = null;

      if (attrs.description) {
        description = I18n.t(attrs.description, { count: attrs.count });
      }

      // oddly post_url is on the user
      let postUrl;
      const icons = users.map((u) => {
        postUrl = postUrl || u.post_url;
        if (u.unknown) {
          return h("div.unknown", {
            attributes: { title: I18n.t("post.unknown_user") },
          });
        } else {
          return avatarFor.call(this, "small", u);
        }
      });

      if (postUrl) {
        description = h(
          "a",
          { attributes: { href: getURL(postUrl) } },
          description
        );
      }

      let buffer = [icons];
      if (description) {
        buffer.push(description);
      }
      return buffer;
    }
  },
});

createWidget("action-link", {
  tagName: "span.action-link",
  template: hbs`<a>{{attrs.text}}. </a>`,

  buildClasses(attrs) {
    return attrs.className;
  },

  click() {
    this.sendWidgetAction(this.attrs.action);
  },
});

export default createWidget("actions-summary", {
  tagName: "section.post-actions",
  template: hbs`
    {{#each attrs.actionsSummary as |as|}}
      <div class='post-action'>{{as.description}}</div>
      <div class='clearfix'></div>
    {{/each}}
    {{#if attrs.deleted_at}}
      <div class='post-action deleted-post'>
        {{d-icon "far-trash-alt"}}
        {{avatar size="small" template=attrs.deletedByAvatarTemplate username=attrs.deletedByUsername}}
        {{date attrs.deleted_at}}
      </div>
    {{/if}}
  `,
});
