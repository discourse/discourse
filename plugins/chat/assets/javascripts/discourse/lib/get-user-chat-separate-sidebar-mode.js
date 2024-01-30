export function getUserChatSeparateSidebarMode(user) {
  let mode = user?.get("user_option.chat_separate_sidebar_mode");
  if (mode === "default") {
    mode = user.siteSettings.chat_separate_sidebar_mode;
  }

  return {
    never: "never" === mode,
    always: "always" === mode,
    fullscreen: "fullscreen" === mode,
  };
}
