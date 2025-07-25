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

export { removeVote, castVote, whoVoted };
