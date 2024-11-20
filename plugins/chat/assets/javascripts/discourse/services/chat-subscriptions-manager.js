import Service, { service } from "@ember/service";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatChannelArchive from "../models/chat-channel-archive";

export default class ChatSubscriptionsManager extends Service {
  @service store;
  @service chatChannelsManager;
  @service chatTrackingStateManager;
  @service currentUser;
  @service appEvents;
  @service chat;
  @service dialog;
  @service router;

  _channelSubscriptions = new Set();

  startChannelSubscription(channel) {
    if (
      channel.currentUserMembership.muted ||
      this._channelSubscriptions.has(channel.id)
    ) {
      return;
    }

    this._channelSubscriptions.add(channel.id);
    this._startChannelMentionsSubscription(channel);

    if (!channel.isDirectMessageChannel) {
      this._startKickFromChannelSubscription(channel);
    }

    this._startChannelNewMessagesSubscription(channel);
  }

  stopChannelSubscription(channel) {
    this.messageBus.unsubscribe(
      `/chat/${channel.id}/new-messages`,
      this._onNewMessages
    );
    if (!channel.isDirectMessageChannel) {
      this.messageBus.unsubscribe(
        `/chat/${channel.id}/new-mentions`,
        this._onNewMentions
      );
      this.messageBus.unsubscribe(
        `/chat/${channel.id}/kick`,
        this._onKickFromChannel
      );
    }

    this._channelSubscriptions.delete(channel.id);
  }

  startChannelsSubscriptions(messageBusIds) {
    this._startNewChannelSubscription(messageBusIds.new_channel);
    this._startChannelArchiveStatusSubscription(messageBusIds.archive_status);
    this._startUserTrackingStateSubscription(messageBusIds.user_tracking_state);
    this._startChannelsEditsSubscription(messageBusIds.channel_edits);
    this._startChannelsStatusChangesSubscription(messageBusIds.channel_status);
    this._startChannelsMetadataChangesSubscription(
      messageBusIds.channel_metadata
    );
  }

  stopChannelsSubscriptions() {
    this._stopNewChannelSubscription();
    this._stopChannelArchiveStatusSubscription();
    this._stopUserTrackingStateSubscription();
    this._stopChannelsEditsSubscription();
    this._stopChannelsStatusChangesSubscription();
    this._stopChannelsMetadataChangesSubscription();

    (this.chatChannelsManager.channels || []).forEach((channel) => {
      this.stopChannelSubscription(channel);
    });
  }

  _startChannelArchiveStatusSubscription(lastId) {
    if (this.currentUser.admin) {
      this.messageBus.subscribe(
        "/chat/channel-archive-status",
        this._onChannelArchiveStatusUpdate,
        lastId
      );
    }
  }

  _stopChannelArchiveStatusSubscription() {
    if (this.currentUser.admin) {
      this.messageBus.unsubscribe(
        "/chat/channel-archive-status",
        this._onChannelArchiveStatusUpdate
      );
    }
  }

  _startChannelMentionsSubscription(channel) {
    this.messageBus.subscribe(
      `/chat/${channel.id}/new-mentions`,
      this._onNewMentions,
      channel.meta.message_bus_last_ids.new_mentions
    );
  }

  _startKickFromChannelSubscription(channel) {
    this.messageBus.subscribe(
      `/chat/${channel.id}/kick`,
      this._onKickFromChannel,
      channel.meta.message_bus_last_ids.kick
    );
  }

  @bind
  _onChannelArchiveStatusUpdate(busData) {
    // we don't want to fetch a channel we don't have locally because archive status changed
    this.chatChannelsManager
      .find(busData.chat_channel_id, { fetchIfNotFound: false })
      .then((channel) => {
        if (!channel) {
          return;
        }

        channel.archive = ChatChannelArchive.create(busData);
      });
  }

  @bind
  _onNewMentions(busData) {
    this.chatChannelsManager.find(busData.channel_id).then((channel) => {
      const membership = channel.currentUserMembership;
      if (busData.message_id > membership?.lastReadMessageId) {
        channel.tracking.mentionCount++;
      }
    });
  }

  @bind
  _onKickFromChannel(busData) {
    this.chatChannelsManager.find(busData.channel_id).then((channel) => {
      if (this.chat.activeChannel.id === channel.id) {
        this.dialog.alert({
          message: i18n("chat.kicked_from_channel"),
          didConfirm: () => {
            this.chatChannelsManager.remove(channel);

            const firstChannel =
              this.chatChannelsManager.publicMessageChannels[0];

            if (firstChannel) {
              this.router.transitionTo(
                "chat.channel",
                ...firstChannel.routeModels
              );
            } else {
              this.router.transitionTo("chat.browse");
            }
          },
        });
      } else {
        this.chatChannelsManager.remove(channel);
      }
    });
  }

