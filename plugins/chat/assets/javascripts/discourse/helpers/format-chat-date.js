import { htmlSafe } from "@ember/template";
import getURL from "discourse/lib/get-url";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default function formatChatDate(message, options = {}) {
  const currentUser = User.current();
  const tz = currentUser ? currentUser.user_option.timezone : moment.tz.guess();
  const date = moment(new Date(message.createdAt), tz);

  const title = date.format(i18n("dates.long_with_year"));
  let display;
  if (options.mode === "tiny") {
    display = date.format(i18n("dates.time_short"));
  } else if (options.mode === "short") {
    display = date.format(i18n("dates.time_short_day"));
  } else if (options.mode === "long") {
    display = date.format(i18n("dates.long_no_year"));
  } else {
    display = date.format(i18n("dates.time"));
  }

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
