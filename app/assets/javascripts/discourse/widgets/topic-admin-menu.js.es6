import { createWidget, applyDecorators } from "discourse/widgets/widget";
import { h } from "virtual-dom";

createWidget("admin-menu-button", {
  html(attrs) {
    let className = "btn";
    if (attrs.buttonClass) {
      className += " " + attrs.buttonClass;
    }

    return h(
      "li",
      { className: attrs.className },
      this.attach("button", {
        className,
        action: attrs.action,
        icon: attrs.icon,
        label: attrs.fullLabel || `topic.${attrs.label}`,
        secondaryAction: "hideAdminMenu"
      })
    );
  }
});

createWidget("topic-admin-menu-button", {
  tagName: "span",
  buildKey: () => `topic-admin-menu-button`,

  defaultState() {
    return { expanded: false, position: null };
  },

  html(attrs, state) {
    if (!this.currentUser || !this.currentUser.get("canManageTopic")) {
      return;
    }

    const result = [];

    // We don't show the button when expanded on the right side
    if (!(attrs.rightSide && state.expanded)) {
      result.push(
        this.attach("button", {
          className:
            "btn-default toggle-admin-menu" +
            (attrs.fixed ? " show-topic-admin" : ""),
          title: "topic_admin_menu",
          icon: "wrench",
          action: "showAdminMenu",
          sendActionEvent: true
        })
      );
    }

    if (state.expanded) {
      result.push(
        this.attach("topic-admin-menu", {
          position: state.position,
          fixed: attrs.fixed,
          topic: attrs.topic,
          openUpwards: attrs.openUpwards,
          rightSide: attrs.rightSide
        })
      );
    }

    return result;
  },

  hideAdminMenu() {
    this.state.expanded = false;
    this.state.position = null;
  },

  showAdminMenu(e) {
    this.state.expanded = true;

    const $button = $(e.target).closest("button");
    const position = $button.position();
    const rtl = $("html").hasClass("rtl");
    position.left = position.left;
    position.outerHeight = $button.outerHeight();

    if (rtl) {
      position.left -= 217 - $button.outerWidth();
    }

    if (this.attrs.fixed) {
      position.left += $button.width() - 203;
    }
    this.state.position = position;
    this.sendWidgetAction("hideMultiSelect");
  }
});

export default createWidget("topic-admin-menu", {
  tagName: "div.popup-menu.topic-admin-popup-menu",

  buildClasses(attrs) {
    if (attrs.rightSide) {
      return "right-side";
    }
  },

  buildAttributes(attrs) {
    let { top, left, outerHeight } = attrs.position;
    const position = attrs.fixed ? "fixed" : "absolute";

    if (attrs.rightSide) {
      return;
    }

    if (attrs.openUpwards) {
      const documentHeight = $(document).height();
      const mainHeight = $("#main").height();
      let bottom = documentHeight - top - 70 - $("#main").offset().top;

      if (documentHeight > mainHeight) {
        bottom = bottom - (documentHeight - mainHeight) - outerHeight;
      }

      return {
        style: `position: ${position}; bottom: ${bottom}px; left: ${left}px;`
      };
    } else {
      return {
        style: `position: ${position}; top: ${top}px; left: ${left}px;`
      };
    }
  },

  html(attrs) {
    const buttons = [];
    buttons.push({
      className: "topic-admin-multi-select",
      buttonClass: "btn-default",
      action: "toggleMultiSelect",
      icon: "tasks",
      label: "actions.multi_select"
    });

    const topic = attrs.topic;
    const details = topic.get("details");

    if (details.get("can_delete")) {
      buttons.push({
        className: "topic-admin-delete",
        buttonClass: "btn-danger",
        action: "deleteTopic",
        icon: "trash-o",
        label: "actions.delete"
      });
    }

    if (topic.get("deleted") && details.get("can_recover")) {
      buttons.push({
        className: "topic-admin-recover",
        buttonClass: "btn-default",
        action: "recoverTopic",
        icon: "undo",
        label: "actions.recover"
      });
    }

    if (topic.get("closed")) {
      buttons.push({
        className: "topic-admin-open",
        buttonClass: "btn-default",
        action: "toggleClosed",
        icon: "unlock",
        label: "actions.open"
      });
    } else {
      buttons.push({
        className: "topic-admin-close",
        buttonClass: "btn-default",
        action: "toggleClosed",
        icon: "lock",
        label: "actions.close"
      });
    }

    buttons.push({
      className: "topic-admin-status-update",
      buttonClass: "btn-default",
      action: "showTopicStatusUpdate",
      icon: "clock-o",
      label: "actions.timed_update"
    });

    const isPrivateMessage = topic.get("isPrivateMessage");

    const featured = topic.get("pinned_at") || topic.get("isBanner");
    if (!isPrivateMessage && (topic.get("visible") || featured)) {
      buttons.push({
        className: "topic-admin-pin",
        buttonClass: "btn-default",
        action: "showFeatureTopic",
        icon: "thumbtack",
        label: featured ? "actions.unpin" : "actions.pin"
      });
    }

    if (this.currentUser.admin) {
      buttons.push({
        className: "topic-admin-change-timestamp",
        buttonClass: "btn-default",
        action: "showChangeTimestamp",
        icon: "calendar",
        label: "change_timestamp.title"
      });
    }

    buttons.push({
      className: "topic-admin-reset-bump-date",
      buttonClass: "btn-default",
      action: "resetBumpDate",
      icon: "anchor",
      label: "actions.reset_bump_date"
    });

    if (!isPrivateMessage) {
      buttons.push({
        className: "topic-admin-archive",
        buttonClass: "btn-default",
        action: "toggleArchived",
        icon: "folder",
        label: topic.get("archived") ? "actions.unarchive" : "actions.archive"
      });
    }

    const visible = topic.get("visible");
    buttons.push({
      className: "topic-admin-visible",
      buttonClass: "btn-default",
      action: "toggleVisibility",
      icon: visible ? "eye-slash" : "eye",
      label: visible ? "actions.invisible" : "actions.visible"
    });

    if (details.get("can_convert_topic")) {
      buttons.push({
        className: "topic-admin-convert",
        buttonClass: "btn-default",
        action: isPrivateMessage
          ? "convertToPublicTopic"
          : "convertToPrivateMessage",
        icon: isPrivateMessage ? "comment" : "envelope",
        label: isPrivateMessage ? "actions.make_public" : "actions.make_private"
      });
    }

    if (this.currentUser.get("staff")) {
      buttons.push({
        action: "showModerationHistory",
        buttonClass: "btn-default",
        icon: "list",
        fullLabel: "admin.flags.moderation_history"
      });
    }

    const extraButtons = applyDecorators(
      this,
      "adminMenuButtons",
      this.attrs,
      this.state
    );

    return [
      h("h3", I18n.t("admin_title")),
      h(
        "ul",
        buttons
          .concat(extraButtons)
          .map(b => this.attach("admin-menu-button", b))
      )
    ];
  },

  clickOutside() {
    this.sendWidgetAction("hideAdminMenu");
  }
});
