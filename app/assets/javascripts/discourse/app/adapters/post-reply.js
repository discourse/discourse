import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export default class PostReplyAdapter extends RestAdapter {
  find(_store, _type, { postId, after = 1 }) {
    return ajax(`/posts/${postId}/replies?after=${after || 1}`).then(
      (post_replies) => ({ post_replies })
    );
  }
}
