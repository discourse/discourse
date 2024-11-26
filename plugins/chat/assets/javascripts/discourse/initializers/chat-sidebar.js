import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { htmlSafe } from "@ember/template";
import UserStatusMessage from "discourse/components/user-status-message";
import { decorateUsername } from "discourse/helpers/decorate-username-selector";
import { withPluginApi } from "discourse/lib/plugin-api";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { avatarUrl } from "discourse-common/lib/avatar-utils";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";
import {
  CHAT_PANEL,
  initSidebarState,
} from "discourse/plugins/chat/discourse/lib/init-sidebar-state";

export default {
  name: "chat-sidebar",
  initialize(container) {
    this.chatService = container.lookup("service:chat");

    if (!this.chatService.userCanChat) {
      return;
    }

    this.siteSettings = container.lookup("service:site-settings");
    this.currentUser = container.lookup("service:current-user");

    withPluginApi("1.8.0", (api) => {
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

    withPluginApi("1.3.0", (api) => {
      const chatChannelsManager = container.lookup(
        "service:chat-channels-manager"
      );
      const chatStateManager = container.lookup("service:chat-state-manager");

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
              return this.chatChannelsManager.hasThreadedChannels;
            }
          };

          return SidebarChatMyThreadsSection;
        },
        CHAT_PANEL
      );

      if (this.siteSettings.enable_public_channels) {
        api.addSidebarSection(
          (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
            const SidebarChatChannelsSectionLink = class extends BaseCustomSidebarSectionLink {
              constructor({ channel, chatService }) {
                super(...arguments);
                this.channel = channel;
                this.chatService = chatService;
                this.chatStateManager = chatStateManager;
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
                return "icon";
              }

              get prefixValue() {
                return "d-chat";
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

              get suffixType() {
                return "icon";
              }

              get suffixValue() {
                return this.channel.tracking.unreadCount > 0 ||
                  // We want to do this so we don't show a blue dot if the user is inside
                  // the channel and a new unread thread comes in.
                  (this.chatService.activeChannel?.id !== this.channel.id &&
                    this.channel.unreadThreadsCountSinceLastViewed > 0)
                  ? "circle"
                  : "";
              }

              get suffixCSSClass() {
                return this.channel.tracking.mentionCount > 0 ||
                  this.channel.tracking.watchedThreadsUnreadCount > 0
                  ? "urgent"
                  : "unread";
              }
            };

            const SidebarChatChannelsSection = class extends BaseCustomSidebarSection {
              @service currentUser;
              @service chatStateManager;

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
                return this.chatChannelsManager.publicMessageChannels.map(
                  (channel) =>
                    new SidebarChatChannelsSectionLink({
                      channel,
                      chatService: this.chatService,
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

      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          const SidebarChatDirectMessagesSectionLink = class extends BaseCustomSidebarSectionLink {
            route = "chat.channel";
            suffixType = "icon";
            hoverType = "icon";
            hoverValue = "xmark";
            hoverTitle = i18n("chat.direct_messages.close");

            constructor({ channel, chatService, currentUser }) {
              super(...arguments);
              this.channel = channel;
              this.chatService = chatService;
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

            get contentComponentArgs() {
              return this.channel.chatable.users[0].get("status");
            }

            get contentComponent() {
              if (this.oneOnOneMessage) {
                return UserStatusMessage;
              }
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
                const username = this.channel.escapedTitle.replaceAll("@", "");
                return htmlSafe(
                  `${escapeExpression(username)}${decorateUsername(
                    escapeExpression(username)
                  )}`
                );
              }
            }

            get prefixType() {
              if (this.channel.iconUploadUrl) {
                return "image";
              } else if (this.channel.chatable.group) {
                return "text";
              } else {
                return "image";
              }
            }

            get prefixValue() {
              if (this.channel.iconUploadUrl) {
                return this.channel.iconUploadUrl;
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
                !!activeUsers?.findBy("id", user?.id) ||
                !!activeUsers?.findBy("username", user?.username)
              ) {
                return "active";
              }
              return "";
            }

            get suffixValue() {
              return this.channel.tracking.unreadCount > 0 ||
                this.channel.unreadThreadsCountSinceLastViewed > 0
                ? "circle"
                : "";
            }

            get suffixCSSClass() {
              return this.channel.tracking.unreadCount > 0 ||
                this.channel.tracking.mentionCount > 0 ||
                this.channel.tracking.watchedThreadsUnreadCount > 0
                ? "urgent"
                : "unread";
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

            @tracked
            userCanDirectMessage = this.chatService.userCanDirectMessage;

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
              return this.chatChannelsManager.truncatedDirectMessageChannels.map(
                (channel) =>
                  new SidebarChatDirectMessagesSectionLink({
                    channel,
                    chatService: this.chatService,
                    currentUser: this.currentUser,
                  })
              );
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
              if (!this.userCanDirectMessage) {
                return [];
              }

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
                (this.sectionLinks.length > 0 || this.userCanDirectMessage)
              );
            }
          };

          return SidebarChatDirectMessagesSection;
        },
        "chat"
      );
    });
  },
};
