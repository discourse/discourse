import { schedule } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { replaceSpan } from "discourse/lib/category-hashtags";
import { TAG_HASHTAG_POSTFIX } from "discourse/lib/tag-hashtags";

const validTagHashtags = {};
const checkedTagHashtags = [];
const testedClass = "hashtag-tag-tested";

function updateFound($hashtags, tagValues) {
  schedule("afterRender", () => {
    $hashtags.each((index, hashtag) => {
      const tagValue = tagValues[index];
      const link = validTagHashtags[tagValue];
      const $hashtag = $(hashtag);

      if (link) {
        if (!$hashtag.data("type") || $hashtag.data("type") === "tag") {
          replaceSpan($hashtag, tagValue, link, $hashtag.data("type"));
        }
      } else if (checkedTagHashtags.indexOf(tagValue) !== -1) {
        $hashtag.addClass(testedClass);
      }
    });
  });
}

export function linkSeenTagHashtags($elem) {
  const $hashtags = $(`span.hashtag:not(.${testedClass})`, $elem);
  const unseen = [];

  if ($hashtags.length) {
    const tagValues = $hashtags.map((_, hashtag) => {
      let text = $(hashtag).text();
      if (text.endsWith(TAG_HASHTAG_POSTFIX)) {
        text = text.slice(0, -TAG_HASHTAG_POSTFIX.length);
        $(hashtag).data("type", "tag");
      }
      return text.substr(1);
    });

    if (tagValues.length) {
      _.uniq(tagValues).forEach(tagValue => {
        if (checkedTagHashtags.indexOf(tagValue) === -1) unseen.push(tagValue);
      });
    }
    updateFound($hashtags, tagValues);
  }

  return unseen;
}

export function fetchUnseenTagHashtags(tagValues) {
  return ajax("/tags/check", { data: { tag_values: tagValues } }).then(
    response => {
      response.valid.forEach(tag => {
        validTagHashtags[tag.value] = tag.url;
      });
      checkedTagHashtags.push.apply(checkedTagHashtags, tagValues);
    }
  );
}
