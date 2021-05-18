import { TAG_HASHTAG_POSTFIX } from "discourse/lib/tag-hashtags";
import { ajax } from "discourse/lib/ajax";
import { replaceSpan } from "discourse/lib/category-hashtags";

const categoryHashtags = {};
const tagHashtags = {};
const checkedHashtags = new Set();

export function linkSeenHashtags($elem) {
  const $hashtags = $elem.find("span.hashtag");
  if ($hashtags.length === 0) {
    return [];
  }

  const slugs = [...$hashtags.map((_, hashtag) => hashtag.innerText.substr(1))];

  $hashtags.each((index, hashtag) => {
    let slug = slugs[index];
    const hasTagSuffix = slug.endsWith(TAG_HASHTAG_POSTFIX);
    if (hasTagSuffix) {
      slug = slug.substr(0, slug.length - TAG_HASHTAG_POSTFIX.length);
    }

    const lowerSlug = slug.toLowerCase();
    if (categoryHashtags[lowerSlug] && !hasTagSuffix) {
      replaceSpan($(hashtag), slug, categoryHashtags[lowerSlug]);
    } else if (tagHashtags[lowerSlug]) {
      replaceSpan($(hashtag), slug, tagHashtags[lowerSlug]);
    }
  });

  return slugs
    .map((slug) => slug.toLowerCase())
    .uniq()
    .filter((slug) => !checkedHashtags.has(slug));
}

export function fetchUnseenHashtags(slugs) {
  return ajax("/hashtags", {
    data: { slugs },
  }).then((response) => {
    Object.keys(response.categories).forEach((slug) => {
      categoryHashtags[slug] = response.categories[slug];
    });

    Object.keys(response.tags).forEach((slug) => {
      tagHashtags[slug] = response.tags[slug];
    });

    slugs.forEach(checkedHashtags.add, checkedHashtags);
  });
}
