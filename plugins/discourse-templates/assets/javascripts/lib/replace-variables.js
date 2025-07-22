import User from "discourse/models/user";

// keep this list synchronized with the list in spec/plugin_helper.rb
export const TEMPLATES_ALLOWED_VARIABLES = Object.freeze([
  "my_username",
  "my_name",
  "chat_channel_name",
  "chat_channel_url",
  "chat_thread_name",
  "chat_thread_url",
  "context_title",
  "context_url",
  "topic_title",
  "topic_url",
  "original_poster_username",
  "original_poster_name",
  "reply_to_username",
  "reply_to_name",
  "last_poster_username",
  "reply_to_or_last_poster_username",
]);

export function replaceVariables(title, content, modelVariables) {
  const currentUser = User.current();
  const variables = {
    ...(modelVariables || {}),
    my_username: currentUser?.username,
    my_name: currentUser?.displayName,
  };

  if (variables && typeof variables === "object") {
    for (const key of TEMPLATES_ALLOWED_VARIABLES) {
      if (variables[key]) {
        title = title.replace(
          new RegExp(`%{${key}(,fallback:.[^}]*)?}`, "g"),
          variables[key]
        );
        content = content.replace(
          new RegExp(`%{${key}(,fallback:.[^}]*)?}`, "g"),
          variables[key]
        );
      } else {
        title = title.replace(
          new RegExp(`%{${key},fallback:(.[^}]*)}`, "g"),
          "$1"
        );
        title = title.replace(new RegExp(`%{${key}}`, "g"), "");
        content = content.replace(
          new RegExp(`%{${key},fallback:(.[^}]*)}`, "g"),
          "$1"
        );
        content = content.replace(new RegExp(`%{${key}}`, "g"), "");
      }
    }
  }

  return { title, content };
}
