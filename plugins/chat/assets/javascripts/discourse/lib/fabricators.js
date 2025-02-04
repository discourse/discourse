/*
Fabricators are used to create fake data for testing purposes.
The following fabricators are available in lib folder to allow
styleguide to use them, and eventually to generate dummy data
in a placeholder component. It should not be used for any other case.
*/
import ApplicationInstance from "@ember/application/instance";
import { setOwner } from "@ember/owner";
import CoreFabricators, { incrementSequence } from "discourse/lib/fabricators";
import Category from "discourse/models/category";
import ChatChannel, {
  CHANNEL_STATUSES,
  CHATABLE_TYPES,
} from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatDirectMessage from "discourse/plugins/chat/discourse/models/chat-direct-message";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatMessageReaction from "discourse/plugins/chat/discourse/models/chat-message-reaction";
import ChatThread from "discourse/plugins/chat/discourse/models/chat-thread";
import ChatThreadPreview from "discourse/plugins/chat/discourse/models/chat-thread-preview";

export default class ChatFabricators {
  constructor(owner) {
    if (owner && !(owner instanceof ApplicationInstance)) {
      throw new Error(
        "First argument of ChatFabricators constructor must be the owning ApplicationInstance"
      );
    }
    setOwner(this, owner);
    this.coreFabricators = new CoreFabricators(owner);
  }

  message(args = {}) {
    const channel = args.channel || this.channel();

    const message = ChatMessage.create(
      channel,
      Object.assign(
        {
          id: args.id || incrementSequence(),
          user: args.user || this.coreFabricators.user(),
          message:
            args.message ||
            "@discobot **abc**defghijklmnopqrstuvwxyz [discourse](discourse.org) :rocket: ",
          created_at: args.created_at || moment(),
        },
        args
      )
    );

    const excerptLength = 50;
    const text = message.message.toString();
    if (text.length <= excerptLength) {
      message.excerpt = text;
    } else {
      message.excerpt = text.slice(0, excerptLength) + "...";
    }

    return message;
  }

  channel(args = {}) {
    const id = args.id || incrementSequence();
    const chatable = args.chatable || this.coreFabricators.category();

    const channel = ChatChannel.create({
      id,
      chatable_type:
        (chatable instanceof Category
          ? CHATABLE_TYPES.categoryChannel
          : CHATABLE_TYPES.directMessageChannel) ||
        chatable?.type ||
        args.chatable_type,
      chatable_id: chatable?.id || args.chatable_id,
      title: args.title
        ? args.title
        : chatable instanceof Category
        ? chatable.name
        : null,
      description: args.description,
      chatable,
      status: args.status || CHANNEL_STATUSES.open,
      slug:
        chatable?.slug || chatable instanceof Category ? chatable.slug : null,
      meta: { can_delete_self: true, ...(args.meta || {}) },
      archive_failed: args.archive_failed ?? false,
      memberships_count: args.memberships_count ?? 0,
    });

    channel.lastMessage = this.message({ channel });

    return channel;
  }

  directMessage(args = {}) {
    return ChatDirectMessage.create({
      group: args.group ?? false,
      users: args.users ?? [
        this.coreFabricators.user(),
        this.coreFabricators.user(),
      ],
    });
  }

  directMessageChannel(args = {}) {
    const directMessage =
      args.chatable ||
      this.directMessage({
        id: args.chatable_id || incrementSequence(),
        group: args.group ?? false,
        users: args.users,
      });

    return this.channel(
      Object.assign(args, {
        chatable_type: CHATABLE_TYPES.directMessageChannel,
        chatable_id: directMessage.id,
        chatable: directMessage,
        memberships_count: directMessage.users.length,
      })
    );
  }

  thread(args = {}) {
    const channel = args.channel || this.channel();
    return ChatThread.create(channel, {
      id: args.id || incrementSequence(),
      title: args.title,
      original_message: args.original_message || this.message({ channel }),
      preview: args.preview || this.threadPreview({ channel }),
    });
  }

  threadPreview(args = {}) {
    return ChatThreadPreview.create({
      last_reply_id: args.last_reply_id || incrementSequence(),
      last_reply_created_at: args.last_reply_created_at || Date.now(),
      last_reply_excerpt: args.last_reply_excerpt || "This is a reply",
      participant_count: args.participant_count ?? 0,
      participant_users: args.participant_users ?? [],
    });
  }

  reaction(args = {}) {
    return ChatMessageReaction.create({
      count: args.count ?? 1,
      users: args.users || [this.coreFabricators.user()],
      emoji: args.emoji || "heart",
      reacted: args.reacted ?? false,
    });
  }
}
