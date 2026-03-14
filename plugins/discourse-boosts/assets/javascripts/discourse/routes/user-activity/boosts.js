import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";

const PAGE_SIZE = 20;

export { PAGE_SIZE };

function flattenBoost(boost) {
  const title = boost.post.topic_title;
  return {
    boost_id: boost.id,
    boost_cooked: boost.cooked,
    boost_raw: boost.raw,
    booster: {
      username: boost.user.username,
      name: boost.user.name,
      avatar_template: boost.user.avatar_template,
    },
    id: boost.post.id,
    user_id: boost.post.user_id,
    username: boost.post.username,
    name: boost.post.name,
    avatar_template: boost.post.avatar_template,
    excerpt: boost.post.excerpt,
    topic_id: boost.post.topic_id,
    url: boost.post.url,
    title,
    titleHtml: title && emojiUnescape(escapeExpression(title)),
    created_at: boost.created_at,
  };
}

export { flattenBoost };

export default class UserActivityBoosts extends DiscourseRoute {
  async model() {
    const username = this.modelFor("user").username;
    const result = await ajax(
      `/discourse-boosts/users/${username}/boosts.json`
    );
    const boosts = result.boosts || [];
    return new TrackedArray(boosts.map(flattenBoost));
  }

  setupController(controller, model) {
    const loadedAll = model.length < PAGE_SIZE;
    this.controllerFor("user-activity.boosts").setProperties({
      model,
      canLoadMore: !loadedAll,
      username: this.modelFor("user").username,
    });
  }
}
