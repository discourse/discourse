import { applyDecorators, createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";

createWidget("admin-menu-button", {
  tagName: "li",

  buildClasses(attrs) {
    return attrs.className;
  },

  html(attrs) {
    let className;
    if (attrs.buttonClass) {
      className = attrs.buttonClass;
    }

    return this.attach("button", {
      className,
      action: attrs.action,
      url: attrs.url,
      icon: attrs.icon,
      label: attrs.fullLabel || `topic.${attrs.label}`,
      secondaryAction: "hideAdminMenu",
    });
  },
});

createWidget("topic-admin-menu-button", {
  tagName: "span.topic-admin-menu-button",
  buildKey: () => "topic-admin-menu-button",

  defaultState() {
    return { expanded: false, position: null };
  },

  html(attrs, state) {
    const result = [];

    const menu = this.attach("topic-admin-menu", {
      position: state.position,
      topic: attrs.topic,
      openUpwards: attrs.openUpwards,
      rightSide: !this.site.mobileView && attrs.rightSide,
      actionButtons: [],
    });

    // We don't show the button when expanded on the right side on desktop
    if (
      menu.attrs.actionButtons.length &&
      (!(attrs.rightSide && state.expanded) || this.site.mobileView)
    ) {
      result.push(
        this.attach("button", {
          className:
            "btn-default popup-menu-button toggle-admin-menu" +
            (attrs.addKeyboardTargetClass ? " keyboard-target-admin-menu" : ""),
          title: "topic_admin_menu",
          icon: "wrench",
          action: "showAdminMenu",
          sendActionEvent: true,
        })
      );
    }

    if (state.expanded) {
      result.push(menu);
    }

    return result;
  },

  hideAdminMenu() {
    this.state.expanded = false;
    this.state.position = null;
  },

  showAdminMenu(e) {
    this.state.expanded = true;
    let button;

    if (e === undefined) {
      button = document.querySelector(".keyboard-target-admin-menu");
    } else {
      button = e.target.closest("button");
    }

    const position = { top: button.offsetTop, left: button.offsetLeft };
    const spacing = 3;
    const menuWidth = 212;

    const rtl = document.documentElement.classList.contains("html.rtl");
    const buttonDOMRect = button.getBoundingClientRect();
    position.outerHeight = buttonDOMRect.height;

    if (this.attrs.openUpwards) {
      if (rtl) {
        position.left -= buttonDOMRect.width + spacing;
      } else {
        position.left += buttonDOMRect.width + spacing;
      }
    } else {
      if (rtl) {
        if (buttonDOMRect.left < menuWidth) {
          position.left += 0;
        } else {
          position.left -= menuWidth - buttonDOMRect.width;
        }
      } else {
        const offsetRight = window.innerWidth - buttonDOMRect.right;

        if (offsetRight < menuWidth) {
          position.left -= menuWidth - buttonDOMRect.width;
        }
      }

      position.top += buttonDOMRect.height + spacing;
    }

    this.state.position = position;
  },

  didRenderWidget() {
    let menuButtons = document.querySelectorAll(
      ".topic-admin-popup-menu button"
    );

    if (menuButtons && menuButtons[0]) {
      menuButtons[0].focus();
    }
  },

  topicToggleActions() {
    this.state.expanded ? this.hideAdminMenu() : this.showAdminMenu();
  },
});

export default createWidget("topic-admin-menu", {
  tagName: "div.popup-menu.topic-admin-popup-menu",

  buildClasses(attrs) {
    if (attrs.rightSide) {
      return "right-side";
    }
  },

  init(attrs) {
    const topic = attrs.topic;
    const details = topic.get("details");
    const isPrivateMessage = topic.get("isPrivateMessage");
    const featured = topic.get("pinned_at") || topic.get("isBanner");
    const visible = topic.get("visible");

    // Admin actions
    if (
      this.get("currentUser.canManageTopic") ||
      details.can_split_merge_topic
    ) {
      this.addActionButton({
        className: "topic-admin-multi-select",
        buttonClass: "popup-menu-btn",
        action: "toggleMultiSelect",
        icon: "tasks",
        label: "actions.multi_select",
        button_group: "topic",
      });
    }

    if (
      this.get("currentUser.canManageTopic") ||
      details.get("can_moderate_category")
    ) {
      if (details.get("can_delete")) {
        this.addActionButton({
          className: "topic-admin-delete",
          buttonClass: "popup-menu-btn-danger",
          action: "deleteTopic",
          icon: "far-trash-alt",
          label: "actions.delete",
          button_group: "topic",
        });
      }

      if (topic.get("deleted") && details.get("can_recover")) {
        this.addActionButton({
          className: "topic-admin-recover",
          buttonClass: "popup-menu-btn",
          action: "recoverTopic",
          icon: "undo",
          label: "actions.recover",
          button_group: "topic",
        });
      }
    }

    if (this.currentUser && details.get("can_close_topic")) {
      if (topic.get("closed")) {
        this.addActionButton({
          className: "topic-admin-open",
          buttonClass: "popup-menu-btn",
          action: "toggleClosed",
          icon: "unlock",
          label: "actions.open",
          button_group: "topic",
        });
      } else {
        this.addActionButton({
          className: "topic-admin-close",
          buttonClass: "popup-menu-btn",
          action: "toggleClosed",
          icon: "lock",
          label: "actions.close",
          button_group: "topic",
        });
      }
    }

    if (this.get("currentUser.canManageTopic")) {
      this.addActionButton({
        className: "admin-topic-timer-update",
        buttonClass: "popup-menu-btn",
        action: "showTopicTimerModal",
        icon: "far-clock",
        label: "actions.timed_update",
        button_group: "time",
      });
    }

    if (
      details.get("can_pin_unpin_topic") &&
      !isPrivateMessage &&
      (topic.get("visible") || featured)
    ) {
      this.addActionButton({
        className: "topic-admin-pin",
        buttonClass: "popup-menu-btn",
        action: "showFeatureTopic",
        icon: "thumbtack",
        label: featured ? "actions.unpin" : "actions.pin",
        button_group: "topic",
      });
    }

    if (this.get("currentUser.canManageTopic")) {
      if (this.currentUser.get("staff")) {
        this.addActionButton({
          className: "topic-admin-change-timestamp",
          buttonClass: "popup-menu-btn",
          action: "showChangeTimestamp",
          icon: "calendar-alt",
          label: "change_timestamp.title",
          button_group: "time",
        });
      }

      this.addActionButton({
        className: "topic-admin-reset-bump-date",
        buttonClass: "popup-menu-btn",
        action: "resetBumpDate",
        icon: "anchor",
        label: "actions.reset_bump_date",
        button_group: "time",
      });
    }

    if (this.currentUser && details.get("can_archive_topic")) {
      if (!isPrivateMessage) {
        this.addActionButton({
          className: "topic-admin-archive",
          buttonClass: "popup-menu-btn",
          action: "toggleArchived",
          icon: "folder",
          label: topic.get("archived")
            ? "actions.unarchive"
            : "actions.archive",
          button_group: "topic",
        });
      }
    }

    if (details.get("can_toggle_topic_visibility")) {
      this.addActionButton({
        className: "topic-admin-visible",
        buttonClass: "popup-menu-btn",
        action: "toggleVisibility",
        icon: visible ? "far-eye-slash" : "far-eye",
        label: visible ? "actions.invisible" : "actions.visible",
        button_group: "topic",
      });
    }

    if (this.get("currentUser.canManageTopic")) {
      if (details.get("can_convert_topic")) {
        this.addActionButton({
          className: "topic-admin-convert",
          buttonClass: "popup-menu-btn",
          action: isPrivateMessage
            ? "convertToPublicTopic"
            : "convertToPrivateMessage",
          icon: isPrivateMessage ? "comment" : "envelope",
          label: isPrivateMessage
            ? "actions.make_public"
            : "actions.make_private",
          button_group: "topic",
        });
      }

      this.addActionButton({
        className: "topic-admin-slow-mode",
        buttonClass: "popup-menu-btn",
        action: "showTopicSlowModeUpdate",
        icon: "hourglass-start",
        label: "actions.slow_mode",
        button_group: "time",
      });

      if (this.currentUser.get("staff")) {
        this.addActionButton({
          icon: "list",
          buttonClass: "popup-menu-btn",
          fullLabel: "review.moderation_history",
          url: `/review?topic_id=${topic.id}&status=all`,
        });
      }
    }
  },

  buildAttributes(attrs) {
    let { top, left, outerHeight } = attrs.position;
    const position = this.site.mobileView ? "fixed" : "absolute";

    if (attrs.rightSide) {
      return;
    }

    if (attrs.openUpwards) {
      const documentHeight = $(document).height();
      const mainHeight = $(".ember-application").height();
      let bottom =
        documentHeight - top - 70 - $(".ember-application").offset().top;

      if (documentHeight > mainHeight) {
        bottom = bottom - (documentHeight - mainHeight) - outerHeight;
      }

      if (this.site.mobileView) {
        bottom = 50;
        left = 0;
      }

      return {
        style: `position: ${position}; bottom: ${bottom}px; left: ${left}px;`,
      };
    } else {
      return {
        style: `position: ${position}; top: ${top}px; left: ${left}px;`,
      };
    }
  },

  addActionButton(button) {
    this.attrs.actionButtons.push(button);
  },

  html(attrs) {
    const extraButtons = applyDecorators(
      this,
      "adminMenuButtons",
      this.attrs,
      this.state
    );

    const actionButtons = attrs.actionButtons
      .concat(extraButtons)
      .filter(Boolean);

    const buttonMap = actionButtons.reduce(
      (prev, current) =>
        prev.set(current.button_group, [
          ...(prev.get(current.button_group) || []),
          current,
        ]),
      new Map()
    );

    let combinedButtonLists = [];

    for (const [group, buttons] of buttonMap.entries()) {
      let buttonList = [];
      buttons.forEach((button) => {
        buttonList.push(this.attach("admin-menu-button", button));
      });
      combinedButtonLists.push(h(`ul.topic-admin-menu-${group}`, buttonList));
    }

    return h("ul", combinedButtonLists);
  },

  clickOutside() {
    this.sendWidgetAction("hideAdminMenu");
  },
});
