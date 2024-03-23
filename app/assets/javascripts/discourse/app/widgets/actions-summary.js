import { hbs } from "ember-cli-htmlbars";
import { h } from "virtual-dom";
import { userPath } from "discourse/lib/url";
import { avatarFor } from "discourse/widgets/post";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

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

  buildClasses(atts) {
    return atts.listClassName;
  },

  buildAttributes(attrs) {
    const attributes = { role: "list" };
    if (attrs.ariaLabel) {
      attributes["aria-label"] = attrs.ariaLabel;
    }
    return attributes;
  },

  html(atts) {
    let users = atts.users;
    if (users) {
      const currentUser = this.currentUser;
      if (
        atts.addSelf &&
        !users.some((u) => u.username === currentUser.username)
      ) {
        users = users.concat(smallUserAtts(currentUser));
      }

      let description = null;

      if (atts.description) {
        description = h(
          "span.list-description",
          { attributes: { "aria-hidden": true } },
          I18n.t(atts.description, { count: atts.count })
        );
      }

      // oddly post_url is on the user
      let postUrl;
      const icons = users.map((u) => {
        postUrl = postUrl || u.post_url;
        if (u.unknown) {
          return h("div.unknown", {
            attributes: {
              title: I18n.t("post.unknown_user"),
              role: "listitem",
            },
          });
        } else {
          return avatarFor.call(this, "small", u, {
            role: "listitem",
            "aria-hidden": false,
          });
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

registerWidgetShim(
  "actions-summary",
  "section.post-actions",
  hbs`<ActionsSummary @data={{@data}} /> `
);
