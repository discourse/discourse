import { trustHTML } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default function dTopicLink(topic, args = {}) {
  const title = topic.get("fancyTitle");
  const readIndicator = topic.get("visited")
    ? `<span class="sr-only">&nbsp;${escapeExpression(i18n("topic.sr_read"))}</span>`
    : "";

  const url = topic.linked_post_number
    ? topic.urlForPostNumber(topic.linked_post_number)
    : topic.get("lastUnreadUrl");

  const classes = ["title"];

  if (args.class) {
    args.class.split(" ").forEach((c) => classes.push(c));
  }

  return trustHTML(
    `<a href='${url}'
        class='${classes.join(" ")}'
        data-topic-id='${topic.id}'>${title}${readIndicator}</a>`
  );
}
