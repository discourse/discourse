import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import User from "discourse/models/user";

registerUnbound("format-chat-date", function (message, mode) {
  const currentUser = User.current();
  const tz = currentUser ? currentUser.user_option.timezone : moment.tz.guess();
  const date = moment(new Date(message.created_at), tz);
  const url = getURL(`/chat/c/-/${message.chat_channel_id}/${message.id}`);
  const title = date.format(I18n.t("dates.long_with_year"));

  const display =
    mode === "tiny"
      ? date.format(I18n.t("chat.dates.time_tiny"))
      : date.format(I18n.t("dates.time"));

  return htmlSafe(
    `<a title='${title}' class='chat-time' href='${url}'>${display}</a>`
  );
});
