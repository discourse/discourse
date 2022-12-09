import ChatChannel, {
  CHATABLE_TYPES,
} from "discourse/plugins/chat/discourse/models/chat-channel";
import EmberObject from "@ember/object";
import { Fabricator } from "./fabricator";

const userFabricator = Fabricator(EmberObject, {
  id: 1,
  username: "hawk",
  name: null,
  avatar_template: "/letter_avatar_proxy/v3/letter/t/41988e/{size}.png",
});

const categoryChatableFabricator = Fabricator(EmberObject, {
  id: 1,
  color: "D56353",
  read_restricted: false,
  name: "My category",
});

const directChannelChatableFabricator = Fabricator(EmberObject, {
  users: [userFabricator({ id: 1, username: "bob" })],
});

export default {
  chatChannel: Fabricator(ChatChannel, {
    id: 1,
    chatable_type: CHATABLE_TYPES.categoryChannel,
    status: "open",
    title: "My category title",
    name: "My category name",
    chatable: categoryChatableFabricator(),
    last_message_sent_at: "2021-11-08T21:26:05.710Z",
    allow_channel_wide_mentions: true,
    message_bus_last_ids: {
      new_mentions: 0,
      new_messages: 0,
    },
  }),

  chatChannelMessage: Fabricator(EmberObject, {
    id: 1,
    chat_channel_id: 1,
    user_id: 1,
    cooked: "This is a test message",
  }),

  directMessageChatChannel: Fabricator(ChatChannel, {
    id: 1,
    chatable_type: CHATABLE_TYPES.directMessageChannel,
    status: "open",
    chatable: directChannelChatableFabricator(),
    last_message_sent_at: "2021-11-08T21:26:05.710Z",
    message_bus_last_ids: {
      new_mentions: 0,
      new_messages: 0,
    },
  }),
};
