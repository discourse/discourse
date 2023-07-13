/*
Fabricators are used to create fake data for testing purposes.
The following fabricators are available in lib folder to allow
styleguide to use them, and eventually to generate dummy data
in a placeholder component. It should not be used for any other case.
*/

import ChatChannel, {
  CHANNEL_STATUSES,
  CHATABLE_TYPES,
} from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatThread from "discourse/plugins/chat/discourse/models/chat-thread";
import ChatThreadPreview from "discourse/plugins/chat/discourse/models/chat-thread-preview";
import ChatDirectMessage from "discourse/plugins/chat/discourse/models/chat-direct-message";
import ChatMessageMentionWarning from "discourse/plugins/chat/discourse/models/chat-message-mention-warning";
import ChatMessageReaction from "discourse/plugins/chat/discourse/models/chat-message-reaction";
import User from "discourse/models/user";
import Bookmark from "discourse/models/bookmark";
import Category from "discourse/models/category";
import Group from "discourse/models/group";

let sequence = 0;

function messageFabricator(args = {}) {
  const channel = args.channel || channelFabricator();

  const message = ChatMessage.create(
    channel,
    Object.assign(
      {
        id: args.id || sequence++,
        user: args.user || userFabricator(),
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

function channelFabricator(args = {}) {
  const id = args.id || sequence++;

  const channel = ChatChannel.create(
    Object.assign(
      {
        id,
        chatable_type:
          args.chatable?.type ||
          args.chatable_type ||
          CHATABLE_TYPES.categoryChannel,
        chatable_id: args.chatable?.id || args.chatable_id,
        title: args.title || "General",
        description: args.description,
        chatable: args.chatable || categoryFabricator(),
        status: CHANNEL_STATUSES.open,
        slug: args.chatable?.slug || "general",
      },
      args
    )
  );

  channel.lastMessage = messageFabricator({ channel });

  return channel;
}

function categoryFabricator(args = {}) {
  return Category.create({
    id: args.id || sequence++,
    color: args.color || "D56353",
    read_restricted: false,
    name: args.name || "General",
    slug: args.slug || "general",
  });
}

function directMessageFabricator(args = {}) {
  return ChatDirectMessage.create({
    id: args.id || sequence++,
    users: args.users || [userFabricator(), userFabricator()],
  });
}

function directMessageChannelFabricator(args = {}) {
  const directMessage =
    args.chatable ||
    directMessageFabricator({
      id: args.chatable_id || sequence++,
    });

  return channelFabricator(
    Object.assign(args, {
      chatable_type: CHATABLE_TYPES.directMessageChannel,
      chatable_id: directMessage.id,
      chatable: directMessage,
    })
  );
}

function userFabricator(args = {}) {
  return User.create({
    id: args.id || sequence++,
    username: args.username || "hawk",
    name: args.name,
    avatar_template: "/letter_avatar_proxy/v3/letter/t/41988e/{size}.png",
    suspended_till: args.suspended_till,
  });
}

function bookmarkFabricator(args = {}) {
  return Bookmark.create({
    id: args.id || sequence++,
  });
}

function threadFabricator(args = {}) {
  const channel = args.channel || channelFabricator();
  return ChatThread.create(channel, {
    id: args.id || sequence++,
    original_message: args.original_message || messageFabricator({ channel }),
    preview: args.preview || threadPreviewFabricator({ channel }),
  });
}
function threadPreviewFabricator(args = {}) {
  return ChatThreadPreview.create({
    last_reply_id: args.last_reply_id || sequence++,
    last_reply_created_at: args.last_reply_created_at || Date.now(),
    last_reply_excerpt: args.last_reply_excerpt || "This is a reply",
  });
}

function reactionFabricator(args = {}) {
  return ChatMessageReaction.create({
    count: args.count || 1,
    users: args.users || [userFabricator()],
    emoji: args.emoji || "heart",
    reacted: args.reacted || false,
  });
}

function groupFabricator(args = {}) {
  return Group.create({
    name: args.name || "Engineers",
  });
}

function messageMentionWarningFabricator(message, args = {}) {
  return ChatMessageMentionWarning.create(message, args);
}

function uploadFabricator() {
  return {
    extension: "jpeg",
    filesize: 126177,
    height: 800,
    human_filesize: "123 KB",
    id: 202,
    original_filename: "avatar.PNG.jpg",
    retain_hours: null,
    short_path: "/images/avatar.png",
    short_url: "upload://yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
    thumbnail_height: 320,
    thumbnail_width: 690,
    url: "/images/avatar.png",
    width: 1920,
  };
}

export default {
  bookmark: bookmarkFabricator,
  user: userFabricator,
  channel: channelFabricator,
  directMessageChannel: directMessageChannelFabricator,
  message: messageFabricator,
  thread: threadFabricator,
  threadPreview: threadPreviewFabricator,
  reaction: reactionFabricator,
  upload: uploadFabricator,
  category: categoryFabricator,
  directMessage: directMessageFabricator,
  messageMentionWarning: messageMentionWarningFabricator,
  group: groupFabricator,
};
