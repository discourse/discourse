import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("topic-link", (topic, args) => {
  const title = topic.get("fancyTitle");

  const url = topic.linked_post_number
    ? topic.urlForPostNumber(topic.linked_post_number)
    : topic.get("lastUnreadUrl");

  const classes = ["title"];

  if (args.class) {
    args.class.split(" ").forEach((c) => classes.push(c));
  }

  return htmlSafe(
    `<a href='${url}'
        role='heading'
        level='2'
        class='${classes.join(" ")}'
        data-topic-id='${topic.id}'>${title}</a>`
  );
});
