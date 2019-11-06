import { schedule } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { replaceSpan } from "discourse/lib/category-hashtags";

const validCategoryHashtags = {};
const checkedCategoryHashtags = [];
const testedKey = "tested";
const testedClass = `hashtag-${testedKey}`;

function updateFound($hashtags, categorySlugs) {
  schedule("afterRender", () => {
    $hashtags.each((index, hashtag) => {
      const categorySlug = categorySlugs[index];
      const link = validCategoryHashtags[categorySlug];
      const $hashtag = $(hashtag);

      if (link) {
        replaceSpan($hashtag, categorySlug, link);
      } else if (checkedCategoryHashtags.indexOf(categorySlug) !== -1) {
        $hashtag.addClass(testedClass);
      }
    });
  });
}

export function linkSeenCategoryHashtags($elem) {
  const $hashtags = $(`span.hashtag:not(.${testedClass})`, $elem);
  const unseen = [];

  if ($hashtags.length) {
    const categorySlugs = $hashtags.map((_, hashtag) =>
      $(hashtag)
        .text()
        .substr(1)
    );
    if (categorySlugs.length) {
      _.uniq(categorySlugs).forEach(categorySlug => {
        if (checkedCategoryHashtags.indexOf(categorySlug) === -1) {
          unseen.push(categorySlug);
        }
      });
    }
    updateFound($hashtags, categorySlugs);
  }

  return unseen;
}

export function fetchUnseenCategoryHashtags(categorySlugs) {
  return ajax("/category_hashtags/check", {
    data: { category_slugs: categorySlugs }
  }).then(response => {
    response.valid.forEach(category => {
      validCategoryHashtags[category.slug] = category.url;
    });
    checkedCategoryHashtags.push.apply(checkedCategoryHashtags, categorySlugs);
  });
}
