import { ButtonClass } from "discourse/widgets/button";
import { createWidget } from "discourse/widgets/widget";
import { h } from "@discourse/virtual-dom";

createWidget(
  "post-admin-menu-button",
  Object.assign(ButtonClass, { tagName: "li.btn" })
);

createWidget("post-admin-menu-button", {
  tagName: "li",

  html(attrs) {
    return this.attach("button", {
      className: attrs.className,
      action: attrs.action,
      url: attrs.url,
      icon: attrs.icon,
      label: attrs.label,
      secondaryAction: attrs.secondaryAction,
    });
  },
});

export function buildManageButtons(attrs, currentUser, siteSettings) {
  if (!currentUser) {
    return [];
  }

  let contents = [];
  if (currentUser.staff) {
    contents.push({
      icon: "list",
      className: "popup-menu-button moderation-history",
      label: "review.moderation_history",
      url: `/review?topic_id=${attrs.topicId}&status=all`,
    });
  }

  if (attrs.canPermanentlyDelete) {
    contents.push({
      icon: "trash-alt",
      className: "popup-menu-button permanently-delete",
      label: "post.controls.permanently_delete",
      action: "permanentlyDeletePost",
    });
  }

  if (!attrs.isWhisper && currentUser.staff) {
    const buttonAtts = {
      action: "togglePostType",
      icon: "shield-alt",
      className: "popup-menu-button toggle-post-type",
    };

    if (attrs.isModeratorAction) {
      buttonAtts.label = "post.controls.revert_to_regular";
    } else {
      buttonAtts.label = "post.controls.convert_to_moderator";
    }
    contents.push(buttonAtts);
  }

  if (attrs.canEditStaffNotes) {
    contents.push({
      icon: "user-shield",
      label: attrs.notice
        ? "post.controls.change_post_notice"
        : "post.controls.add_post_notice",
      action: "changeNotice",
      className: attrs.notice
        ? "popup-menu-button change-notice"
        : "popup-menu-button add-notice",
    });
  }

  if (currentUser.staff && attrs.hidden) {
    contents.push({
      icon: "far-eye",
      label: "post.controls.unhide",
      action: "unhidePost",
      className: "popup-menu-button unhide-post",
    });
  }

  if (
    currentUser.admin ||
    (siteSettings.moderators_change_post_ownership && currentUser.staff)
  ) {
    contents.push({
      icon: "user",
      label: "post.controls.change_owner",
      action: "changePostOwner",
      className: "popup-menu-button change-owner",
    });
  }

  if (attrs.user_id && currentUser.staff) {
    if (siteSettings.enable_badges) {
      contents.push({
        icon: "certificate",
        label: "post.controls.grant_badge",
        action: "grantBadge",
        className: "popup-menu-button grant-badge",
      });
    }

    if (attrs.locked) {
      contents.push({
        icon: "unlock",
        label: "post.controls.unlock_post",
        action: "unlockPost",
        title: "post.controls.unlock_post_description",
        className: "popup-menu-button unlock-post",
      });
    } else {
      contents.push({
        icon: "lock",
        label: "post.controls.lock_post",
        action: "lockPost",
        title: "post.controls.lock_post_description",
        className: "popup-menu-button lock-post",
      });
    }
  }

  if (attrs.canManage || attrs.canWiki) {
    if (attrs.wiki) {
      contents.push({
        action: "toggleWiki",
        label: "post.controls.unwiki",
        icon: "far-edit",
        className: "popup-menu-button wiki wikied",
      });
    } else {
      contents.push({
        action: "toggleWiki",
        label: "post.controls.wiki",
        icon: "far-edit",
        className: "popup-menu-button wiki",
      });
    }
  }

  if (attrs.canPublishPage) {
    contents.push({
      icon: "file",
      label: "post.controls.publish_page",
      action: "showPagePublish",
      className: "popup-menu-button publish-page",
    });
  }

  if (attrs.canManage) {
    contents.push({
      icon: "sync-alt",
      label: "post.controls.rebake",
      action: "rebakePost",
      className: "popup-menu-button rebuild-html",
    });
  }

  return contents;
}

export default createWidget("post-admin-menu", {
  tagName: "div.post-admin-menu.popup-menu",

  html() {
    const contents = [];

    buildManageButtons(this.attrs, this.currentUser, this.siteSettings).forEach(
      (b) => {
        b.secondaryAction = "closeAdminMenu";
        contents.push(this.attach("post-admin-menu-button", b));
      }
    );

    return h("ul", contents);
  },

  clickOutside() {
    this.sendWidgetAction("closeAdminMenu");
  },
});
