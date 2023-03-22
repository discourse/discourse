import Service, { inject as service } from "@ember/service";
import I18n from "I18n";
import { bind } from "discourse-common/utils/decorators";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ChatSubscriptionsManager extends Service {
  @service store;
  @service chatChannelsManager;
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

    if (!channel.isDirectMessageChannel) {
      this._startChannelMentionsSubscription(channel);
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

        channel.setProperties({
          archive_failed: busData.archive_failed,
          archive_completed: busData.archive_completed,
          archived_messages: busData.archived_messages,
          archive_topic_id: busData.archive_topic_id,
          total_messages: busData.total_messages,
        });
      });
  }

  @bind
  _onNewMentions(busData) {
    this.chatChannelsManager.find(busData.channel_id).then((channel) => {
      const membership = channel.currentUserMembership;
      if (busData.message_id > membership?.last_read_message_id) {
        membership.unread_mentions = (membership.unread_mentions || 0) + 1;
      }
    });
  }

  @bind
  _onKickFromChannel(busData) {
    this.chatChannelsManager.find(busData.channel_id).then((channel) => {
      if (this.chat.activeChannel.id === channel.id) {
        this.dialog.alert({
          message: I18n.t("chat.kicked_from_channel"),
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
    this.chatChannelsManager.find(busData.channel_id).then((channel) => {
      if (busData.user_id === this.currentUser.id) {
        // User sent message, update tracking state to no unread
        channel.currentUserMembership.last_read_message_id = busData.message_id;
      } else {
        // Ignored user sent message, update tracking state to no unread
        if (this.currentUser.ignored_users.includes(busData.username)) {
          channel.currentUserMembership.last_read_message_id =
            busData.message_id;
        } else {
          // Message from other user. Increment trackings state
          if (
            busData.message_id >
            (channel.currentUserMembership.last_read_message_id || 0)
          ) {
            channel.currentUserMembership.unread_count =
              channel.currentUserMembership.unread_count + 1;
          }
        }
      }

      channel.lastMessageSentAt = new Date();
    });
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
  }

  _stopUserTrackingStateSubscription() {
    if (!this.currentUser) {
      return;
    }

    this.messageBus.unsubscribe(
      `/chat/user-tracking-state/${this.currentUser.id}`,
      this._onUserTrackingStateUpdate
    );
  }

  @bind
  _onUserTrackingStateUpdate(busData) {
    this.chatChannelsManager.find(busData.chat_channel_id).then((channel) => {
      if (
        !channel?.currentUserMembership?.last_read_message_id ||
        parseInt(channel?.currentUserMembership?.last_read_message_id, 10) <=
          busData.chat_message_id
      ) {
        channel.currentUserMembership.last_read_message_id =
          busData.chat_message_id;
        channel.currentUserMembership.unread_count = busData.unread_count;
        channel.currentUserMembership.unread_mentions = busData.unread_mentions;
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
      // we need to refrehs here to have correct last message ids
      channel.meta = data.channel.meta;

      if (
        channel.isDirectMessageChannel &&
        !channel.currentUserMembership.following
      ) {
        channel.currentUserMembership.unread_count = 1;
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
          channel.setProperties({
            memberships_count: busData.memberships_count,
          });
          this.appEvents.trigger("chat:refresh-channel-members");
        }
      });
  }

  @bind
  _onChannelEdits(busData) {
    this.chatChannelsManager.find(busData.chat_channel_id).then((channel) => {
      if (channel) {
        channel.setProperties({
          title: busData.name,
          description: busData.description,
          slug: busData.slug,
        });
      }
    });
  }

  @bind
  _onChannelStatus(busData) {
    this.chatChannelsManager.find(busData.chat_channel_id).then((channel) => {
      channel.set("status", busData.status);

      // it is not possible for the user to set their last read message id
      // if the channel has been archived, because all the messages have
      // been deleted. we don't want them seeing the blue dot anymore so
      // just completely reset the unreads
      if (busData.status === CHANNEL_STATUSES.archived) {
        channel.currentUserMembership.unread_count = 0;
        channel.currentUserMembership.unread_mentions = 0;
      }
    });
  }
}
