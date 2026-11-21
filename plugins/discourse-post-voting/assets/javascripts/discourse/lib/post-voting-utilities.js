import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const ALL_CATEGORIES = "all_categories";

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
  if (siteSettings.post_voting_category_mode === ALL_CATEGORIES) {
    return true;
  }

  return !!category?.post_voting_allowed;
};

export { removeVote, castVote, whoVoted, postVotingEnabledForCategory };