  _startChannelNewMessagesSubscription(channel) {
    this.messageBus.subscribe(
      `/chat/${channel.id}/new-messages`,
      this._onNewMessages,
      channel.meta.message_bus_last_ids.new_messages
    );
  }

  @bind
  _onNewMessages(busData) {
    switch (busData.type) {
      case "channel":
        this._onNewChannelMessage(busData);
        break;
      case "thread":
        this._onNewThreadMessage(busData);
        break;
    }
  }

  _onNewChannelMessage(busData) {
    this.chatChannelsManager.find(busData.channel_id).then((channel) => {
      channel.lastMessage = busData.message;
      const user = busData.message.user;
      if (user.id === this.currentUser.id) {
        // User sent message, update tracking state to no unread
        channel.currentUserMembership.lastReadMessageId =
          channel.lastMessage.id;
      } else {
        // Ignored user sent message, update tracking state to no unread
        if (this.currentUser.ignored_users.includes(user.username)) {
          channel.currentUserMembership.lastReadMessageId =
            channel.lastMessage.id;
        } else {
          if (
            channel.lastMessage.id >
            (channel.currentUserMembership.lastReadMessageId || 0)
          ) {
            channel.tracking.unreadCount++;
          }

          // Thread should be considered unread if not already.
          if (busData.thread_id && channel.threadingEnabled) {
            channel.threadsManager
              .find(channel.id, busData.thread_id)
              .then((thread) => {
                if (thread.currentUserMembership) {
                  channel.threadsManager.markThreadUnread(
                    busData.thread_id,
                    busData.message.created_at
                  );
                  this._updateActiveLastViewedAt(channel);
                }
              });
          }
        }
      }
    });
  }

  _onNewThreadMessage(busData) {
    this.chatChannelsManager.find(busData.channel_id).then((channel) => {
      if (!channel.threadingEnabled && !busData.force_thread) {
        return;
      }

      channel.threadsManager
        .find(busData.channel_id, busData.thread_id)
        .then((thread) => {
          thread.lastMessageId = busData.message.id;

          if (busData.message.user.id === this.currentUser.id) {
            // Thread should no longer be considered unread.
            if (thread.currentUserMembership) {
              channel.threadsManager.unreadThreadOverview.delete(
                parseInt(busData.thread_id, 10)
              );
              thread.currentUserMembership.lastReadMessageId =
                busData.message.id;
            }
          } else {
            // Ignored user sent message, update tracking state to no unread
            if (
              this.currentUser.ignored_users.includes(
                busData.message.user.username
              )
            ) {
              if (thread.currentUserMembership) {
                thread.currentUserMembership.lastReadMessageId =
                  busData.message.id;
              }
            } else {
              // Message from other user. Increment unread for thread tracking state.
              if (
                thread.currentUserMembership &&
                busData.message.id >
                  (thread.currentUserMembership.lastReadMessageId || 0) &&
                !thread.currentUserMembership.isQuiet
              ) {
                channel.threadsManager.markThreadUnread(
                  busData.thread_id,
                  busData.message.created_at
                );

                if (
                  thread.currentUserMembership.notificationLevel ===
                  NotificationLevels.WATCHING
                ) {
                  thread.tracking.watchedThreadsUnreadCount++;
                  channel.tracking.watchedThreadsUnreadCount++;
                } else {
                  thread.tracking.unreadCount++;
                }

                this._updateActiveLastViewedAt(channel);
              }
            }
          }
        });
    });
  }

  // If the user is currently looking at this channel via activeChannel, we don't want the unread
  // indicator to show in the sidebar for unread threads (since that is based on the lastViewedAt).
  _updateActiveLastViewedAt(channel) {
    if (this.chat.activeChannel?.id === channel.id) {
      channel.updateLastViewedAt();
    }
  }

  _startUserTrackingStateSubscription(lastId) {
    if (!this.currentUser) {
      return;
    }

    this.messageBus.subscribe(
      `/chat/user-tracking-state/${this.currentUser.id}`,
      this._onUserTrackingStateUpdate,
      lastId
    );
    this.messageBus.subscribe(
      `/chat/bulk-user-tracking-state/${this.currentUser.id}`,
      this._onBulkUserTrackingStateUpdate,
      lastId
    );
  }

  _stopUserTrackingStateSubscription() {
    if (!this.currentUser) {
      return;
    }

    this.messageBus.unsubscribe(
      `/chat/user-tracking-state/${this.currentUser.id}`,
      this._onUserTrackingStateUpdate
    );

    this.messageBus.unsubscribe(
      `/chat/bulk-user-tracking-state/${this.currentUser.id}`,
      this._onBulkUserTrackingStateUpdate
    );
  }

