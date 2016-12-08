import { CANCELLED_STATUS } from 'discourse/lib/autocomplete';
import Category from 'discourse/models/category';

var cache = {};
var cacheTime;
var oldSearch;

function updateCache(term, results) {
  cache[term] = results;
  cacheTime = new Date();
  return results;
}

function searchTags(term, categories, limit) {
  return new Ember.RSVP.Promise((resolve) => {
    const clearPromise = setTimeout(() => {
      resolve(CANCELLED_STATUS);
    }, 5000);

    const debouncedSearch = _.debounce((q, cats, resultFunc) => {
      oldSearch = $.ajax(Discourse.getURL("/tags/filter/search"), {
        type: 'GET',
        cache: true,
        data: { limit: limit, q }
      });

      var returnVal = CANCELLED_STATUS;

      oldSearch.then((r) => {
        var tags = r.results.map((tag) => { return { text: tag.text, count: tag.count }; });
        returnVal = cats.concat(tags);
      }).always(() => {
        oldSearch = null;
        resultFunc(returnVal);
      });
    }, 300);

    debouncedSearch(term, categories, (result) => {
      clearTimeout(clearPromise);
      resolve(updateCache(term, result));
    });
  });
};

export function search(term, siteSettings) {
  if (oldSearch) {
    oldSearch.abort();
    oldSearch = null;
  }

  if ((new Date() - cacheTime) > 30000) cache = {};
  const cached = cache[term];
  if (cached) return cached;

  const limit = 5;
  var categories = Category.search(term, { limit });
  var numOfCategories = categories.length;
  categories = categories.map((category) => { return { model: category }; });

  if (numOfCategories !== limit && siteSettings.tagging_enabled) {
    return searchTags(term, categories, limit - numOfCategories);
  } else {
    return updateCache(term, categories);
  }
};
