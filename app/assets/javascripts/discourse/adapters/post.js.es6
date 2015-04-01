import RestAdapter from 'discourse/adapters/rest';

export default RestAdapter.extend({

  // GET /posts doesn't include a type
  find(store, type, findArgs) {
    return this._super(store, type, findArgs).then(function(result) {
      return {post: result};
    });
  }
});
