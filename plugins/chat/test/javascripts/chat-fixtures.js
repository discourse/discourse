import { deepMerge } from "discourse/lib/object";

export const messageContents = ["Hello world", "What up", "heyo!"];

export const directMessageChannels = [
  {
    chat_channel: {
      chatable: {
        users: [
          {
            id: 1,
            username: "markvanlan",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/f9ae1b/{size}.png",
          },
          {
            id: 2,
            username: "hawk",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/f9ae1b/{size}.png",
          },
        ],
      },
      chatable_id: 58,
      chatable_type: "DirectMessage",
      chatable_url: null,
      id: 75,
      title: "@hawk",
      current_user_membership: {
        muted: false,
        following: true,
      },
      allow_channel_wide_mentions: true,
      last_message: { id: 333, created_at: "2021-07-02T08:14:16.950Z" },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    },
  },
  {
    chat_channel: {
      chatable: {
        users: [
          {
            id: 1,
            username: "markvanlan",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/f9ae1b/{size}.png",
          },
          {
            id: 3,
            username: "eviltrout",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/f9ae1b/{size}.png",
          },
        ],
      },
      chatable_id: 59,
      chatable_type: "DirectMessage",
      chatable_url: null,
      id: 76,
      title: "@eviltrout, @markvanlan",
      current_user_membership: {
        muted: false,
        following: true,
      },
      allow_channel_wide_mentions: true,
      last_message: { id: 333, created_at: "2021-07-02T08:14:16.950Z" },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    },
  },
];

const chatables = {
  1: {
    id: 1,
    name: "Bug",
    color: "0088CC",
    text_color: "FFFFFF",
    slug: "bug",
  },
  8: {
    id: 8,
    name: "Public category",
    slug: "public-category",
    posts_count: 1,
  },
  12: {
    id: 12,
    name: "Another category",
    slug: "another-category",
    posts_count: 100,
  },
};

export const chatChannels = {
  public_channels: [
    {
      id: 9,
      chatable_id: 1,
      chatable_type: "Category",
      chatable_url: "/c/bug/1",
      title: "Site",
      status: "open",
      chatable: chatables[1],
      allow_channel_wide_mentions: true,
      last_message: { id: 333, created_at: "2021-07-02T08:14:16.950Z" },
      current_user_membership: {
        muted: false,
        following: true,
      },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    },
    {
      id: 7,
      chatable_id: 1,
      chatable_type: "Category",
      chatable_url: "/c/bug/1",
      title: "Bug",
      status: "open",
      chatable: chatables[1],
      allow_channel_wide_mentions: true,
      last_message: { id: 333, created_at: "2021-07-02T08:14:16.950Z" },
      current_user_membership: {
        muted: false,
        following: true,
      },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    },
    {
      id: 4,
      chatable_id: 8,
      chatable_type: "Category",
      chatable_url: "/c/public-category/8",
      title: "Public category",
      status: "open",
      chatable: chatables[8],
      allow_channel_wide_mentions: true,
      last_message: { id: 333, created_at: "2021-07-02T08:14:16.950Z" },
      current_user_membership: {
        muted: false,
        following: true,
      },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    },
    {
      id: 5,
      chatable_id: 8,
      chatable_type: "Category",
      chatable_url: "/c/public-category/8",
      title: "Public category (read-only)",
      status: "read_only",
      chatable: chatables[8],
      allow_channel_wide_mentions: true,
      last_message: { id: 333, created_at: "2021-07-02T08:14:16.950Z" },
      current_user_membership: {
        muted: false,
        following: true,
      },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    },
    {
      id: 6,
      chatable_id: 8,
      chatable_type: "Category",
      chatable_url: "/c/public-category/8",
      title: "Public category (closed)",
      status: "closed",
      chatable: chatables[8],
      allow_channel_wide_mentions: true,
      last_message: { id: 333, created_at: "2021-07-02T08:14:16.950Z" },
      current_user_membership: {
        muted: false,
        following: true,
      },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    },
    {
      id: 10,
      chatable_id: 8,
      chatable_type: "Category",
      chatable_url: "/c/public-category/8",
      title: "Public category (archived)",
      status: "archived",
      chatable: chatables[8],
      allow_channel_wide_mentions: true,
      last_message: { id: 333, created_at: "2021-07-02T08:14:16.950Z" },
      current_user_membership: {
        muted: false,
        following: true,
      },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    },
    {
      id: 11,
      chatable_id: 12,
      chatable_type: "Category",
      chatable_url: "/c/another-category/12",
      title: "Another Category",
      status: "open",
      chatable: chatables[12],
      allow_channel_wide_mentions: true,
      last_message: { id: 333, created_at: "2021-07-02T08:14:16.950Z" },
      current_user_membership: {
        muted: false,
        following: true,
      },
      message_bus_last_ids: {
        new_mentions: 0,
        new_messages: 0,
      },
    },
  ],
  tracking: {
    channel_tracking: {
      4: { unread_count: 0, mention_count: 0 },
      5: { unread_count: 0, mention_count: 0 },
      6: { unread_count: 0, mention_count: 0 },
      7: { unread_count: 0, mention_count: 0 },
      9: { unread_count: 0, mention_count: 0 },
      10: { unread_count: 0, mention_count: 0 },
      11: { unread_count: 0, mention_count: 0 },
      75: { unread_count: 0, mention_count: 0 },
      76: { unread_count: 0, mention_count: 0 },
    },
    thread_tracking: {},
  },
  direct_message_channels: directMessageChannels.mapBy("chat_channel"),
  message_bus_last_ids: {
    channel_metadata: 0,
    channel_edits: 0,
    channel_status: 0,
    new_channel: 0,
    user_tracking_state: 0,
  },
};

