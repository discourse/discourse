import LoadMore from "discourse/mixins/load-more";

export default Ember.Component.extend(LoadMore, {
  init() {
    this._super();
    this.set('eyelineSelector', this.get('selector'));
  },

  actions: {
    loadMore() {
      this.sendAction();
    }
  }
});
