import { tracked } from "@glimmer/tracking";
import { get } from "@ember/object";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { htmlSafe } from "@ember/template";
import { decorateUsername } from "discourse/helpers/decorate-username-selector";
import { avatarUrl } from "discourse/lib/avatar-utils";
import { bind } from "discourse/lib/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";
import ChatSidebarIndicators from "discourse/plugins/chat/discourse/components/chat-sidebar-indicators";
import {
  CHAT_PANEL,
  initSidebarState,
} from "discourse/plugins/chat/discourse/lib/init-sidebar-state";

const CHAT_STARRED_CHANNELS_SECTION = "chat-starred-channels";

function createChannelLink(BaseCustomSidebarSectionLink, options = {}) {
  const { showSuffix = true, enableHoverForPublicChannels = false } = options;

  return class extends BaseCustomSidebarSectionLink {
    route = "chat.channel";
    suffixType = "icon";
    hoverType = "icon";

    constructor({
      channel,
      chatService,
      currentUser,
      siteSettings,
      chatStateManager,
    }) {
      super(...arguments);
      this.channel = channel;
      this.chatService = chatService;
      this.siteSettings = siteSettings;
      this.currentUser = currentUser;
      this.chatStateManager = chatStateManager;

      if (this.isOneOnOneDM) {
        const user = this.channel.chatable.users?.[0];
        if (user?.username !== i18n("chat.deleted_chat_username")) {
          user.statusManager.trackStatus();
        }
      }
    }

    @bind
    willDestroy() {
      if (this.isOneOnOneDM) {
        this.channel.chatable.users?.[0]?.statusManager?.stopTrackingStatus();
      }
    }

    get isDM() {
      return this.channel.isDirectMessageChannel;
    }

    get isOneOnOneDM() {
      return this.isDM && this.channel.chatable.users.length === 1;
    }

    get name() {
      return this.isDM
        ? this.channel.slugifiedTitle
        : dasherize(this.channel.slugifiedTitle);
    }

    get classNames() {
      const classes = [];

      if (this.channel.currentUserMembership.muted) {
        classes.push("sidebar-section-link--muted");
      }

      if (
        this.channel.id === this.chatService.activeChannel?.id &&
        (this.chatStateManager.isDrawerExpanded ||
          this.chatStateManager.isFullPageActive)
      ) {
        classes.push("sidebar-section-link--active");
      }

      classes.push(`channel-${this.channel.id}`);

      return classes.join(" ");
    }

    get models() {
      return this.channel.routeModels;
    }

    get text() {
      if (this.isDM) {
        if (this.channel.chatable.group) {
          return this.channel.title;
        } else {
          const username = this.channel.escapedTitle.replaceAll("@", "");
          return htmlSafe(
            `${escapeExpression(username)}${decorateUsername(
              escapeExpression(username)
            )}`
          );
        }
      } else {
        return htmlSafe(emojiUnescape(this.channel.escapedTitle));
      }
    }

    get title() {
      if (this.isDM) {
        if (this.channel.chatable.group) {
          return i18n("chat.placeholder_channel", {
            channelName: this.channel.escapedTitle,
          });
        } else {
          return i18n("chat.placeholder_users", {
            commaSeparatedNames: this.channel.escapedTitle,
          });
        }
      } else {
        return this.channel.escapedDescription
          ? htmlSafe(this.channel.escapedDescription)
          : `${this.channel.escapedTitle} ${i18n("chat.title")}`;
      }
    }

    get prefixType() {
      if (this.isDM) {
        if (this.channel.emoji) {
          return "emoji";
        } else if (this.channel.chatable.group) {
          return "text";
        } else {
          return "image";
        }
      } else {
        return this.channel.emoji ? "emoji" : "icon";
      }
    }

    get prefixValue() {
      if (this.isDM) {
        if (this.channel.emoji) {
          return this.channel.emoji;
        } else if (this.channel.chatable.group) {
          return this.channel.membershipsCount;
        } else {
          return avatarUrl(
            this.channel.chatable.users[0].avatar_template,
            "tiny"
          );
        }
      } else {
        return this.channel.emoji ?? "d-chat";
      }
    }

    get prefixColor() {
      return this.isDM ? null : this.channel.chatable.color;
    }

    get prefixBadge() {
      return !this.isDM && this.channel.chatable.read_restricted ? "lock" : "";
    }

    get prefixCSSClass() {
      if (this.isDM) {
        const activeUsers = this.chatService.presenceChannel.users;
        const user = this.channel.chatable.users[0];

        if (
          !!activeUsers?.find((item) => get(item, "id") === user?.id) ||
          !!activeUsers?.find(
            (item) => get(item, "username") === user?.username
          )
        ) {
          return "active";
        }
      }
      return "";
    }

    get suffixComponent() {
      return ChatSidebarIndicators;
    }

    get suffixArgs() {
      if (this.isDM) {
        return {
          userStatus: this.isOneOnOneDM
            ? this.channel.chatable.users[0].get("status")
            : null,
          unreadCount: this.channel.tracking.unreadCount,
          unreadThreadsCount: this.channel.unreadThreadsCountSinceLastViewed,
          mentionCount: this.channel.tracking.mentionCount,
          watchedThreadsUnreadCount:
            this.channel.tracking.watchedThreadsUnreadCount,
          isDirectMessageChannel: true,
        };
      } else {
        return {
          unreadCount: this.channel.tracking.unreadCount,
          unreadThreadsCount:
            this.chatService.activeChannel?.id !== this.channel.id
              ? this.channel.unreadThreadsCountSinceLastViewed
              : 0,
          mentionCount: this.channel.tracking.mentionCount,
          watchedThreadsUnreadCount:
            this.channel.tracking.watchedThreadsUnreadCount,
          isDirectMessageChannel: false,
        };
      }
    }

    get suffixValue() {
      return showSuffix ? "" : "";
    }

    get suffixCSSClass() {
      return showSuffix ? "" : "";
    }

    get hoverValue() {
      if (this.isDM) {
        return "xmark";
      }
      return enableHoverForPublicChannels ? "" : "";
    }

    get hoverTitle() {
      return this.isDM ? i18n("chat.direct_messages.close") : "";
    }

    get hoverAction() {
      if (this.isDM) {
        return (event) => {
          event.stopPropagation();
          event.preventDefault();
          this.chatService.unfollowChannel(this.channel);
        };
      }
      return null;
    }
  };
}

