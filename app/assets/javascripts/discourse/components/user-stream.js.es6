import LoadMore from "discourse/mixins/load-more";

export default Ember.Component.extend(LoadMore, {
  loading: false,
  eyelineSelector: '.user-stream .item',
  classNames: ['user-stream'],

  _scrollTopOnModelChange: function() {
    Em.run.schedule('afterRender', () => $(document).scrollTop(0));
  }.observes('stream.user.id'),

  actions: {
    loadMore() {
      if (this.get('loading')) { return; }

      this.set('loading', true);
      const stream = this.get('stream');
      stream.findItems().then(() => {
        this.set('loading', false);
        this.get('eyeline').flushRest();
      });
    }
  }
});
