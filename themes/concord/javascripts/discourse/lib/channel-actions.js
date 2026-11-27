import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withoutPrefix } from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import ActionMenu from "../components/action-menu.gjs";
import ChannelPrivacyModal from "../components/modal/channel-privacy.gjs";
import RenameModal from "../components/modal/rename.gjs";

const CATEGORY_LEVELS = { muted: 0, regular: 1, watching: 3 };

const t = (key, opts) => i18n(themePrefix(`channel_menu.${key}`), opts);

/**
 * What the inline menus on headings and channels offer. Each kind of channel
 * is backed by something different, so most items differ by kind, and each
 * shows only when the user may do it.
 *
 * An item is `{ label, icon, action, checked?, danger? }`, `{ heading }` to
 * label the items after it, or `{ divider: true }`. One with `items` instead
 * of an action opens them as a submenu.
 */
export default class ChannelActions {
  @service currentUser;
  @service dialog;
  @service menu;
  @service modal;
  @service router;
  @service toasts;

  constructor(owner, sidebarSections, privacy, creator) {
    setOwner(this, owner);
    this.sidebarSections = sidebarSections;
    this.privacy = privacy;
    this.creator = creator;
    this.chat = owner.lookup("service:chat");
    this.chatApi = owner.lookup("service:chat-api");
    this.chatChannelsManager = owner.lookup("service:chat-channels-manager");
    this.voiceRooms = owner.lookup("service:live-rooms");
  }

  /** Puts the `…` button on a channel row. */
  decorate(link) {
    if (!this.currentUser) {
      return link;
    }

    link.hoverType = "icon";
    link.hoverValue = "ellipsis";
    link.hoverTitle = t("title");
    link.hoverAction = (event, onClose) => {
      event.preventDefault();
      event.stopPropagation();
      this.#show(event, this.channelItems(link), onClose);
    };

    return link;
  }

  /** Opens a channel's menu from somewhere other than its `…` button. */
  showChannelMenu(anchor, link) {
    this.#showAt(anchor, this.channelItems(link));
  }

  /** The `…` button on a section heading. */
  sectionAction(index) {
    if (!this.sidebarSections.canEdit) {
      return;
    }

    return {
      id: "sectionMenu",
      icon: "ellipsis",
      title: t("section_title"),
      action: (event) => this.#show(event, this.sectionItems(index)),
    };
  }

