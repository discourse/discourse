import { cancel, later } from "@ember/runloop";
import { CANCELLED_STATUS } from "discourse/lib/autocomplete";
import { Promise } from "rsvp";
import discourseDebounce from "discourse-common/lib/debounce";
import { emailValid } from "discourse/lib/utilities";
import { isTesting } from "discourse-common/config/environment";
import { userPath } from "discourse/lib/url";
import { ajax } from "discourse/lib/ajax";

let cache = {},
  cacheKey,
  cacheTime,
  currentTerm,
  oldSearch;

export function resetUserSearchCache() {
  cache = {};
  cacheKey = null;
  cacheTime = null;
  currentTerm = null;
  oldSearch = null;
}

export function camelCaseToSnakeCase(text) {
  return text.replace(/([a-zA-Z])(?=[A-Z])/g, "$1_").toLowerCase();
}

function performSearch(
  term,
  topicId,
  categoryId,
  includeGroups,
  includeMentionableGroups,
  includeMessageableGroups,
  customUserSearchOptions,
  allowedUsers,
  groupMembersOf,
  includeStagedUsers,
  lastSeenUsers,
  limit,
  resultsFn
) {
  let cached = cache[term];
  if (cached) {
    resultsFn(cached);
    return;
  }

  const eagerComplete = eagerCompleteSearch(term, topicId || categoryId);

  if (term === "" && !eagerComplete && !lastSeenUsers) {
    // The server returns no results in this case, so no point checking
    // do not return empty list, because autocomplete will get terminated
    resultsFn(CANCELLED_STATUS);
    return;
  }

  let data = {
    term,
    topic_id: topicId,
    category_id: categoryId,
    include_groups: includeGroups,
    include_mentionable_groups: includeMentionableGroups,
    include_messageable_groups: includeMessageableGroups,
    groups: groupMembersOf,
    topic_allowed_users: allowedUsers,
    include_staged_users: includeStagedUsers,
    last_seen_users: lastSeenUsers,
    limit,
  };

  if (customUserSearchOptions) {
    Object.keys(customUserSearchOptions).forEach((key) => {
      data[camelCaseToSnakeCase(key)] = customUserSearchOptions[key];
    });
  }

  // need to be able to cancel this
  oldSearch = ajax(userPath("search/users"), {
    data,
  });

  let returnVal = CANCELLED_STATUS;

  oldSearch
    .then(function (r) {
      const hasResults = !!(
        (r.users && r.users.length) ||
        (r.groups && r.groups.length) ||
        (r.emails && r.emails.length)
      );

      if (eagerComplete && !hasResults) {
        // we are trying to eager load, but received no results
        // do not return empty list, because autocomplete will get terminated
        r = CANCELLED_STATUS;
      }

      cache[term] = r;
      cacheTime = new Date();
      // If there is a newer search term, return null
      if (term === currentTerm) {
        returnVal = r;
      }
    })
    .finally(function () {
      oldSearch = null;
      resultsFn(returnVal);
    });
}

let debouncedSearch = function (
  term,
  topicId,
  categoryId,
  includeGroups,
  includeMentionableGroups,
  includeMessageableGroups,
  customUserSearchOptions,
  allowedUsers,
  groupMembersOf,
  includeStagedUsers,
  lastSeenUsers,
  limit,
  resultsFn
) {
  discourseDebounce(
    this,
    performSearch,
    term,
    topicId,
    categoryId,
    includeGroups,
    includeMentionableGroups,
    includeMessageableGroups,
    customUserSearchOptions,
    allowedUsers,
    groupMembersOf,
    includeStagedUsers,
    lastSeenUsers,
    limit,
    resultsFn,
    300
  );
};

function organizeResults(r, options) {
  if (r === CANCELLED_STATUS) {
    return r;
  }

  let exclude = options.exclude || [],
    limit = options.limit || 5,
    users = [],
    emails = [],
    groups = [],
    results = [];

  if (r.users) {
    r.users.every(function (u) {
      if (exclude.indexOf(u.username) === -1) {
        users.push(u);
        results.push(u);
      }
      return results.length <= limit;
    });
  }

  if (options.allowEmails && emailValid(options.term)) {
    let e = { username: options.term };
    emails = [e];
    results.push(e);
  }

  if (r.groups) {
    r.groups.every(function (g) {
      if (
        options.term.toLowerCase() === g.name.toLowerCase() ||
        results.length < limit
      ) {
        if (exclude.indexOf(g.name) === -1) {
          groups.push(g);
          results.push(g);
        }
      }
      return true;
    });
  }

  results.users = users;
  results.emails = emails;
  results.groups = groups;
  return results;
}

// all punctuation except for -, _ and . which are allowed in usernames
// note: these are valid in names, but will end up tripping search anyway so just skip
// this means searching for `sam saffron` is OK but if my name is `sam$ saffron` autocomplete
// will not find me, which is a reasonable compromise
//
// we also ignore if we notice a double space or a string that is only a space
const ignoreRegex = /([\u2000-\u206F\u2E00-\u2E7F\\'!"#$%&()*,\/:;<=>?\[\]^`{|}~])|\s\s|^\s$|^[^+]*\+[^@]*$/;

export function skipSearch(term, allowEmails, lastSeenUsers = false) {
  if (lastSeenUsers) {
    return false;
  }
  if (term.indexOf("@") > -1 && !allowEmails) {
    return true;
  }

  return !!term.match(ignoreRegex);
}

export function eagerCompleteSearch(term, scopedId) {
  return term === "" && !!scopedId;
}

export default function userSearch(options) {
  if (options.term && options.term.length > 0 && options.term[0] === "@") {
    options.term = options.term.substring(1);
  }

  let term = options.term || "",
    includeGroups = options.includeGroups,
    includeMentionableGroups = options.includeMentionableGroups,
    includeMessageableGroups = options.includeMessageableGroups,
    customUserSearchOptions = options.customUserSearchOptions,
    allowedUsers = options.allowedUsers,
    topicId = options.topicId,
    categoryId = options.categoryId,
    groupMembersOf = options.groupMembersOf,
    includeStagedUsers = options.includeStagedUsers,
    lastSeenUsers = options.lastSeenUsers,
    limit = options.limit || 6;

  if (oldSearch) {
    oldSearch.abort();
    oldSearch = null;
  }

  currentTerm = term;

  return new Promise(function (resolve) {
    const newCacheKey = `${topicId}-${categoryId}`;

    if (new Date() - cacheTime > 30000 || cacheKey !== newCacheKey) {
      cache = {};
    }

    cacheKey = newCacheKey;

    let clearPromise;
    if (!isTesting()) {
      clearPromise = later(() => resolve(CANCELLED_STATUS), 5000);
    }

    if (skipSearch(term, options.allowEmails, options.lastSeenUsers)) {
      resolve([]);
      return;
    }

    debouncedSearch(
      term,
      topicId,
      categoryId,
      includeGroups,
      includeMentionableGroups,
      includeMessageableGroups,
      customUserSearchOptions,
      allowedUsers,
      groupMembersOf,
      includeStagedUsers,
      lastSeenUsers,
      limit,
      function (r) {
        cancel(clearPromise);
        resolve(organizeResults(r, options));
      }
    );
  });
}
