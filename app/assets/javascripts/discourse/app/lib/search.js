import EmberObject from "@ember/object";
import { isEmpty } from "@ember/utils";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { search as searchCategoryTag } from "discourse/lib/category-tag-search";
import { emojiUnescape } from "discourse/lib/text";
import { userPath } from "discourse/lib/url";
import userSearch from "discourse/lib/user-search";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Post from "discourse/models/post";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";
import getURL from "discourse-common/lib/get-url";
import { deepMerge } from "discourse-common/lib/object";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import { i18n } from "discourse-i18n";

const translateResultsCallbacks = [];
const MAX_RECENT_SEARCHES = 5; // should match backend constant with the same name

const logSearchLinkClickedCallbacks = [];

export function addLogSearchLinkClickedCallbacks(fn) {
  logSearchLinkClickedCallbacks.push(fn);
}
export function resetLogSearchLinkClickedCallbacks() {
  logSearchLinkClickedCallbacks.clear();
}

export function addSearchResultsCallback(callback) {
  translateResultsCallbacks.push(callback);
}

export function translateResults(results, opts) {
  opts = opts || {};

  results.topics = results.topics || [];
  results.users = results.users || [];
  results.posts = results.posts || [];
  results.categories = results.categories || [];
  results.tags = results.tags || [];
  results.groups = results.groups || [];

  const topicMap = {};
  results.topics = results.topics.map(function (topic) {
    topic = Topic.create(topic);
    topicMap[topic.id] = topic;
    return topic;
  });

  results.posts = results.posts.map((post) => {
    if (post.username) {
      post.userPath = userPath(post.username.toLowerCase());
    }
    post = Post.create(post);
    post.set("topic", topicMap[post.topic_id]);
    post.blurb = emojiUnescape(post.blurb);
    return post;
  });

  results.users = results.users.map(function (user) {
    return User.create(user);
  });

  results.categories = results.categories
    .map(function (category) {
      return Category.list().findBy("id", category.id || category.model.id);
    })
    .compact();

  results.grouped_search_result?.extra?.categories?.forEach((category) =>
    Site.current().updateCategory(category)
  );

  results.groups = results.groups
    .map((group) => {
      const name = escapeExpression(group.name);
      const fullName = escapeExpression(group.full_name || group.display_name);
      const flairUrl = isEmpty(group.flair_url)
        ? null
        : escapeExpression(group.flair_url);
      const flairColor = escapeExpression(group.flair_color);
      const flairBgColor = escapeExpression(group.flair_bg_color);

      return {
        id: group.id,
        flairUrl,
        flairColor,
        flairBgColor,
        fullName,
        name,
        url: getURL(`/g/${name}`),
      };
    })
    .compact();

  results.tags = results.tags
    .map(function (tag) {
      const tagName = escapeExpression(tag.name);
      return EmberObject.create({
        id: tagName,
        url: getURL("/tag/" + tagName),
      });
    })
    .compact();

  return translateResultsCallbacks
    .reduce(
      (promise, callback) => promise.then((r) => callback(r)),
      Promise.resolve(results)
    )
    .then((results_) => {
      translateGroupedSearchResults(results_, opts);
      return EmberObject.create(results_);
    });
}

function translateGroupedSearchResults(results, opts) {
  results.resultTypes = [];
  const groupedSearchResult = results.grouped_search_result;
  if (groupedSearchResult) {
    [
      // We are defining the order that the result types will be
      // displayed in. We should make this customizable.
      ["topic", "posts"],
      ["category", "categories"],
      ["tag", "tags"],
      ["user", "users"],
      ["group", "groups"],
    ].forEach(function (pair) {
      const type = pair[0];
      const name = pair[1];
      if (results[name].length > 0) {
        const componentName =
          opts.searchContext?.type === "topic" && type === "topic"
            ? "post"
            : type;

        const result = {
          results: results[name],
          componentName: `search-result-${componentName}`,
          type,
          more: groupedSearchResult[`more_${name}`],
        };

        if (result.more && componentName === "topic" && opts.fullSearchUrl) {
          result.more = false;
          result.moreUrl = opts.fullSearchUrl;
        }

        results.resultTypes.push(result);
      }
    });
  }
}

export function searchForTerm(term, opts) {
  if (!opts) {
    opts = {};
  }

  // Only include the data we have
  const data = { term };
  if (opts.typeFilter) {
    data.type_filter = opts.typeFilter;
  }
  if (opts.searchForId) {
    data.search_for_id = true;
  }
  if (opts.restrictToArchetype) {
    data.restrict_to_archetype = opts.restrictToArchetype;
  }

  if (opts.searchContext) {
    data.search_context = {
      type: opts.searchContext.type,
      id: opts.searchContext.id,
      name: opts.searchContext.name,
    };
  }

  let ajaxPromise = ajax("/search/query", { data });
  const promise = ajaxPromise.then((res) => translateResults(res, opts));
  promise.abort = ajaxPromise.abort;
  return promise;
}

