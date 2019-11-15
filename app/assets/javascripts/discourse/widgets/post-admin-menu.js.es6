import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { ButtonClass } from "discourse/widgets/button";

createWidget(
  "post-admin-menu-button",
  jQuery.extend(ButtonClass, { tagName: "li.btn" })
);

export function buildManageButtons(attrs, currentUser, siteSettings) {
  if (!currentUser) {
    return [];
  }

  let contents = [];
  if (currentUser.staff) {
    contents.push({
      icon: "list",
      className: "btn-default",
      label: "review.moderation_history",
      url: `/review?topic_id=${attrs.topicId}&status=all`
    });
  }

  if (!attrs.isWhisper && currentUser.staff) {
    const buttonAtts = {
      action: "togglePostType",
      icon: "shield-alt",
      className: "btn-default toggle-post-type"
    };

    if (attrs.isModeratorAction) {
      buttonAtts.label = "post.controls.revert_to_regular";
    } else {
      buttonAtts.label = "post.controls.convert_to_moderator";
    }
    contents.push(buttonAtts);
  }

  if (currentUser.staff) {
    if (attrs.noticeType) {
      contents.push({
        icon: "user-shield",
        label: "post.controls.remove_post_notice",
        action: "removeNotice",
        className: "btn-default remove-notice"
      });
    } else {
      contents.push({
        icon: "user-shield",
        label: "post.controls.add_post_notice",
        action: "addNotice",
        className: "btn-default add-notice"
      });
    }
  }

  if (attrs.canManage && attrs.hidden) {
    contents.push({
      icon: "far-eye",
      label: "post.controls.unhide",
      action: "unhidePost",
      className: "btn-default unhide-post"
    });
  }

  if (currentUser.admin) {
    contents.push({
      icon: "user",
      label: "post.controls.change_owner",
      action: "changePostOwner",
      className: "btn-default change-owner"
    });
  }

  if (currentUser.staff) {
    if (siteSettings.enable_badges) {
      contents.push({
        icon: "certificate",
        label: "post.controls.grant_badge",
        action: "grantBadge",
        className: "btn-default grant-badge"
      });
    }

    if (attrs.locked) {
      contents.push({
        icon: "unlock",
        label: "post.controls.unlock_post",
        action: "unlockPost",
        title: "post.controls.unlock_post_description",
        className: "btn-default unlock-post"
      });
    } else {
      contents.push({
        icon: "lock",
        label: "post.controls.lock_post",
        action: "lockPost",
        title: "post.controls.lock_post_description",
        className: "btn-default lock-post"
      });
    }
  }

  if (attrs.canManage || attrs.canWiki) {
    if (attrs.wiki) {
      contents.push({
        action: "toggleWiki",
        label: "post.controls.unwiki",
        icon: "far-edit",
        className: "btn-default wiki wikied"
      });
    } else {
      contents.push({
        action: "toggleWiki",
        label: "post.controls.wiki",
        icon: "far-edit",
        className: "btn-default wiki"
      });
    }
  }

  if (attrs.canManage) {
    contents.push({
      icon: "cog",
      label: "post.controls.rebake",
      action: "rebakePost",
      className: "btn-default rebuild-html"
    });
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
        b.secondaryAction = "closeAdminMenu";
        contents.push(this.attach("post-admin-menu-button", b));
      }
    );

    return contents;
  },

  clickOutside() {
    this.sendWidgetAction("closeAdminMenu");
  }
});
