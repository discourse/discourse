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
  @service chatChannelNoticesManager;

  _channelCallbacks = new Map();

  startChannelsSubscriptions(messageBusIds, channels) {
    this._startPerChannelSubscriptions(channels);
    this._startUserStateSubscription(messageBusIds.user_state);
  }

  stopChannelsSubscriptions() {
    this._stopPerChannelSubscriptions();
    this._stopUserStateSubscription();
  }

  subscribeToChannel(channel) {
    if (this._channelCallbacks.has(channel.id)) {
      return;
    }
    this._subscribeToChannel(channel);
  }

  unsubscribeFromChannel(channel) {
    this._unsubscribeFromChannel(channel);
  }

  _startPerChannelSubscriptions(channels) {
    channels?.forEach((channel) => this._subscribeToChannel(channel));
  }

  _stopPerChannelSubscriptions() {
    for (const [channelId, callback] of this._channelCallbacks) {
      this.messageBus.unsubscribe(`/chat/${channelId}`, callback);
    }
    this._channelCallbacks.clear();
  }

  _subscribeToChannel(channel) {
    if (this._channelCallbacks.has(channel.id)) {
      return;
    }

    const busChannel = `/chat/${channel.id}`;
    let lastId = channel.channelMessageBusLastId;
    const callback = (busData, _globalId, messageId) => {
      // Gap detection runs synchronously, before any microtask from the
      // view-time ChatChannelSubscriptionManager can update channelMessageBusLastId.
      if (lastId >= 0 && messageId !== lastId + 1) {
        this.chat.flagDesync(
          `${busChannel}: expected ${lastId + 1}, got ${messageId}`
        );
      }
      lastId = messageId;

      this._onPerChannelMessage(channel.id, busData, messageId);
    };

    this._channelCallbacks.set(channel.id, callback);
    this.messageBus.subscribe(busChannel, callback, lastId);
  }

  _unsubscribeFromChannel(channel) {
    const callback = this._channelCallbacks.get(channel.id);
    if (callback) {
      this.messageBus.unsubscribe(`/chat/${channel.id}`, callback);
      this._channelCallbacks.delete(channel.id);
    }
  }

  @bind
  _onPerChannelMessage(channelId, busData, messageId) {
    this.chatChannelsManager
      .find(channelId, { fetchIfNotFound: false })
      .then((channel) => {
        if (!channel) {
          return;
        }

        channel.channelMessageBusLastId = messageId;

        switch (busData.type) {
          case "sent":
            this._onSentForTracking(channel, busData);
            break;
          case "new_messages":
            this._onNewMessages(busData);
            break;
          case "edits":
            this._onChannelEdits(channel, busData);
            break;
          case "status":
            this._onChannelStatus(channel, busData);
            break;
          case "metadata":
            this._onChannelMetadata(channel, busData);
            break;
          case "archive_status":
            this._onChannelArchiveStatusUpdate(channel, busData);
            break;
        }
      });
  }

  _onSentForTracking(channel, busData) {
    const message = busData.chat_message;
    if (!message) {
      return;
    }

    channel.lastMessage = message;
    const user = message.user;
    if (user.id === this.currentUser.id) {
      channel.currentUserMembership.lastReadMessageId = message.id;
    } else {
      if (this.currentUser.ignored_users.includes(user.username)) {
        channel.currentUserMembership.lastReadMessageId = message.id;
      } else {
        if (
          message.id > (channel.currentUserMembership.lastReadMessageId || 0)
        ) {
          channel.tracking.unreadCount++;
        }

        if (busData.chat_message.thread_id && channel.threadingEnabled) {
          channel.threadsManager
            .find(channel.id, busData.chat_message.thread_id)
            .then((thread) => {
              if (thread?.currentUserMembership) {
                channel.threadsManager.markThreadUnread(
                  busData.chat_message.thread_id,
                  busData.chat_message.created_at
                );
                this._updateActiveLastViewedAt(channel);
              }
            });
        }
      }
    }
  }

  _onChannelArchiveStatusUpdate(channel, busData) {
    channel.archive = ChatChannelArchive.create(busData);
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
      case "thread":
        this._onNewThreadMessage(busData);
        break;
    }
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
              if (thread.currentUserMembership) {
                channel.threadsManager.unreadThreadOverview.delete(
                  parseInt(busData.thread_id, 10)
                );
                thread.currentUserMembership.lastReadMessageId =
                  busData.message.id;
              }
            } else {
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
    this._userStateLastId = lastId;
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
    const channel = `/chat/user-state/${this.currentUser.id}`;
    if (this._userStateLastId >= 0 && messageId !== this._userStateLastId + 1) {
      this.chat.flagDesync(
        `${channel}: expected ${this._userStateLastId + 1}, got ${messageId}`
      );
    }
    this._userStateLastId = messageId;

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
      case "new_mentions":
        this._onNewMentions(busData);
        break;
      case "kick":
        this._onKickFromChannel(busData);
        break;
      case "new_channel":
        this._onNewChannelMessage(busData);
        break;
      case "notice":
        this._onNotice(busData);
        break;
      case "self_flagged":
        this._onSelfFlagged(busData);
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

  _onNewChannelMessage(data) {
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
    this._subscribeToChannel(channel);
  }

  _onNotice(busData) {
    this.chatChannelNoticesManager.handleNotice(busData);
  }

  _onSelfFlagged(busData) {
    this.chatChannelsManager
      .find(busData.channel_id, { fetchIfNotFound: false })
      .then((channel) => {
        if (!channel) {
          return;
        }

        const message = channel.messagesManager.findMessage(
          busData.chat_message_id
        );
        if (message) {
          message.userFlagStatus = busData.user_flag_status;
        }
      });
  }

  _onChannelMetadata(channel, busData) {
    channel.membershipsCount = busData.memberships_count;
    this.appEvents.trigger("chat:refresh-channel-members");
  }

  _onChannelEdits(channel, busData) {
    channel.title = busData.name;
    channel.description = busData.description;
    channel.slug = busData.slug;
  }

  _onChannelStatus(channel, busData) {
    channel.status = busData.status;

    if (busData.status === CHANNEL_STATUSES.archived) {
      channel.tracking.reset();
    }
  }
}
