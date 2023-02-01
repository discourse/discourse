import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import User from "discourse/models/user";

registerUnbound("format-chat-date", function (message, details, mode) {
  let currentUser = User.current();

  let tz = currentUser ? currentUser.user_option.timezone : moment.tz.guess();

  let date = moment(new Date(message.created_at), tz);

  let url = "";

  if (details) {
    url = getURL(`/chat/c/-/${details.chat_channel_id}/${message.id}`);
  }

  let title = date.format(I18n.t("dates.long_with_year"));

  let display =
    mode === "tiny"
      ? date.format(I18n.t("chat.dates.time_tiny"))
      : date.format(I18n.t("dates.time"));

  return htmlSafe(
    `<a title='${title}' class='chat-time' href='${url}'>${display}</a>`
  );
});
