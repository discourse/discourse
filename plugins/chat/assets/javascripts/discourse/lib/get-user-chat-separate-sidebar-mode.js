export function getUserChatSeparateSidebarMode(user) {
  const mode = user.get("user_option.chat_separate_sidebar_mode");

  return {
    never: "never" === mode,
    always: "always" === mode,
    fullscreen: "fullscreen" === mode,
  };
}
