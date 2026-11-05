import { getAbsoluteURL } from "discourse/lib/get-url";

export default function eventCalendarDetails(event) {
  const description = event.description?.trim() ? event.description : null;
  const postUrl = event.post?.url ? getAbsoluteURL(event.post.url) : null;

  return [description, postUrl].filter(Boolean).join("\n");
}
