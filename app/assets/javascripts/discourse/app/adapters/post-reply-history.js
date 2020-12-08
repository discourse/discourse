import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export default RestAdapter.extend({
  find(store, type, findArgs) {
    const maxReplies = this.siteSettings.max_reply_history;
    return ajax(
      `/posts/${findArgs.postId}/reply-history?max_replies=${maxReplies}`
    ).then((replies) => {
      return { post_reply_histories: replies };
    });
  },
});