const message0 = {
  id: 174,
  message: messageContents[0],
  cooked: messageContents[0],
  excerpt: messageContents[0],
  created_at: "2021-07-20T08:14:16.950Z",
  flag_count: 0,
  user: {
    id: 1,
    username: "markvanlan",
    name: null,
    avatar_template: "/letter_avatar_proxy/v4/letter/m/48db29/{size}.png",
  },
  available_flags: ["spam"],
};

const message1 = {
  id: 175,
  message: messageContents[1],
  cooked: messageContents[1],
  excerpt: messageContents[1],
  created_at: "2021-07-20T08:14:22.043Z",
  flag_count: 0,
  user: {
    id: 2,
    username: "hawk",
    name: null,
    avatar_template: "/letter_avatar_proxy/v4/letter/m/48db29/{size}.png",
  },
  in_reply_to: message0,
  uploads: [
    {
      extension: "pdf",
      filesize: 861550,
      height: null,
      human_filesize: "841 KB",
      id: 38,
      original_filename: "Chat message PDF!",
      retain_hours: null,
      short_path: "/uploads/short-url/vYozObYao54I6G3x8wvOf73epfX.pdf",
      short_url: "upload://vYozObYao54I6G3x8wvOf73epfX.pdf",
      thumbnail_height: null,
      thumbnail_width: null,
      url: "/images/avatar.png",
      width: null,
    },
  ],
  available_flags: ["spam"],
};

const message2 = {
  id: 176,
  message: messageContents[2],
  cooked: messageContents[2],
  excerpt: messageContents[2],
  created_at: "2021-07-20T08:14:25.043Z",
  flag_count: 0,
  user: {
    id: 2,
    username: "hawk",
    name: null,
    avatar_template: "/letter_avatar_proxy/v4/letter/m/48db29/{size}.png",
  },
  in_reply_to: message0,
  uploads: [
    {
      extension: "png",
      filesize: 50419,
      height: 393,
      human_filesize: "49.2 KB",
      id: 37,
      original_filename: "image.png",
      retain_hours: null,
      short_path: "/uploads/short-url/2LbadI7uOM7JsXyVoc12dHUjJYo.png",
      short_url: "upload://2LbadI7uOM7JsXyVoc12dHUjJYo.png",
      thumbnail_height: 224,
      thumbnail_width: 689,
      url: "/images/avatar.png",
      width: 1209,
    },
  ],
  reactions: {
    heart: {
      count: 1,
      reacted: false,
      users: [{ id: 99, username: "im-penar" }],
    },
    kiwi_fruit: {
      count: 2,
      reacted: true,
      users: [{ id: 99, username: "im-penar" }],
    },
    tada: {
      count: 1,
      reacted: true,
      users: [],
    },
  },
  available_flags: ["spam"],
};

const message3 = {
  id: 177,
  message: "gg @osama @mark @here",
  cooked:
    '<p>gg <a class="mention" href="/u/osama">@osama</a> <a class="mention" href="/u/mark">@mark</a> <a class="mention" href="/u/here">@here</a></p>',
  excerpt:
    '<p>gg <a class="mention" href="/u/osama">@osama</a> <a class="mention" href="/u/mark">@mark</a> <a class="mention" href="/u/here">@here</a></p>',
  created_at: "2021-07-22T08:14:16.950Z",
  flag_count: 0,
  user: {
    id: 1,
    username: "markvanlan",
    name: null,
    avatar_template: "/letter_avatar_proxy/v4/letter/m/48db29/{size}.png",
  },
  available_flags: ["spam"],
};

export function generateChatView(loggedInUser, metaOverrides = {}) {
  const metaDefaults = {
    can_flag: true,
    user_silenced: false,
    can_moderate: loggedInUser.staff,
    can_delete_self: true,
    can_delete_others: loggedInUser.staff,
  };
  return {
    meta: deepMerge(metaDefaults, metaOverrides),
    chat_messages: [message0, message1, message2, message3],
  };
}
