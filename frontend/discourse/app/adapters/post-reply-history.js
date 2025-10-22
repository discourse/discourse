import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export default class PostReplyHistoryAdapter extends RestAdapter {
  find(_store, _type, { postId }) {
    return ajax(`/posts/${postId}/reply-history`).then(
      (post_reply_histories) => ({ post_reply_histories })
    );
  }
}
