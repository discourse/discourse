export function getUserChatSeparateSidebarMode(
  user,
  siteSettings = user?.siteSettings
) {
  let mode = user?.get("user_option.chat_separate_sidebar_mode");
  if (!mode || mode === "default") {
    mode = siteSettings?.chat_separate_sidebar_mode;
  }

  return {
    never: "never" === mode,
    always: "always" === mode,
    fullscreen: "fullscreen" === mode,
  };
}
