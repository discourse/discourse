import { tracked } from "@glimmer/tracking";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

function initialize(api) {
  api.addPostClassesCallback((post) => {
    if (post.post_number === 1 && post.can_vote) {
      return ["voting-post"];
    }
  });
  api.addTrackedPostProperties("can_vote");
  api.addTagsHtmlCallback(
    (topic) => {
      if (!topic.can_vote) {
        return;
      }

      let buffer = [];

      let title = "";
      if (topic.user_voted) {
        title = ` title='${i18n("topic_voting.voted")}'`;
      }

      let userVotedClass = topic.user_voted ? " voted" : "";
      buffer.push(
        `<a href='${topic.url}' class='list-vote-count vote-count-${topic.vote_count} discourse-tag simple${userVotedClass}'${title}>`
      );

      buffer.push(i18n("topic_voting.votes", { count: topic.vote_count }));
      buffer.push("</a>");

      if (buffer.length > 0) {
        return buffer.join("");
      }
    },
    { priority: -100 }
  );

  api.modifyClass(
    "model:topic",
    (Superclass) =>
      class extends Superclass {
        @tracked vote_count;
        @tracked user_voted;
      }
  );
  api.modifyClass(
    "model:user",
    (Superclass) =>
      class extends Superclass {
        @tracked votes_exceeded;
        @tracked votes_left;
      }
  );
}

export default {
  name: "extend-category-for-voting",

  before: "inject-discourse-objects",

  initialize() {
    withPluginApi("0.8.4", (api) => initialize(api));
    withPluginApi("0.8.30", (api) => api.addCategorySortCriteria("votes"));
  },
};
