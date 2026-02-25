import Service, { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { i18n } from "discourse-i18n";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatChannelArchive from "../models/chat-channel-archive";

export default class ChatSubscriptionsManager extends Service {
  @service chatChannelsManager;
  @service currentUser;
  @service appEvents;
  @service chat;
  @service dialog;
  @service router;

  _globalLastIds = {};

  startChannelsSubscriptions(messageBusIds) {
    this._startNewChannelSubscription(messageBusIds.new_channel);
    this._startChannelUpdatesSubscription(messageBusIds.channel_updates);
    this._startUserStateSubscription(messageBusIds.user_state);
  }

  stopChannelsSubscriptions() {
    this._stopNewChannelSubscription();
    this._stopChannelUpdatesSubscription();
    this._stopUserStateSubscription();
  }

  _startChannelUpdatesSubscription(lastId) {
    this._globalLastIds["/chat/channel-updates"] = lastId;
    this.messageBus.subscribe(
      "/chat/channel-updates",
      this._onChannelUpdate,
      lastId
    );
  }

  _stopChannelUpdatesSubscription() {
    this.messageBus.unsubscribe("/chat/channel-updates", this._onChannelUpdate);
  }

  @bind
  _onChannelUpdate(busData, _globalId, messageId) {
    this._checkForGap("/chat/channel-updates", messageId);

    switch (busData.type) {
      case "edits":
        this._onChannelEdits(busData);
        break;
      case "status":
        this._onChannelStatus(busData);
        break;
      case "metadata":
        this._onChannelMetadata(busData);
        break;
      case "archive_status":
        this._onChannelArchiveStatusUpdate(busData);
        break;
      case "new_messages":
        this._onNewMessages(busData);
        break;
      case "new_mentions":
        this._onNewMentions(busData);
        break;
      case "kick":
        this._onKickFromChannel(busData);
        break;
    }
  }

  _onChannelArchiveStatusUpdate(busData) {
    this.chatChannelsManager
      .find(busData.chat_channel_id, { fetchIfNotFound: false })
      .then((channel) => {
        if (!channel) {
          return;
        }

        channel.archive = ChatChannelArchive.create(busData);
      });
  }

  _onNewMentions(busData) {
    this.chatChannelsManager
      .find(busData.channel_id, { fetchIfNotFound: false })
      .then((channel) => {
        if (!channel) {
          return;
        }

        const membership = channel.currentUserMembership;
        if (busData.message_id > membership?.lastReadMessageId) {
          channel.tracking.mentionCount++;
        }
      });
  }

  _onKickFromChannel(busData) {
    this.chatChannelsManager
      .find(busData.channel_id, { fetchIfNotFound: false })
      .then((channel) => {
        if (!channel) {
          return;
        }

        if (this.chat.activeChannel?.id === channel.id) {
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

  _onNewMessages(busData) {
    switch (busData.payload_type) {
      case "channel":
        this._onNewChannelMessage(busData);
        break;
      case "thread":
        this._onNewThreadMessage(busData);
        break;
    }
  }

  _onNewChannelMessage(busData) {
    this.chatChannelsManager
      .find(busData.channel_id, { fetchIfNotFound: false })
      .then((channel) => {
        if (!channel) {
          return;
        }

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
                  if (thread?.currentUserMembership) {
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
    this.chatChannelsManager
      .find(busData.channel_id, { fetchIfNotFound: false })
      .then((channel) => {
        if (!channel) {
          return;
        }

        if (!channel.threadingEnabled && !busData.force_thread) {
          return;
        }

        channel.threadsManager
          .find(busData.channel_id, busData.thread_id)
          .then((thread) => {
            if (!thread) {
              return;
            }

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

  _startUserStateSubscription(lastId) {
    if (!this.currentUser) {
      return;
    }

    const channel = `/chat/user-state/${this.currentUser.id}`;
    this._globalLastIds[channel] = lastId;
    this.messageBus.subscribe(channel, this._onUserState, lastId);
  }

  _stopUserStateSubscription() {
    if (!this.currentUser) {
      return;
    }

    this.messageBus.unsubscribe(
      `/chat/user-state/${this.currentUser.id}`,
      this._onUserState
    );
  }

  @bind
  _onUserState(busData, _globalId, messageId) {
    this._checkForGap(`/chat/user-state/${this.currentUser.id}`, messageId);

    switch (busData.type) {
      case "tracking_state":
        this._onUserTrackingStateUpdate(busData);
        break;
      case "bulk_tracking_state":
        this._onBulkUserTrackingStateUpdate(busData.channels);
        break;
      case "has_threads":
        this._onUserHasThreads(busData);
        break;
    }
  }

  _onUserHasThreads(busData) {
    if (busData.has_threads) {
      this.chatChannelsManager.userHasThreads = true;
    }
  }

  _onBulkUserTrackingStateUpdate(channels) {
    Object.keys(channels).forEach((channelId) => {
      this._updateChannelTrackingData(channelId, channels[channelId]);
    });
  }

  _onUserTrackingStateUpdate(busData) {
    this._updateChannelTrackingData(busData.channel_id, busData);
  }

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
    this._globalLastIds["/chat/new-channel"] = lastId;
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
  _onNewChannelSubscription(data, _globalId, messageId) {
    this._checkForGap("/chat/new-channel", messageId);

    const channel = this.chatChannelsManager.store(data.channel);
    channel.meta = data.channel.meta;
    channel.currentUserMembership = data.channel.current_user_membership;

    if (
      channel.isDirectMessageChannel &&
      !channel.currentUserMembership.following
    ) {
      channel.tracking.unreadCount = 1;
    }

    this.chatChannelsManager.follow(channel);
  }

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

  _onChannelEdits(busData) {
    this.chatChannelsManager
      .find(busData.chat_channel_id, { fetchIfNotFound: false })
      .then((channel) => {
        if (channel) {
          channel.title = busData.name;
          channel.description = busData.description;
          channel.slug = busData.slug;
        }
      });
  }

  _onChannelStatus(busData) {
    this.chatChannelsManager
      .find(busData.chat_channel_id, { fetchIfNotFound: false })
      .then((channel) => {
        if (channel) {
          channel.status = busData.status;

          // it is not possible for the user to set their last read message id
          // if the channel has been archived, because all the messages have
          // been deleted. we don't want them seeing the blue dot anymore so
          // just completely reset the unreads
          if (busData.status === CHANNEL_STATUSES.archived) {
            channel.tracking.reset();
          }
        }
      });
  }

  _checkForGap(channel, messageId) {
    const lastId = this._globalLastIds[channel];
    if (lastId >= 0 && messageId !== lastId + 1) {
      this.chat.flagDesync(
        `${channel}: expected ${lastId + 1}, got ${messageId}`
      );
    }
    this._globalLastIds[channel] = messageId;
  }
}
