import { iconNode } from "discourse-common/lib/icon-library";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { avatarFor } from "discourse/widgets/post";
import hbs from "discourse/widgets/hbs-compiler";

createWidget("pm-remove-group-link", {
  tagName: "a.remove-invited",
  template: hbs`{{d-icon "times"}}`,

  click() {
    bootbox.confirm(
      I18n.t("private_message_info.remove_allowed_group", {
        name: this.attrs.name
      }),
      confirmed => {
        if (confirmed) {
          this.sendWidgetAction("removeAllowedGroup", this.attrs);
        }
      }
    );
  }
});

createWidget("pm-map-user-group", {
  tagName: "div.user.group",

  transform(attrs) {
    return { href: Discourse.getURL(`/groups/${attrs.group.name}`) };
  },

  template: hbs`
    {{fa-icon 'users'}}
    <a href={{transformed.href}}>{{attrs.group.name}}</a>
    {{#if attrs.canRemoveAllowedUsers}}
      {{attach widget="pm-remove-group-link" attrs=attrs.group}}
    {{/if}}
  `
});

createWidget("pm-remove-link", {
  tagName: "a.remove-invited",
  template: hbs`{{d-icon "times"}}`,

  click() {
    const messageKey = this.attrs.isCurrentUser
      ? "leave_message"
      : "remove_allowed_user";

    bootbox.confirm(
      I18n.t(`private_message_info.${messageKey}`, {
        name: this.attrs.user.username
      }),
      confirmed => {
        if (confirmed) {
          this.sendWidgetAction("removeAllowedUser", this.attrs.user);
        }
      }
    );
  }
});

createWidget("pm-map-user", {
  tagName: "div.user",

  html(attrs) {
    const user = attrs.user;
    const avatar = avatarFor("small", {
      template: user.avatar_template,
      username: user.username
    });
    const link = h("a", { attributes: { href: user.get("path") } }, [
      avatar,
      " ",
      user.username
    ]);
    const result = [link];
    const isCurrentUser = attrs.canRemoveSelfId === user.get("id");

    if (attrs.canRemoveAllowedUsers || isCurrentUser) {
      result.push(" ");
      result.push(this.attach("pm-remove-link", { user, isCurrentUser }));
    }

    return result;
  }
});

export default createWidget("private-message-map", {
  tagName: "section.information.private-message-map",

  html(attrs) {
    const participants = [];

    if (attrs.allowedGroups.length) {
      participants.push(
        attrs.allowedGroups.map(group => {
          return this.attach("pm-map-user-group", {
            group,
            canRemoveAllowedUsers: attrs.canRemoveAllowedUsers
          });
        })
      );
    }

    const allowedUsersLength = attrs.allowedUsers.length;

    if (allowedUsersLength) {
      participants.push(
        attrs.allowedUsers.map(au => {
          return this.attach("pm-map-user", {
            user: au,
            canRemoveAllowedUsers: attrs.canRemoveAllowedUsers,
            canRemoveSelfId: attrs.canRemoveSelfId
          });
        })
      );
    }

    const result = [
      h("h3", [
        iconNode("envelope"),
        " ",
        I18n.t("private_message_info.title")
      ]),
      h("div.participants.clearfix", participants)
    ];

    if (attrs.canInvite) {
      result.push(
        h(
          "div.controls",
          this.attach("button", {
            action: "showInvite",
            label: "private_message_info.invite",
            className: "btn"
          })
        )
      );
    }

    return result;
  }
});
