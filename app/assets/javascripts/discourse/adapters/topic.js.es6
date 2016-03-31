import RestAdapter from 'discourse/adapters/rest';

export default RestAdapter.extend({
  find(store, type, findArgs) {
    if (findArgs.similar) {
      return Discourse.ajax("/topics/similar_to", { data: findArgs.similar });
    } else {
      return this._super(store, type, findArgs);
    }
  }
});
