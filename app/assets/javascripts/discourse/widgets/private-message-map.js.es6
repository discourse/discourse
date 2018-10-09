import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { avatarFor, avatarImg } from "discourse/widgets/post";
import hbs from "discourse/widgets/hbs-compiler";

createWidget("pm-remove-group-link", {
  tagName: "a.remove-invited.no-text.btn-icon.btn",
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
    <a href={{transformed.href}} class="group-link">
      {{d-icon "users"}}
      <span class="group-name">{{attrs.group.name}}</span>
    </a>
    {{#if attrs.isEditing}}
    {{#if attrs.canRemoveAllowedUsers}}
      {{attach widget="pm-remove-group-link" attrs=attrs.group}}
    {{/if}}
    {{/if}}
  `
});

createWidget("pm-remove-link", {
  tagName: "a.remove-invited.no-text.btn-icon.btn",
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
    const username = h("span.username", user.username);

    let link;

    if (this.site && this.site.mobileView) {
      const avatar = avatarImg("tiny", {
        template: user.avatar_template,
        username: user.username
      });
      link = h("a", { attributes: { href: user.get("path") } }, [
        avatar,
        username
      ]);
    } else {
      const avatar = avatarFor("tiny", {
        template: user.avatar_template,
        username: user.username
      });

      link = h(
        "a",
        { attributes: { class: "user-link", href: user.get("path") } },
        [avatar, username]
      );
    }

    const result = [link];
    const isCurrentUser = attrs.canRemoveSelfId === user.get("id");

    if (attrs.isEditing && (attrs.canRemoveAllowedUsers || isCurrentUser)) {
      result.push(this.attach("pm-remove-link", { user, isCurrentUser }));
    }

    return result;
  }
});

export default createWidget("private-message-map", {
  tagName: "section.information.private-message-map",

  buildKey: attrs => `private-message-map-${attrs.id}`,

  defaultState() {
    return { isEditing: false };
  },

  html(attrs) {
    const participants = [];

    if (attrs.allowedGroups.length) {
      participants.push(
        attrs.allowedGroups.map(group => {
          return this.attach("pm-map-user-group", {
            group,
            canRemoveAllowedUsers: attrs.canRemoveAllowedUsers,
            isEditing: this.state.isEditing
          });
        })
      );
    }

    if (attrs.allowedUsers.length) {
      participants.push(
        attrs.allowedUsers.map(au => {
          return this.attach("pm-map-user", {
            user: au,
            canRemoveAllowedUsers: attrs.canRemoveAllowedUsers,
            canRemoveSelfId: attrs.canRemoveSelfId,
            isEditing: this.state.isEditing
          });
        })
      );
    }

    let hideNamesClass = "";
    if (
      !this.state.isEditing &&
      this.site.mobileView &&
      Ember.makeArray(participants[0]).length > 4
    ) {
      hideNamesClass = ".hide-names";
    }

    const result = [h(`div.participants${hideNamesClass}`, participants)];

    const controls = [
      this.attach("button", {
        action: "toggleEditing",
        label: "private_message_info.edit",
        className: "btn btn-default add-remove-participant-btn"
      })
    ];

    if (attrs.canInvite && this.state.isEditing) {
      controls.push(
        this.attach("button", {
          action: "showInvite",
          icon: "plus",
          className: "btn.no-text.btn-icon"
        })
      );
    }

    result.push(h("div.controls", controls));

    return result;
  },

  toggleEditing() {
    this.state.isEditing = !this.state.isEditing;
  }
});