export default {
  name: "chat-sidebar",
  initialize(container) {
    this.chatService = container.lookup("service:chat");

    if (!this.chatService.userCanChat) {
      return;
    }

    this.siteSettings = container.lookup("service:site-settings");
    this.currentUser = container.lookup("service:current-user");

    withPluginApi((api) => {
      const chatStateManager = container.lookup("service:chat-state-manager");

      api.addSidebarPanel(
        (BaseCustomSidebarPanel) =>
          class ChatSidebarPanel extends BaseCustomSidebarPanel {
            key = CHAT_PANEL;
            switchButtonLabel = i18n("sidebar.panels.chat.label");
            switchButtonIcon = "d-chat";

            get switchButtonDefaultUrl() {
              return chatStateManager.lastKnownChatURL || "/chat";
            }
          }
      );

      initSidebarState(api, api.getCurrentUser());
    });

    withPluginApi((api) => {
      const chatChannelsManager = container.lookup(
        "service:chat-channels-manager"
      );
      const chatStateManager = container.lookup("service:chat-state-manager");

      if (this.siteSettings.chat_search_enabled) {
        api.addSidebarSection(
          (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
            const SidebarChatSearchSectionLink = class extends BaseCustomSidebarSectionLink {
              route = "chat.search";
              text = i18n("chat.search.title");
              title = i18n("chat.search.title");
              name = "chat-search";
              prefixType = "icon";
              prefixValue = "magnifying-glass";
            };

            const SidebarChatSearchSection = class extends BaseCustomSidebarSection {
              hideSectionHeader = true;
              name = "chat-search";
              title = "";

              get links() {
                return [new SidebarChatSearchSectionLink()];
              }

              get text() {
                return null;
              }
            };

            return SidebarChatSearchSection;
          },
          CHAT_PANEL
        );
      }

      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          const SidebarChatMyThreadsSectionLink = class extends BaseCustomSidebarSectionLink {
            route = "chat.threads";
            text = i18n("chat.my_threads.title");
            title = i18n("chat.my_threads.title");
            name = "user-threads";
            prefixType = "icon";
            prefixValue = "discourse-threads";
            suffixType = "icon";

            constructor() {
              super(...arguments);

              if (container.isDestroyed) {
                return;
              }
            }

            get suffixValue() {
              return chatChannelsManager.allChannels.some(
                (channel) => channel.unreadThreadsCount > 0
              )
                ? "circle"
                : "";
            }

            get suffixCSSClass() {
              return chatChannelsManager.allChannels.some(
                (channel) => channel.tracking.watchedThreadsUnreadCount > 0
              )
                ? "urgent"
                : "unread";
            }
          };

          const SidebarChatMyThreadsSection = class extends BaseCustomSidebarSection {
            @service chatChannelsManager;

            // we only show `My Threads` link
            hideSectionHeader = true;

            name = "user-threads";

            // sidebar API doesn’t let you have undefined values
            // even if you don't show the section’s header
            title = "";

            get links() {
              return [new SidebarChatMyThreadsSectionLink()];
            }

            get text() {
              return null;
            }

            get displaySection() {
              return this.chatChannelsManager.shouldShowMyThreads;
            }
          };

          return SidebarChatMyThreadsSection;
        },
        CHAT_PANEL
      );

      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          const SidebarChatStarredChannelLink = createChannelLink(
            BaseCustomSidebarSectionLink,
            {
              showSuffix: false,
              enableHoverForPublicChannels: false,
            }
          );

          const SidebarChatStarredChannelsSection = class extends BaseCustomSidebarSection {
            @service currentUser;
            @service chatStateManager;
            @service siteSettings;

            constructor() {
              super(...arguments);

              if (container.isDestroyed) {
                return;
              }
              this.chatService = container.lookup("service:chat");
              this.chatChannelsManager = container.lookup(
                "service:chat-channels-manager"
              );
            }

            get sectionLinks() {
              return this.chatChannelsManager.starredChannels.map(
                (channel) =>
                  new SidebarChatStarredChannelLink({
                    channel,
                    chatService: this.chatService,
                    currentUser: this.currentUser,
                    siteSettings: this.siteSettings,
                    chatStateManager: this.chatStateManager,
                  })
              );
            }

            get name() {
              return CHAT_STARRED_CHANNELS_SECTION;
            }

            get title() {
              return i18n("chat.starred_channels");
            }

            get text() {
              return i18n("chat.starred_channels");
            }

            get links() {
              return this.sectionLinks;
            }

            get displaySection() {
              return (
                this.chatStateManager.hasPreloadedChannels &&
                this.chatChannelsManager.hasStarredChannels
              );
            }
          };

          return SidebarChatStarredChannelsSection;
        },
        CHAT_PANEL
      );

      if (this.siteSettings.enable_public_channels) {
        api.addSidebarSection(
          (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
            const SidebarChatChannelsSectionLink = class extends BaseCustomSidebarSectionLink {
              constructor({ channel, chatService, siteSettings }) {
                super(...arguments);
                this.channel = channel;
                this.chatService = chatService;
                this.chatStateManager = chatStateManager;
                this.siteSettings = siteSettings;
              }

              get name() {
                return dasherize(this.channel.slugifiedTitle);
              }

              get classNames() {
                const classes = [];

                if (this.channel.currentUserMembership.muted) {
                  classes.push("sidebar-section-link--muted");
                }

                if (
                  this.channel.id === this.chatService.activeChannel?.id &&
                  (this.chatStateManager.isDrawerExpanded ||
                    this.chatStateManager.isFullPageActive)
                ) {
                  classes.push("sidebar-section-link--active");
                }

                classes.push(`channel-${this.channel.id}`);

                return classes.join(" ");
              }

              get route() {
                return "chat.channel";
              }

              get models() {
                return this.channel.routeModels;
              }

              get text() {
                return htmlSafe(emojiUnescape(this.channel.escapedTitle));
              }

              get prefixType() {
                return this.channel.emoji ? "emoji" : "icon";
              }

              get prefixValue() {
                return this.channel.emoji ?? "d-chat";
              }

              get prefixColor() {
                return this.channel.chatable.color;
              }

              get title() {
                return this.channel.escapedDescription
                  ? htmlSafe(this.channel.escapedDescription)
                  : `${this.channel.escapedTitle} ${i18n("chat.title")}`;
              }

              get prefixBadge() {
                return this.channel.chatable.read_restricted ? "lock" : "";
              }

              get suffixComponent() {
                return ChatSidebarIndicators;
              }

              get suffixArgs() {
                return {
                  unreadCount: this.channel.tracking.unreadCount,
                  // We want to do this so we don't show a blue dot if the user is inside
                  // the channel and a new unread thread comes in.
                  unreadThreadsCount:
                    this.chatService.activeChannel?.id !== this.channel.id
                      ? this.channel.unreadThreadsCountSinceLastViewed
                      : 0,
                  mentionCount: this.channel.tracking.mentionCount,
                  watchedThreadsUnreadCount:
                    this.channel.tracking.watchedThreadsUnreadCount,
                  isDirectMessageChannel: false,
                };
              }
            };

            const SidebarChatChannelsSection = class extends BaseCustomSidebarSection {
              @service currentUser;
              @service chatStateManager;
              @service siteSettings;

              @tracked
              currentUserCanJoinPublicChannels =
                this.currentUser &&
                (this.currentUser.staff ||
                  this.currentUser.has_joinable_public_channels);

              constructor() {
                super(...arguments);

                if (container.isDestroyed) {
                  return;
                }
                this.chatService = container.lookup("service:chat");
                this.chatChannelsManager = container.lookup(
                  "service:chat-channels-manager"
                );
                this.router = container.lookup("service:router");
              }

              get sectionLinks() {
                return this.chatChannelsManager.unstarredPublicMessageChannels.map(
                  (channel) =>
                    new SidebarChatChannelsSectionLink({
                      channel,
                      chatService: this.chatService,
                      siteSettings: this.siteSettings,
                    })
                );
              }

              get name() {
                return "chat-channels";
              }

              get title() {
                return i18n("chat.chat_channels");
              }

              get text() {
                return i18n("chat.chat_channels");
              }

              get actions() {
                return [
                  {
                    id: "browseChannels",
                    title: i18n("chat.channels_list_popup.browse"),
                    action: () => this.router.transitionTo("chat.browse.open"),
                  },
                ];
              }

              get actionsIcon() {
                return "pencil";
              }

              get links() {
                return this.sectionLinks;
              }

              get displaySection() {
                return (
                  this.chatStateManager.hasPreloadedChannels &&
                  (this.sectionLinks.length > 0 ||
                    this.currentUserCanJoinPublicChannels)
                );
              }
            };

            return SidebarChatChannelsSection;
          },
          CHAT_PANEL
        );
      }

      if (this.chatService.userCanDirectMessage) {
        api.addSidebarSection(
          (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
            const SidebarChatNewDirectMessagesSectionLink = class extends BaseCustomSidebarSectionLink {
              route = "chat.new-message";
              name = "new-chat-dm";
              title = i18n("sidebar.start_new_dm.title");
              text = i18n("sidebar.start_new_dm.text");
              prefixType = "icon";
              prefixValue = "plus";
            };

            const SidebarChatDirectMessagesSectionLink = class extends BaseCustomSidebarSectionLink {
              route = "chat.channel";
              suffixType = "icon";
              hoverType = "icon";
              hoverValue = "xmark";
              hoverTitle = i18n("chat.direct_messages.close");

              constructor({ channel, chatService, currentUser, siteSettings }) {
                super(...arguments);
                this.channel = channel;
                this.chatService = chatService;
                this.siteSettings = siteSettings;
                this.currentUser = currentUser;
                this.chatStateManager = chatStateManager;

                if (this.oneOnOneMessage) {
                  const user = this.channel.chatable.users[0];
                  if (user.username !== i18n("chat.deleted_chat_username")) {
                    user.statusManager.trackStatus();
                  }
                }
              }

              @bind
              willDestroy() {
                if (this.oneOnOneMessage) {
                  this.channel.chatable.users[0].statusManager.stopTrackingStatus();
                }
              }

              get oneOnOneMessage() {
                return this.channel.chatable.users.length === 1;
              }

              get suffixComponent() {
                return ChatSidebarIndicators;
              }

              get suffixArgs() {
                return {
                  userStatus: this.oneOnOneMessage
                    ? this.channel.chatable.users[0].get("status")
                    : null,
                  unreadCount: this.channel.tracking.unreadCount,
                  unreadThreadsCount:
                    this.channel.unreadThreadsCountSinceLastViewed,
                  mentionCount: this.channel.tracking.mentionCount,
                  watchedThreadsUnreadCount:
                    this.channel.tracking.watchedThreadsUnreadCount,
                  isDirectMessageChannel: true,
                };
              }

              get name() {
                return this.channel.slugifiedTitle;
              }

              get classNames() {
                const classes = [];

                if (this.channel.currentUserMembership.muted) {
                  classes.push("sidebar-section-link--muted");
                }

                if (
                  this.channel.id === this.chatService.activeChannel?.id &&
                  (this.chatStateManager.isDrawerExpanded ||
                    this.chatStateManager.isFullPageActive)
                ) {
                  classes.push("sidebar-section-link--active");
                }

                classes.push(`channel-${this.channel.id}`);

                return classes.join(" ");
              }

              get models() {
                return this.channel.routeModels;
              }

              get title() {
                if (this.channel.chatable.group) {
                  return i18n("chat.placeholder_channel", {
                    channelName: this.channel.escapedTitle,
                  });
                } else {
                  return i18n("chat.placeholder_users", {
                    commaSeparatedNames: this.channel.escapedTitle,
                  });
                }
              }

              get text() {
                if (this.channel.chatable.group) {
                  return this.channel.title;
                } else {
                  const username = this.channel.escapedTitle.replaceAll(
                    "@",
                    ""
                  );
                  return htmlSafe(
                    `${escapeExpression(username)}${decorateUsername(
                      escapeExpression(username)
                    )}`
                  );
                }
              }

              get prefixType() {
                if (this.channel.emoji) {
                  return "emoji";
                } else if (this.channel.chatable.group) {
                  return "text";
                } else {
                  return "image";
                }
              }

              get prefixValue() {
                if (this.channel.emoji) {
                  return this.channel.emoji;
                } else if (this.channel.chatable.group) {
                  return this.channel.membershipsCount;
                } else {
                  return avatarUrl(
                    this.channel.chatable.users[0].avatar_template,
                    "tiny"
                  );
                }
              }

              get prefixCSSClass() {
                const activeUsers = this.chatService.presenceChannel.users;
                const user = this.channel.chatable.users[0];

                if (
                  !!activeUsers?.find((item) => get(item, "id") === user?.id) ||
                  !!activeUsers?.find(
                    (item) => get(item, "username") === user?.username
                  )
                ) {
                  return "active";
                }
                return "";
              }

              get hoverAction() {
                return (event) => {
                  event.stopPropagation();
                  event.preventDefault();
                  this.chatService.unfollowChannel(this.channel);
                };
              }
            };

            const SidebarChatDirectMessagesSection = class extends BaseCustomSidebarSection {
              @service site;
              @service modal;
              @service router;
              @service currentUser;
              @service chatStateManager;
              @service siteSettings;

              constructor() {
                super(...arguments);

                if (container.isDestroyed) {
                  return;
                }

                this.chatService = container.lookup("service:chat");
                this.chatChannelsManager = container.lookup(
                  "service:chat-channels-manager"
                );
              }

              get hideSectionHeader() {
                return (
                  this.chatChannelsManager
                    .truncatedUnstarredDirectMessageChannels.length === 0
                );
              }

              get sectionLinks() {
                const channels =
                  this.chatChannelsManager
                    .truncatedUnstarredDirectMessageChannels;

                if (channels.length > 0) {
                  return channels.map(
                    (channel) =>
                      new SidebarChatDirectMessagesSectionLink({
                        channel,
                        chatService: this.chatService,
                        currentUser: this.currentUser,
                        siteSettings: this.siteSettings,
                      })
                  );
                } else {
                  return [new SidebarChatNewDirectMessagesSectionLink()];
                }
              }

              get name() {
                return "chat-dms";
              }

              get title() {
                return i18n("chat.direct_messages.title");
              }

              get text() {
                return i18n("chat.direct_messages.title");
              }

              get actions() {
                return [
                  {
                    id: "startDm",
                    title: i18n("chat.direct_messages.new"),
                    action: () => {
                      this.modal.show(ChatModalNewMessage);
                    },
                  },
                ];
              }

              get actionsIcon() {
                return "plus";
              }

              get links() {
                return this.sectionLinks;
              }

              get displaySection() {
                return (
                  this.chatStateManager.hasPreloadedChannels &&
                  this.sectionLinks?.length > 0
                );
              }
            };

            return SidebarChatDirectMessagesSection;
          },
          "chat"
        );
      }
    });
  },
};
