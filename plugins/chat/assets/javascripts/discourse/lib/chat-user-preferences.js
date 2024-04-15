import {
  HEADER_INDICATOR_PREFERENCE_ALL_NEW,
  HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
  HEADER_INDICATOR_PREFERENCE_NEVER,
  HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
} from "discourse/plugins/chat/discourse/controllers/preferences-chat";

export function hasChatIndicator(user) {
  const pref = user.user_option.chat_header_indicator_preference;

  return {
    ALL_NEW: pref === HEADER_INDICATOR_PREFERENCE_ALL_NEW,
    DM_AND_MENTIONS: pref === HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
    ONLY_MENTIONS: pref === HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
    NEVER: pref === HEADER_INDICATOR_PREFERENCE_NEVER,
  };
}
