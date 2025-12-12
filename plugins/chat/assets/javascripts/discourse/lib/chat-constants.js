export const PAST = "past";
export const FUTURE = "future";
export const READ_INTERVAL_MS = 1000;
export const DEFAULT_MESSAGE_PAGE_SIZE = 50;
export const THREAD_TITLE_PROMPT_THRESHOLD = 5;
export const FOOTER_NAV_ROUTES = [
  "chat.starred-channels",
  "chat.direct-messages",
  "chat.channels",
  "chat.threads",
];
export const INDICATOR_PREFERENCES = {
  all_new: "all_new",
  dm_and_mentions: "dm_and_mentions",
  only_mentions: "only_mentions",
  never: "never",
};
export const CHAT_ATTRS = [
  "chat_enabled",
  "only_chat_push_notifications",
  "ignore_channel_wide_mention",
  "show_thread_title_prompts",
  "chat_sound",
  "chat_email_frequency",
  "chat_header_indicator_preference",
  "chat_separate_sidebar_mode",
  "chat_send_shortcut",
  "chat_quick_reaction_type",
  "chat_quick_reactions_custom",
];

export const CHAT_QUICK_REACTIONS_CUSTOM_DEFAULT = "heart|+1|smile";

export const HEADER_INDICATOR_PREFERENCE_NEVER = "never";
export const HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS = "dm_and_mentions";
export const HEADER_INDICATOR_PREFERENCE_ALL_NEW = "all_new";
export const HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS = "only_mentions";
