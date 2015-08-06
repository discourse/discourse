import LoadMore from "discourse/mixins/load-more";

export default Ember.View.extend(LoadMore, {
  loading: false,
  eyelineSelector: '.user-stream .item',
  classNames: ['user-stream'],

  _scrollTopOnModelChange: function() {
    Em.run.schedule('afterRender', function() {
      $(document).scrollTop(0);
    });
  }.observes('controller.model.user.id'),

  actions: {
    loadMore() {
      const self = this;
      if (this.get('loading')) { return; }

      this.set('loading', true);
      const stream = this.get('controller.model');
      stream.findItems().then(function() {
        self.set('loading', false);
        self.get('eyeline').flushRest();
      });
    }
  }
});
