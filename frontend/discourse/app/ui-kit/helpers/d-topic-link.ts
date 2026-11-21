import { trustHTML } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

/** The topic properties `dTopicLink` reads. */
export interface LinkedTopic {
  id: number;

  /** The post to link to, instead of the last unread one. */
  linked_post_number?: number | null;

  get(key: string): unknown;
  urlForPostNumber(postNumber: number): string;
}

/**
 * Renders a link to a topic, titled with its fancy title.
 *
 * @param topic - The topic.
 * @param args - The options.
 * @returns The link.
 */
export default function dTopicLink(
  topic: LinkedTopic,
  args: {
    /** Space-separated classes added after `title`. */
    class?: string;
  } = {}
) {
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
