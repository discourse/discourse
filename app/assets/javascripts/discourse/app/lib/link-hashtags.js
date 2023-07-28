// TODO (martin) Delete this after core PR and any other PRs that depend
// on this file (e.g. discourse-encrypt) are merged.

import deprecated from "discourse-common/lib/deprecated";
import { TAG_HASHTAG_POSTFIX } from "discourse/lib/tag-hashtags";
import { ajax } from "discourse/lib/ajax";
import { replaceSpan } from "discourse/lib/category-hashtags";
import jQuery from "jquery";

const categoryHashtags = {};
const tagHashtags = {};
const checkedHashtags = new Set();

export function linkSeenHashtags(elem) {
  if (elem instanceof jQuery) {
    elem = elem[0];

    deprecated("linkSeenHashtags now expects a DOM node as first parameter", {
      since: "2.8.0.beta7",
      dropFrom: "2.9.0.beta1",
      id: "discourse.link-hashtags.dom-node",
    });
  }

  const hashtags = [...(elem?.querySelectorAll("span.hashtag") || [])];
  if (hashtags.length === 0) {
    return [];
  }
  const slugs = [...hashtags.map((hashtag) => hashtag.innerText.slice(1))];

  hashtags.forEach((hashtag, index) => {
    let slug = slugs[index];
    const hasTagSuffix = slug.endsWith(TAG_HASHTAG_POSTFIX);
    if (hasTagSuffix) {
      slug = slug.slice(0, slug.length - TAG_HASHTAG_POSTFIX.length);
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
