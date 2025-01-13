import { cancel } from "@ember/runloop";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { CANCELLED_STATUS } from "discourse/lib/autocomplete";
import { SEPARATOR } from "discourse/lib/category-hashtags";
import discourseDebounce from "discourse/lib/debounce";
import discourseLater from "discourse/lib/later";
import { TAG_HASHTAG_POSTFIX } from "discourse/lib/tag-hashtags";
import Category from "discourse/models/category";
import { isTesting } from "discourse-common/config/environment";

let cache = {};
let cacheTime;
let oldSearch;

function updateCache(term, results) {
  cache[term] = results;
  cacheTime = new Date();
  return results;
}

function searchFunc(q, limit, cats, resultFunc) {
  oldSearch = ajax("/tags/filter/search", {
    data: { limit, q },
  });

  let returnVal = CANCELLED_STATUS;

  oldSearch
    .then((r) => {
      const categoryNames = cats.map((c) => c.model.get("name"));

      const tags = r.results.map((tag) => {
        tag.text = categoryNames.includes(tag.text)
          ? `${tag.text}${TAG_HASHTAG_POSTFIX}`
          : tag.text;
        return tag;
      });

      returnVal = cats.concat(tags);
    })
    .finally(() => {
      oldSearch = null;
      resultFunc(returnVal);
    });
}

function searchTags(term, categories, limit) {
  return new Promise((resolve) => {
    let clearPromise = isTesting()
      ? null
      : discourseLater(() => {
          resolve(CANCELLED_STATUS);
        }, 5000);

    discourseDebounce(
      this,
      searchFunc,
      term,
      limit,
      categories,
      (result) => {
        cancel(clearPromise);
        resolve(updateCache(term, result));
      },
      300
    );
  });
}

export function search(term, siteSettings) {
  if (oldSearch) {
    oldSearch.abort();
    oldSearch = null;
  }

  if (new Date() - cacheTime > 30000) {
    cache = {};
  }
  const cached = cache[term];
  if (cached) {
    return cached;
  }

  const limit = 5;
  let categories = Category.search(term, { limit });
  let numOfCategories = categories.length;

  categories = categories.map((category) => {
    return { model: category, text: Category.slugFor(category, SEPARATOR, 2) };
  });

  if (numOfCategories !== limit && siteSettings.tagging_enabled) {
    return searchTags(term, categories, limit - numOfCategories);
  } else {
    return updateCache(term, categories);
  }
}
