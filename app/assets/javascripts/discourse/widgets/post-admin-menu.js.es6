import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { ButtonClass } from "discourse/widgets/button";

createWidget(
  "post-admin-menu-button",
  jQuery.extend(ButtonClass, {
    tagName: "li.btn",
    click() {
      this.sendWidgetAction("closeAdminMenu");
      return this.sendWidgetAction(this.attrs.action);
    }
  })
);

export function buildManageButtons(attrs, currentUser, siteSettings) {
  if (!currentUser) {
    return [];
  }

  let contents = [];
  if (currentUser.staff) {
    contents.push({
      icon: "list",
      label: "admin.flags.moderation_history",
      action: "showModerationHistory"
    });
  }

  if (!attrs.isWhisper && currentUser.staff) {
    const buttonAtts = {
      action: "togglePostType",
      icon: "shield",
      className: "toggle-post-type"
    };

    if (attrs.isModeratorAction) {
      buttonAtts.label = "post.controls.revert_to_regular";
    } else {
      buttonAtts.label = "post.controls.convert_to_moderator";
    }
    contents.push(buttonAtts);
  }

  if (attrs.canManage) {
    contents.push({
      icon: "cog",
      label: "post.controls.rebake",
      action: "rebakePost",
      className: "rebuild-html"
    });

    if (attrs.hidden) {
      contents.push({
        icon: "eye",
        label: "post.controls.unhide",
        action: "unhidePost",
        className: "unhide-post"
      });
    }
  }

  if (currentUser.admin) {
    contents.push({
      icon: "user",
      label: "post.controls.change_owner",
      action: "changePostOwner",
      className: "change-owner"
    });
  }

  if (currentUser.staff) {
    if (siteSettings.enable_badges) {
      contents.push({
        icon: "certificate",
        label: "post.controls.grant_badge",
        action: "grantBadge",
        className: "grant-badge"
      });
    }

    const action = attrs.locked ? "unlock" : "lock";
    contents.push({
      icon: action,
      label: `post.controls.${action}_post`,
      action: `${action}Post`,
      title: `post.controls.${action}_post_description`,
      className: `${action}-post`
    });
  }

  if (attrs.canManage || attrs.canWiki) {
    if (attrs.wiki) {
      contents.push({
        action: "toggleWiki",
        label: "post.controls.unwiki",
        icon: "pencil-square-o",
        className: "wiki wikied"
      });
    } else {
      contents.push({
        action: "toggleWiki",
        label: "post.controls.wiki",
        icon: "pencil-square-o",
        className: "wiki"
      });
    }
  }

  return contents;
}

export default createWidget("post-admin-menu", {
  tagName: "div.post-admin-menu.popup-menu",

  html() {
    const contents = [];
    contents.push(h("h3", I18n.t("admin_title")));

    buildManageButtons(this.attrs, this.currentUser, this.siteSettings).forEach(
      b => {
        contents.push(this.attach("post-admin-menu-button", b));
      }
    );

    return contents;
  },

  clickOutside() {
    this.sendWidgetAction("closeAdminMenu");
  }
});
