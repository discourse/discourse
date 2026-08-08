import { computed, get } from "@ember/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

function extendCategory(api) {
  Category.reopen({
    enable_topic_voting: computed("custom_fields.enable_topic_voting", {
      get() {
        return get(this.custom_fields, "enable_topic_voting") === true;
      },
    }),
  });
  api.addPostClassesCallback((post) => {
    if (post.post_number === 1 && post.can_vote) {
      return ["voting-post"];
    }
  });
  api.addTrackedPostProperties("can_vote");
  api.addTagsHtmlCallback(
    (topic) => {
      const router = api.container.lookup("service:router");

      if (!topic.can_vote || router.currentRouteName?.startsWith("topic.")) {
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

      return buffer.join("");
    },
    { priority: -100 }
  );

  api.addModelField("topic", "vote_count");
  api.addModelField("topic", "user_voted");
  api.addModelField("user", "votes_exceeded");
  api.addModelField("user", "vote_limit");
  api.addModelField("user", "votes_left");
}

export default {
  name: "extend-category-for-voting",

  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      extendCategory(api);
      api.addCategorySortCriteria("votes");
    });
  },
};
