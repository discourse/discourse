import RestAdapter from 'discourse/adapters/rest';

export default RestAdapter.extend({
  find(store, type, findArgs) {
    const maxReplies = Discourse.SiteSettings.max_reply_history;
    return Discourse.ajax(`/posts/${findArgs.postId}/reply-history?max_replies=${maxReplies}`).then(replies => {
      return { post_reply_histories: replies };
    });
  },
});
