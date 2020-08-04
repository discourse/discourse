import { ajax } from "discourse/lib/ajax";
import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  find(store, type, findArgs) {
    return ajax(`/posts/${findArgs.postId}/replies`).then(replies => {
      return { post_replies: replies };
    });
  }
});