  @bind
  _onBulkUserTrackingStateUpdate(busData) {
    Object.keys(busData).forEach((channelId) => {
      this._updateChannelTrackingData(channelId, busData[channelId]);
    });
  }

  @bind
  _onUserTrackingStateUpdate(busData) {
    this._updateChannelTrackingData(busData.channel_id, busData);
  }

  @bind
  _updateChannelTrackingData(channelId, busData) {
    this.chatChannelsManager.find(channelId).then((channel) => {
      if (!busData.thread_id) {
        channel.currentUserMembership.lastReadMessageId =
          busData.last_read_message_id;
      }

      channel.tracking.unreadCount = busData.unread_count;
      channel.tracking.mentionCount = busData.mention_count;
      channel.tracking.watchedThreadsUnreadCount =
        busData.watched_threads_unread_count;

      if (
        busData.hasOwnProperty("unread_thread_overview") &&
        channel.threadingEnabled
      ) {
        channel.threadsManager.unreadThreadOverview =
          busData.unread_thread_overview;
      }

      if (
        busData.thread_id &&
        busData.hasOwnProperty("thread_tracking") &&
        channel.threadingEnabled
      ) {
        channel.threadsManager
          .find(channelId, busData.thread_id)
          .then((thread) => {
            if (
              thread.currentUserMembership &&
              !thread.currentUserMembership.isQuiet
            ) {
              thread.currentUserMembership.lastReadMessageId =
                busData.last_read_message_id;
              thread.tracking.unreadCount =
                busData.thread_tracking.unread_count;
              thread.tracking.mentionCount =
                busData.thread_tracking.mention_count;
              thread.tracking.watchedThreadsUnreadCount =
                busData.thread_tracking.watched_threads_unread_count;
            }
          });
      }
    });
  }

  _startNewChannelSubscription(lastId) {
    this.messageBus.subscribe(
      "/chat/new-channel",
      this._onNewChannelSubscription,
      lastId
    );
  }

  _stopNewChannelSubscription() {
    this.messageBus.unsubscribe(
      "/chat/new-channel",
      this._onNewChannelSubscription
    );
  }

  @bind
  _onNewChannelSubscription(data) {
    this.chatChannelsManager.find(data.channel.id).then((channel) => {
      // we need to refresh here to have correct last message ids
      channel.meta = data.channel.meta;
      channel.currentUserMembership = data.channel.current_user_membership;

      if (
        channel.isDirectMessageChannel &&
        !channel.currentUserMembership.following
      ) {
        channel.tracking.unreadCount = 1;
      }

      this.chatChannelsManager.follow(channel);
    });
  }

  _startChannelsMetadataChangesSubscription(lastId) {
    this.messageBus.subscribe(
      "/chat/channel-metadata",
      this._onChannelMetadata,
      lastId
    );
  }

  _startChannelsEditsSubscription(lastId) {
    this.messageBus.subscribe(
      "/chat/channel-edits",
      this._onChannelEdits,
      lastId
    );
  }

  _startChannelsStatusChangesSubscription(lastId) {
    this.messageBus.subscribe(
      "/chat/channel-status",
      this._onChannelStatus,
      lastId
    );
  }

  _stopChannelsStatusChangesSubscription() {
    this.messageBus.unsubscribe("/chat/channel-status", this._onChannelStatus);
  }

  _stopChannelsEditsSubscription() {
    this.messageBus.unsubscribe("/chat/channel-edits", this._onChannelEdits);
  }

  _stopChannelsMetadataChangesSubscription() {
    this.messageBus.unsubscribe(
      "/chat/channel-metadata",
      this._onChannelMetadata
    );
  }

  @bind
  _onChannelMetadata(busData) {
    this.chatChannelsManager
      .find(busData.chat_channel_id, { fetchIfNotFound: false })
      .then((channel) => {
        if (channel) {
          channel.membershipsCount = busData.memberships_count;
          this.appEvents.trigger("chat:refresh-channel-members");
        }
      });
  }

  @bind
  _onChannelEdits(busData) {
    this.chatChannelsManager.find(busData.chat_channel_id).then((channel) => {
      if (channel) {
        channel.title = busData.name;
        channel.description = busData.description;
        channel.slug = busData.slug;
      }
    });
  }

  @bind
  _onChannelStatus(busData) {
    this.chatChannelsManager.find(busData.chat_channel_id).then((channel) => {
      channel.status = busData.status;

      // it is not possible for the user to set their last read message id
      // if the channel has been archived, because all the messages have
      // been deleted. we don't want them seeing the blue dot anymore so
      // just completely reset the unreads
      if (busData.status === CHANNEL_STATUSES.archived) {
        channel.tracking.reset();
      }
    });
  }
}
