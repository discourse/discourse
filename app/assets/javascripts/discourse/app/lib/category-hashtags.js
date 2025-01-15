import deprecated from "discourse/lib/deprecated";
import { hashtagTriggerRule } from "discourse/lib/hashtag-autocomplete";

export const SEPARATOR = ":";

export function replaceSpan($elem, categorySlug, categoryLink, type) {
  type = type ? ` data-type="${type}"` : "";
  $elem.replaceWith(
    `<a href="${categoryLink}" class="hashtag"${type}>#<span>${categorySlug}</span></a>`
  );
}

export function categoryHashtagTriggerRule(textarea, opts) {
  deprecated(
    "categoryHashtagTriggerRule is being replaced by hashtagTriggerRule and the new hashtag-autocomplete plugin APIs",
    {
      since: "2.9.0.beta10",
      dropFrom: "3.0.0.beta1",
      id: "discourse.category-hashtags.categoryHashtagTriggerRule",
    }
  );
  return hashtagTriggerRule(textarea, opts);
}
