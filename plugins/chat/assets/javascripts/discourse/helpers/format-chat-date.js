import { htmlSafe } from "@ember/template";
import User from "discourse/models/user";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

export default function formatChatDate(message, options = {}) {
  const currentUser = User.current();
  const tz = currentUser ? currentUser.user_option.timezone : moment.tz.guess();
  const date = moment(new Date(message.createdAt), tz);

  const title = date.format(I18n.t("dates.long_with_year"));
  const display =
    options.mode === "tiny"
      ? date.format(I18n.t("dates.time_short"))
      : date.format(I18n.t("dates.time"));

  if (message.staged) {
    return htmlSafe(
      `<span title='${title}' tabindex="-1" class='chat-time'>${display}</span>`
    );
  } else {
    let url;
    if (options.threadContext) {
      url = getURL(
        `/chat/c/-/${message.channel.id}/t/${message.thread.id}/${message.id}`
      );
    } else {
      url = getURL(`/chat/c/-/${message.channel.id}/${message.id}`);
    }

    return htmlSafe(
      `<a title='${title}' tabindex="-1" class='chat-time' href='${url}'>${display}</a>`
    );
  }
}
