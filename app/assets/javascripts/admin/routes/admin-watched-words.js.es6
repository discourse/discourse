import WatchedWord from 'admin/models/watched-word';

export default Discourse.Route.extend({
  queryParams: {
    filter: { replace: true }
  },

  model() {
    return WatchedWord.findAll();
  },

  afterModel(watchedWordsList) {
    this.controllerFor('adminWatchedWords').set('allWatchedWords', watchedWordsList);
  }
});
