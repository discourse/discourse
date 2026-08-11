import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const vote = function (type, data) {
  return ajax("/post_voting/vote", {
    type,
    data,
  });
};

const removeVote = function (data) {
  return vote("DELETE", data);
};

const castVote = function (data) {
  return vote("POST", data);
};

const whoVoted = function (data) {
  return ajax("/post_voting/voters", {
    type: "GET",
    data,
  }).catch(popupAjaxError);
};

const postVotingEnabledForCategory = function (category, siteSettings) {
  const allowed = (siteSettings.post_voting_enabled_categories || "")
    .split("|")
    .map((id) => parseInt(id, 10))
    .filter((id) => !Number.isNaN(id));

  if (allowed.length === 0) {
    return true;
  }

  if (!category) {
    return false;
  }

  if (siteSettings.post_voting_enabled_categories_include_subcategories) {
    return category.ancestors.some((ancestor) => allowed.includes(ancestor.id));
  }

  return allowed.includes(category.id);
};

export { removeVote, castVote, whoVoted, postVotingEnabledForCategory };
