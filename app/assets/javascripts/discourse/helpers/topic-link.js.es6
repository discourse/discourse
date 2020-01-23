import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("topic-link", (topic, args) => {
  const title = topic.get("fancyTitle");
  const linkedPostNumber = (topic.linked_post_number || args.postNumberToLink);
  const url = linkedPostNumber
    ? topic.urlForPostNumber(linkedPostNumber)
    : topic.get("lastUnreadUrl");

  const classes = ["title"];
  if (args.class) {
    args.class.split(" ").forEach(c => classes.push(c));
  }

  const result = `<a href='${url}'
                     class='${classes.join(" ")}'
                     data-topic-id='${topic.id}'>${title}</a>`;
  return new Handlebars.SafeString(result);
});
