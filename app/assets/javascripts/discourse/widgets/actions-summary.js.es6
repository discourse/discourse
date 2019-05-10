import { createWidget } from "discourse/widgets/widget";
import { avatarFor } from "discourse/widgets/post";
import { h } from "virtual-dom";
import { userPath } from "discourse/lib/url";
import hbs from "discourse/widgets/hbs-compiler";

export function avatarAtts(user) {
  return {
    template: user.avatar_template,
    username: user.username,
    post_url: user.post_url,
    url: userPath(user.username_lower)
  };
}

createWidget("small-user-list", {
  tagName: "div.clearfix",

  buildClasses(atts) {
    return atts.listClassName;
  },

  html(atts) {
    let users = atts.users;
    if (users) {
      const currentUser = this.currentUser;
      if (
        atts.addSelf &&
        !users.some(u => u.username === currentUser.username)
      ) {
        users = users.concat(avatarAtts(currentUser));
      }

      let description = null;

      if (atts.description) {
        description = I18n.t(atts.description, { count: atts.count });
      }

      // oddly post_url is on the user
      let postUrl;
      const icons = users.map(u => {
        postUrl = postUrl || u.post_url;
        return avatarFor.call(this, "small", u);
      });

      if (postUrl) {
        description = h(
          "a",
          { attributes: { href: Discourse.getURL(postUrl) } },
          description
        );
      }

      let buffer = [icons];
      if (description) {
        buffer.push(description);
      }
      return buffer;
    }
  }
});

createWidget("action-link", {
  tagName: "span.action-link",
  template: hbs`<a>{{attrs.text}}. </a>`,

  buildClasses(attrs) {
    return attrs.className;
  },

  click() {
    this.sendWidgetAction(this.attrs.action);
  }
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
  `
});
