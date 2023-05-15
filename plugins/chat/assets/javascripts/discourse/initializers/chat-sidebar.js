import { htmlSafe } from "@ember/template";
import { withPluginApi } from "discourse/lib/plugin-api";
import I18n from "I18n";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { avatarUrl, escapeExpression } from "discourse/lib/utilities";
import { dasherize } from "@ember/string";
import { emojiUnescape } from "discourse/lib/text";
import { decorateUsername } from "discourse/helpers/decorate-username-selector";
import { until } from "discourse/lib/formatter";
import { inject as service } from "@ember/service";

export default {
  name: "chat-sidebar",
  initialize(container) {
    this.chatService = container.lookup("service:chat");
    this.chatTrackingState = container.lookup("service:chat-tracking-state");

    if (!this.chatService.userCanChat) {
      return;
    }

    withPluginApi("1.3.0", (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          const SidebarChatChannelsSectionLink = class extends BaseCustomSidebarSectionLink {
            constructor({ channel, chatService, chatTrackingState }) {
              super(...arguments);
              this.channel = channel;
              this.chatService = chatService;
              this.chatTrackingState = chatTrackingState;
            }

            get name() {
              return dasherize(this.channel.slugifiedTitle);
            }

            get classNames() {
              const classes = [];

              if (this.channel.currentUserMembership.muted) {
                classes.push("sidebar-section-link--muted");
              }

              if (this.channel.id === this.chatService.activeChannel?.id) {
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
                : `${this.channel.escapedTitle} ${I18n.t("chat.title")}`;
            }

            get prefixBadge() {
              return this.channel.chatable.read_restricted ? "lock" : "";
            }

            get suffixType() {
              return "icon";
            }

            get suffixValue() {
              return this.chatTrackingState.getChannelState(this.channel.id)
                .unreadCount > 0
                ? "circle"
                : "";
            }

            get suffixCSSClass() {
              return this.chatTrackingState.getChannelState(this.channel.id)
                .mentionCount > 0
                ? "urgent"
                : "unread";
            }
          };

          const SidebarChatChannelsSection = class extends BaseCustomSidebarSection {
            @tracked currentUserCanJoinPublicChannels =
              this.sidebar.currentUser &&
              (this.sidebar.currentUser.staff ||
                this.sidebar.currentUser.has_joinable_public_channels);

            constructor() {
              super(...arguments);

              if (container.isDestroyed) {
                return;
              }
              this.chatService = container.lookup("service:chat");
              this.chatTrackingState = container.lookup(
                "service:chat-tracking-state"
              );
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
                    chatTrackingState: this.chatTrackingState,
                  })
              );
            }

            get name() {
              return "chat-channels";
            }

            get title() {
              return I18n.t("chat.chat_channels");
            }

            get text() {
              return I18n.t("chat.chat_channels");
            }

            get actions() {
              return [
                {
                  id: "browseChannels",
                  title: I18n.t("chat.channels_list_popup.browse"),
                  action: () => this.router.transitionTo("chat.browse.open"),
                },
              ];
            }

            get actionsIcon() {
              return "pencil-alt";
            }

            get links() {
              return this.sectionLinks;
            }

            get displaySection() {
              return (
                this.sectionLinks.length > 0 ||
                this.currentUserCanJoinPublicChannels
              );
            }
          };

          return SidebarChatChannelsSection;
        }
      );

      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          const SidebarChatDirectMessagesSectionLink = class extends BaseCustomSidebarSectionLink {
            constructor({ channel, chatService, chatTrackingState }) {
              super(...arguments);
              this.channel = channel;
              this.chatService = chatService;
              this.chatTrackingState = chatTrackingState;

              if (this.oneOnOneMessage) {
                this.channel.chatable.users[0].trackStatus();
              }
            }

            @bind
            willDestroy() {
              if (this.oneOnOneMessage) {
                this.channel.chatable.users[0].stopTrackingStatus();
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

              if (this.channel.id === this.chatService.activeChannel?.id) {
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

            get title() {
              return I18n.t("chat.placeholder_channel", {
                channelName: this.channel.escapedTitle,
              });
            }

            get oneOnOneMessage() {
              return this.channel.chatable.users.length === 1;
            }

            get text() {
              const username = this.channel.escapedTitle.replaceAll("@", "");
              if (this.oneOnOneMessage) {
                const status = this.channel.chatable.users[0].get("status");
                const statusHtml = status ? this._userStatusHtml(status) : "";
                return htmlSafe(
                  `${escapeExpression(
                    username
                  )}${statusHtml} ${decorateUsername(
                    escapeExpression(username)
                  )}`
                );
              } else {
                return username;
              }
            }

            get prefixType() {
              if (this.oneOnOneMessage) {
                return "image";
              } else {
                return "text";
              }
            }

            get prefixValue() {
              if (this.channel.chatable.users.length === 1) {
                return avatarUrl(
                  this.channel.chatable.users[0].avatar_template,
                  "tiny"
                );
              } else {
                return this.channel.chatable.users.length;
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

            get suffixType() {
              return "icon";
            }

            get suffixValue() {
              return this.chatTrackingState.getChannelState(this.channel.id)
                .unreadCount > 0
                ? "circle"
                : "";
            }

            get suffixCSSClass() {
              return "urgent";
            }

            get hoverType() {
              return "icon";
            }

            get hoverValue() {
              return "times";
            }

            get hoverAction() {
              return (event) => {
                event.stopPropagation();
                event.preventDefault();
                this.chatService.unfollowChannel(this.channel);
              };
            }

            get hoverTitle() {
              return I18n.t("chat.direct_messages.leave");
            }

            _userStatusHtml(status) {
              const emoji = escapeExpression(`:${status.emoji}:`);
              const title = this._userStatusTitle(status);
              return `<span class="user-status">${emojiUnescape(emoji, {
                title,
              })}</span>`;
            }

            _userStatusTitle(status) {
              let title = `${escapeExpression(status.description)}`;

              if (status.ends_at) {
                const untilFormatted = until(
                  status.ends_at,
                  this.chatService.currentUser.user_option.timezone,
                  this.chatService.currentUser.locale
                );
                title += ` ${untilFormatted}`;
              }

              return title;
            }
          };

          const SidebarChatDirectMessagesSection = class extends BaseCustomSidebarSection {
            @service site;
            @service router;
            @tracked userCanDirectMessage =
              this.chatService.userCanDirectMessage;

            constructor() {
              super(...arguments);

              if (container.isDestroyed) {
                return;
              }
              this.chatService = container.lookup("service:chat");
              this.chatTrackingState = container.lookup(
                "service:chat-tracking-state"
              );
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
                    chatTrackingState: this.chatTrackingState,
                  })
              );
            }

            get name() {
              return "chat-dms";
            }

            get title() {
              return I18n.t("chat.direct_messages.title");
            }

            get text() {
              return I18n.t("chat.direct_messages.title");
            }

            get actions() {
              if (!this.userCanDirectMessage) {
                return [];
              }

              return [
                {
                  id: "startDm",
                  title: I18n.t("chat.direct_messages.new"),
                  action: () => {
                    this.router.transitionTo("chat.draft-channel");
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
              return this.sectionLinks.length > 0 || this.userCanDirectMessage;
            }
          };

          return SidebarChatDirectMessagesSection;
        }
      );
    });
  },
};