  sectionItems(index) {
    const sections = this.sidebarSections;
    const section = sections.sections[index];

    return [
      {
        label: t("rename_section"),
        icon: "pencil",
        action: () =>
          this.#rename(t("rename_section"), section.name, (name) =>
            sections.renameSection(index, name)
          ),
      },
      index > 0 && {
        label: t("move_up"),
        icon: "arrow-up",
        action: () => this.#run(() => sections.moveSection(index, -1)),
      },
      index < sections.sections.length - 1 && {
        label: t("move_down"),
        icon: "arrow-down",
        action: () => this.#run(() => sections.moveSection(index, 1)),
      },
      {
        label: t("delete_section"),
        icon: "trash-can",
        danger: true,
        action: () =>
          this.dialog.deleteConfirm({
            message: t("delete_section_confirm", { name: section.name }),
            didConfirm: () => this.#run(() => sections.deleteSection(index)),
          }),
      },
    ].filter(Boolean);
  }

  // Everyday actions first, then notifications, the section, and deleting last
  // on its own.
  channelItems(link) {
    const [type] = link.channelKey.split(":");

    if (type === "dm") {
      return this.#directMessageItems(link.channel);
    }

    const sections =
      {
        forum: () => this.#forumItems(link.category),
        text: () => this.#textItems(link.channel),
        voice: () => this.#voiceItems(link.room),
      }[type]?.() || {};

    return [
      sections.markRead,
      sections.rename,
      this.#privacyItem(link),
      {
        label: t("copy_link"),
        icon: "link",
        action: () => this.#copyLink(link),
      },
      ...(sections.notifications || []),
      ...this.#moveItems(link.channelKey),
      sections.delete && { divider: true },
      sections.delete,
    ].filter(Boolean);
  }

  #forumItems(category) {
    const level = category.notification_level;
    const items = {
      markRead: {
        label: t("mark_read"),
        icon: "eye",
        action: () => this.#run(() => this.#dismissCategory(category)),
      },
      notifications: [
        { heading: t("notifications") },
        ...[
          ["watching", "all_posts"],
          ["regular", "default"],
          ["muted", "mute"],
        ].map(([name, label]) => ({
          label: t(label),
          checked: level === CATEGORY_LEVELS[name],
          action: () =>
            this.#run(() => category.setNotification(CATEGORY_LEVELS[name])),
        })),
      ],
    };

    if (category.can_edit) {
      items.rename = {
        label: t("rename"),
        icon: "pencil",
        action: () =>
          this.#rename(t("rename"), category.name, (name) =>
            ajax(`/categories/${category.id}`, {
              type: "PUT",
              data: { name },
            }).then(() => category.set("name", name))
          ),
      };
      items.delete = {
        label: t("delete"),
        icon: "trash-can",
        danger: true,
        action: () =>
          this.#confirmDelete(category.name, async () => {
            await ajax(`/categories/${category.id}`, { type: "DELETE" });
            await this.sidebarSections.removeChannel(`forum:${category.id}`);
            this.#goHomeIfOn(category.url);
          }),
      };
    }

    return items;
  }

  // Unread state and notifications belong to a membership, which a channel
  // listed but never opened doesn't have yet.
  #textItems(channel) {
    const items = {};

    if (channel.currentUserMembership?.following) {
      items.markRead = this.#chatMarkRead(channel);
      items.notifications = this.#chatNotifications(channel);
    }

    if (this.currentUser.staff) {
      items.rename = {
        label: t("rename"),
        icon: "pencil",
        action: () =>
          this.#rename(t("rename"), channel.title, (name) =>
            this.chatApi
              .updateChannel(channel.id, { name })
              .then(() => (channel.title = name))
          ),
      };
      items.delete = {
        label: t("delete"),
        icon: "trash-can",
        danger: true,
        action: () =>
          this.#confirmDelete(channel.title, async () => {
            await this.chatApi.destroyChannel(channel.id);
            const wasOpen = this.chat.activeChannel?.id === channel.id;
            this.chatChannelsManager.remove(channel);
            await this.#deleteBackingCategory(channel);
            await this.sidebarSections.removeChannel(`text:${channel.id}`);
            if (wasOpen) {
              this.router.transitionTo("discovery.latest");
            }
          }),
      };
    }

    return items;
  }

  // Closing a DM takes it off the list until there's something new in it,
  // as chat's own menu does; there's nothing to leave.
  #directMessageItems(channel) {
    return [
      this.#chatMarkRead(channel),
      ...this.#chatNotifications(channel),
      { divider: true },
      {
        id: "close-dm",
        label: t("close_dm"),
        icon: "xmark",
        action: () =>
          this.#run(async () => {
            await this.chat.unfollowChannel(channel);
            this.chatChannelsManager.remove(channel);
            if (this.chat.activeChannel?.id === channel.id) {
              this.router.transitionTo("discovery.latest");
            }
          }),
      },
    ];
  }

  #privacyItem(link) {
    const privacy = this.privacy.forLink(link);

    if (!privacy) {
      return;
    }

    return {
      id: "privacy",
      label: t("privacy"),
      icon: "lock",
      action: () =>
        this.modal.show(ChannelPrivacyModal, {
          model: {
            privacy,
            name: link.sortName,
            groups: this.creator.groups,
          },
        }),
    };
  }

  #chatMarkRead(channel) {
    return {
      id: "mark-read",
      label: t("mark_read"),
      icon: "eye",
      action: () => this.#run(() => this.chatApi.markChannelAsRead(channel.id)),
    };
  }

  #chatNotifications(channel) {
    const membership = channel.currentUserMembership;

    return [
      { heading: t("notifications") },
      ...[
        ["always", "all_messages"],
        ["mention", "mentions_only"],
        ["never", "nothing"],
      ].map(([level, label]) => ({
        label: t(label),
        checked: !membership?.muted && membership?.notificationLevel === level,
        action: () =>
          this.#updateChatSettings(channel, {
            muted: false,
            notification_level: level,
          }),
      })),
      {
        label: t("mute"),
        checked: !!membership?.muted,
        action: () =>
          this.#updateChatSettings(channel, { muted: !membership?.muted }),
      },
    ];
  }

  #voiceItems(room) {
    if (!room.can_manage) {
      return {};
    }

    return {
      rename: {
        label: t("rename"),
        icon: "pencil",
        action: () =>
          this.#rename(t("rename"), room.name, (name) =>
            ajax(`/live/rooms/${room.id}`, {
              type: "PUT",
              data: { room: { name } },
            }).then((result) => this.voiceRooms.upsertRoom(result.room))
          ),
      },
      delete: {
        label: t("delete"),
        icon: "trash-can",
        danger: true,
        action: () =>
          this.#confirmDelete(room.name, async () => {
            const url = this.router.urlFor("live-room", room.slug);
            await ajax(`/live/rooms/${room.id}`, { type: "DELETE" });
            this.voiceRooms.handleDirectoryEvent({ type: "destroyed", room });
            await this.sidebarSections.removeChannel(`voice:${room.id}`);
            this.#goHomeIfOn(url);
          }),
      },
    };
  }

  #moveItems(key) {
    const sections = this.sidebarSections;

    if (!sections.canEdit) {
      return [];
    }

    const current = sections.sectionIndexOf(key);

    // A submenu, so the sections don't lengthen every channel's menu.
    return [
      { divider: true },
      {
        id: "move-to-section",
        label: t("move_to_section"),
        icon: "right-left",
        items: this.#sectionChoices(key, current),
      },
    ];
  }

  #sectionChoices(key, current) {
    const sections = this.sidebarSections;

    return [
      ...sections.sections.map((section, index) => ({
        label: section.name,
        checked: index === current,
        action: () => this.#run(() => sections.moveChannel(key, section.name)),
      })),
      {
        label: t("no_section"),
        checked: current === -1,
        action: () => this.#run(() => sections.moveChannel(key, null)),
      },
      // Moving into a section that doesn't exist yet creates it.
      {
        label: t("new_section"),
        icon: "plus",
        action: () =>
          this.#rename(
            t("new_section"),
            "",
            (name) => sections.moveChannel(key, name),
            t("create_section")
          ),
      },
    ];
  }

  #show(event, items, onClose) {
    this.#showAt(
      event.target.closest("a, button") || event.target,
      items,
      onClose
    );
  }

  #showAt(anchor, items, onClose) {
    this.menu.show(anchor, {
      identifier: "concord-channel-menu",
      component: ActionMenu,
      data: { items },
      placement: "right-start",
      modalForMobile: true,
      onClose,
    });
  }

  #copyLink(link) {
    const href = link.href && link.href !== "#" ? link.href : null;
    const url =
      href ||
      (link.route === "live-room" || link.room
        ? this.router.urlFor("live-room", link.room.slug)
        : this.router.urlFor(
            link.route,
            ...(link.models || (link.model ? [link.model] : []))
          ));

    clipboardCopy(new URL(url, window.location.origin).href);
    this.toasts.success({
      duration: "short",
      data: { message: t("link_copied") },
    });
  }

  // New topics and unread posts both, whichever "new" the user has set up.
  async #dismissCategory(category) {
    await ajax("/topics/reset-new", {
      type: "PUT",
      data: {
        category_id: category.id,
        dismiss_topics: true,
        dismiss_posts: true,
      },
    });
    await ajax("/topics/bulk", {
      type: "PUT",
      data: {
        filter: "unread",
        category_id: category.id,
        operation: { type: "dismiss_posts" },
      },
    });
  }

  #updateChatSettings(channel, settings) {
    return this.#run(async () => {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          channel.id,
          settings
        );
      const membership = channel.currentUserMembership;
      membership.muted = result.membership.muted;
      membership.notificationLevel = result.membership.notification_level;
    });
  }

  #rename(title, value, save, submitLabel) {
    this.modal.show(RenameModal, {
      model: { title, value, save, submitLabel },
    });
  }

  #confirmDelete(name, destroy) {
    this.dialog.deleteConfirm({
      message: t("delete_confirm", { name }),
      didConfirm: () => this.#run(destroy),
    });
  }

  // A channel made from the create modal has a category of its own, under the
  // chat container, that only exists to give it permissions; it goes with
  // the channel. Any other category is left alone.
  async #deleteBackingCategory(channel) {
    const category = Category.findById(channel.chatableId);
    const container = category?.parentCategory;

    if (container?.slug !== settings.chat_container_category) {
      return;
    }

    try {
      await ajax(`/categories/${category.id}`, { type: "DELETE" });
    } catch {
      // Something was posted in it after all; it stays, still hidden.
    }
  }

  // Compared without the subfolder, which the router's current URL leaves out.
  #goHomeIfOn(url) {
    if (this.router.currentURL?.startsWith(withoutPrefix(url))) {
      this.router.transitionTo("discovery.latest");
    }
  }

  async #run(fn) {
    try {
      await fn();
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
