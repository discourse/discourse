import RestAdapter from 'discourse/adapters/rest';

export default RestAdapter.extend({
  pathFor(store, type, findArgs) {
    return `/admin/flags/${findArgs.filter}.json?rest_api=true`;
  },

  afterFindAll(results, helper) {
    results.forEach(flag => {
      let conversations = [];
      flag.post_actions.forEach(pa => {
        if (pa.conversation) {
          let conversation = {
            permalink: pa.permalink,
            hasMore: pa.conversation.has_more,
            response: {
              excerpt: pa.conversation.response.excerpt,
              user: helper.lookup('user', pa.conversation.response.user_id)
            }
          };

          if (pa.conversation.reply) {
            conversation.reply = {
              excerpt: pa.conversation.reply.excerpt,
              user: helper.lookup('user', pa.conversation.reply.user_id)
            };
          }
          conversations.push(conversation);
        }
      });
      flag.set('conversations', conversations);
    });

    return results;
  }
});
