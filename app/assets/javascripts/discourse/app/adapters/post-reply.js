import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export default class PostReplyAdapter extends RestAdapter {
  find(store, type, findArgs) {
    return ajax(`/posts/${findArgs.postId}/replies`).then((replies) => {
      return { post_replies: replies };
    });
  }
}
