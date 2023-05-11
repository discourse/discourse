import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import User from "discourse/models/user";

registerUnbound("format-chat-date", function (message, mode) {
  const currentUser = User.current();
  const tz = currentUser ? currentUser.user_option.timezone : moment.tz.guess();
  const date = moment(new Date(message.createdAt), tz);

  const title = date.format(I18n.t("dates.long_with_year"));
  const display =
    mode === "tiny"
      ? date.format(I18n.t("chat.dates.time_tiny"))
      : date.format(I18n.t("dates.time"));

  if (message.staged) {
    return htmlSafe(
      `<span title='${title}' tabindex="-1" class='chat-time'>${display}</span>`
    );
  } else {
    const url = getURL(`/chat/c/-/${message.channel.id}/${message.id}`);
    return htmlSafe(
      `<a title='${title}' tabindex="-1" class='chat-time' href='${url}'>${display}</a>`
    );
  }
});
