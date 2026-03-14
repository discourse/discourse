import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

export default async function createBoost(post, raw, currentUser) {
  const previousBoosts = post.boosts || [];
  const optimisticBoost = {
    id: `pending-${Date.now()}`,
    raw,
    cooked: `<p>${emojiUnescape(escapeExpression(raw))}</p>`,
    user: {
      id: currentUser.id,
      username: currentUser.username,
      avatar_template: currentUser.avatar_template,
    },
    can_delete: true,
  };
  post.boosts = [...previousBoosts, optimisticBoost];
  post.can_boost = false;

  try {
    const result = await ajax(`/discourse-boosts/posts/${post.id}/boosts`, {
      type: "POST",
      data: { raw },
    });
    post.boosts = post.boosts.map((b) =>
      b.id === optimisticBoost.id ? result : b
    );
  } catch (e) {
    post.boosts = previousBoosts;
    post.can_boost = true;
    popupAjaxError(e);
  }
}