export function searchContextDescription(type, name) {
  if (type) {
    switch (type) {
      case "topic":
        return i18n("search.context.topic");
      case "user":
        return i18n("search.context.user", { username: name });
      case "category":
        return i18n("search.context.category", { category: name });
      case "tag":
        return i18n("search.context.tag", { tag: name });
      case "private_messages":
        return i18n("search.context.private_messages");
    }
  }
}

export function getSearchKey(args) {
  return (
    args.q +
    "|" +
    ((args.searchContext && args.searchContext.type) || "") +
    "|" +
    ((args.searchContext && args.searchContext.id) || "")
  );
}

export function isValidSearchTerm(searchTerm, siteSettings) {
  if (searchTerm) {
    return searchTerm.trim().length >= siteSettings.min_search_term_length;
  } else {
    return false;
  }
}

export function applySearchAutocomplete($input, siteSettings) {
  $input.autocomplete(
    deepMerge({
      template: findRawTemplate("category-tag-autocomplete"),
      key: "#",
      width: "100%",
      treatAsTextarea: true,
      autoSelectFirstSuggestion: false,
      transformComplete: (obj) => obj.text,
      dataSource: (term) => searchCategoryTag(term, siteSettings),
    })
  );

  if (siteSettings.enable_mentions) {
    $input.autocomplete(
      deepMerge({
        template: findRawTemplate("user-selector-autocomplete"),
        key: "@",
        width: "100%",
        treatAsTextarea: true,
        autoSelectFirstSuggestion: false,
        transformComplete: (v) => v.username || v.name,
        dataSource: (term) => userSearch({ term, includeGroups: true }),
      })
    );
  }
}

export function updateRecentSearches(currentUser, term) {
  if (!term) {
    return;
  }

  let recentSearches = Object.assign(currentUser.recent_searches || []);

  if (recentSearches.includes(term)) {
    recentSearches = recentSearches.without(term);
  } else if (recentSearches.length === MAX_RECENT_SEARCHES) {
    recentSearches.popObject();
  }

  recentSearches.unshiftObject(term);
  currentUser.set("recent_searches", recentSearches);
}

export function logSearchLinkClick(params) {
  if (
    logSearchLinkClickedCallbacks.length &&
    !logSearchLinkClickedCallbacks.some((fn) => fn(params))
  ) {
    // Return early if any callbacks return false
    return;
  }

  ajax("/search/click", {
    type: "POST",
    data: {
      search_log_id: params.searchLogId,
      search_result_id: params.searchResultId,
      search_result_type: params.searchResultType,
    },
  });
}

/**
 * reciprocallyRankedList() makes use of the Reciprocal Ranking Fusion Algorithm (RRF)
 *
 * A method used to combine rankings from multiple sources
 * to aggregate them to provide a single improved ranking
 *
 * RRF = 1 / k + r(d)
 *
 * k = a constant, small positive value to avoid division by zero
 * r(d) = the reciprocal rank of the item in the ranking list
 *
 *
 * @param {Array} lists - an array of arrays containing the results from each source
 * The passed-in list must include the properties specified in the `identifiers` array
 * @param {Array} identifiers - an array of property names used to identify items in the ranking lists
 *
 * Example Usage: reciprocallyRankedList([list1, list2, list3], ["id", "topic_id", "uuid"])
 *
 **/
export function reciprocallyRankedList(lists, identifiers) {
  const k = 5;

  if (lists.length === 1) {
    return lists;
  }

  if (lists.length !== identifiers.length) {
    throw new Error("The number of lists must match the number of identifiers");
  }

  if (lists.length === 0) {
    throw new Error("Lists must not be an empty array");
  }

  // Assign a reciprocal rank to each result
  lists.forEach((list) => {
    list.forEach((listItem, index) => {
      const identifierValues = identifiers.map((id) => listItem[id]);
      const itemKey = identifierValues.join("_");
      listItem.reciprocalRank = 1 / (index + k);
      listItem.itemKey = itemKey;
    });
  });

  // Combine lists into a single list
  const combinedList = [].concat(...lists);

  // Remove duplicates and sum reciprocal ranks based on identifiers
  const resultMap = new Map();
  combinedList.forEach((result) => {
    const existingResult = resultMap.get(result.itemKey);
    if (!existingResult) {
      resultMap.set(result.itemKey, result);
    } else {
      // Sum reciprocal ranks for duplicates
      existingResult.reciprocalRank += result.reciprocalRank;
    }
  });

  // Convert the map values back to an array
  const uniqueResults = Array.from(resultMap.values());

  // Sort the results by reciprocal ranking
  const sortedResults = uniqueResults.sort(
    (a, b) => b.reciprocalRank - a.reciprocalRank
  );

  return sortedResults;
}
