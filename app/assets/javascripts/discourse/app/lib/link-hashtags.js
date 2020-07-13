import { schedule } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { replaceSpan } from "discourse/lib/category-hashtags";
import { TAG_HASHTAG_POSTFIX } from "discourse/lib/tag-hashtags";

const categoryHashtags = {};
const tagHashtags = {};
const checkedHashtags = new Set();

export function linkSeenHashtags($elem) {
  const $hashtags = $elem.find("span.hashtag");
  if ($hashtags.length === 0) {
    return [];
  }

  const slugs = [...$hashtags.map((_, hashtag) => hashtag.innerText.substr(1))];

  schedule("afterRender", () => {
    $hashtags.each((index, hashtag) => {
      let slug = slugs[index];
      const hasTagSuffix = slug.endsWith(TAG_HASHTAG_POSTFIX);
      if (hasTagSuffix) {
        slug = slug.substr(0, slug.length - TAG_HASHTAG_POSTFIX.length);
      }

      if (categoryHashtags[slug] && !hasTagSuffix) {
        replaceSpan($(hashtag), slug, categoryHashtags[slug]);
      } else if (tagHashtags[slug]) {
        replaceSpan($(hashtag), slug, tagHashtags[slug]);
      }
    });
  });

  return slugs.uniq().filter(slug => !checkedHashtags.has(slug));
}

export function fetchUnseenHashtags(slugs) {
  return ajax("/hashtags", {
    data: { slugs }
  }).then(response => {
    Object.keys(response.categories).forEach(slug => {
      categoryHashtags[slug] = response.categories[slug];
    });

    Object.keys(response.tags).forEach(slug => {
      tagHashtags[slug] = response.tags[slug];
    });

    slugs.forEach(checkedHashtags.add, checkedHashtags);
  });
}
