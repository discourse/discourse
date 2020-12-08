import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export default RestAdapter.extend({
  find(store, type, findArgs) {
    return ajax(`/posts/${findArgs.postId}/replies`).then((replies) => {
      return { post_replies: replies };
    });
  },
});
