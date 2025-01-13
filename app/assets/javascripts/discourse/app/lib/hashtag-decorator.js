import { ajax } from "discourse/lib/ajax";
import domFromString from "discourse/lib/dom-from-string";
import { getHashtagTypeClasses } from "discourse/lib/hashtag-type-registry";
import { emojiUnescape } from "discourse/lib/text";

const checkedHashtags = new Set();
let seenHashtags = {};

// NOTE: For future maintainers, the hashtag lookup here does not take
// into account mixed contexts -- for instance, a chat quote inside a post
// or a post quote inside a chat message, so this may
// not provide an accurate priority lookup for hashtags without a ::type suffix in those
// cases.
export function fetchUnseenHashtagsInContext(
  contextualHashtagConfiguration,
  slugs
) {
  return ajax("/hashtags", {
    data: { slugs, order: contextualHashtagConfiguration },
  }).then((response) => {
    Object.keys(response).forEach((type) => {
      seenHashtags[type] = seenHashtags[type] || {};
      response[type].forEach((item) => {
        seenHashtags[type][item.ref] = seenHashtags[type][item.ref] || item;
      });
    });
    slugs.forEach(checkedHashtags.add, checkedHashtags);
  });
}

export function linkSeenHashtagsInContext(
  contextualHashtagConfiguration,
  elem
) {
  const hashtagSpans = [...(elem?.querySelectorAll("span.hashtag-raw") || [])];
  if (hashtagSpans.length === 0) {
    return [];
  }
  const slugs = [
    ...hashtagSpans.map((span) => span.innerText.replace("#", "")),
  ];

  hashtagSpans.forEach((hashtagSpan, index) => {
    _findAndReplaceSeenHashtagPlaceholder(
      slugs[index],
      contextualHashtagConfiguration,
      hashtagSpan
    );
  });

  return slugs
    .map((slug) => slug.toLowerCase())
    .uniq()
    .filter((slug) => !checkedHashtags.has(slug));
}

function _findAndReplaceSeenHashtagPlaceholder(
  slugRef,
  contextualHashtagConfiguration,
  hashtagSpan
) {
  contextualHashtagConfiguration.forEach((type) => {
    // Replace raw span for the hashtag with a cooked one
    const matchingSeenHashtag = seenHashtags[type]?.[slugRef];
    if (matchingSeenHashtag) {
      generatePlaceholderHashtagHTML(type, hashtagSpan, {
        preloaded: true,
        ...matchingSeenHashtag,
      });
    }
  });
}

export function generatePlaceholderHashtagHTML(type, spanEl, data) {
  // NOTE: When changing the HTML structure here, you must also change
  // it in the hashtag-autocomplete markdown rule, and vice-versa.
  const link = document.createElement("a");
  link.classList.add("hashtag-cooked");
  link.href = data.relative_url;
  link.dataset.type = type;
  link.dataset.id = data.id;
  link.dataset.slug = data.slug;
  const hashtagTypeClass = new getHashtagTypeClasses()[type];
  link.innerHTML = `${hashtagTypeClass.generateIconHTML(
    data
  )}<span>${emojiUnescape(data.text)}</span>`;
  spanEl.replaceWith(link);
}

export function decorateHashtags(element, site) {
  element.querySelectorAll(".hashtag-cooked").forEach((hashtagEl) => {
    // Replace the empty icon placeholder span with actual icon HTML.
    const iconPlaceholderEl = hashtagEl.querySelector(
      ".hashtag-icon-placeholder"
    );
    const hashtagType = hashtagEl.dataset.type;
    const hashtagTypeClass = getHashtagTypeClasses()[hashtagType];
    if (iconPlaceholderEl && hashtagTypeClass) {
      const hashtagIconHTML = hashtagTypeClass
        .generateIconHTML({
          icon: site.hashtag_icons[hashtagType],
          id: hashtagEl.dataset.id,
          slug: hashtagEl.dataset.slug,
        })
        .trim();
      iconPlaceholderEl.replaceWith(domFromString(hashtagIconHTML)[0]);
    }

    // Add an aria-label to the hashtag element so that screen readers
    // can read the hashtag text.
    hashtagEl.setAttribute("aria-label", `${hashtagEl.innerText.trim()}`);
  });
}
