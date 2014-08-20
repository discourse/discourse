import DiscoveryController from 'discourse/controllers/discovery';

export default DiscoveryController.extend({
  needs: ['discovery'],

  period: function() {
    return this.get('controllers.discovery.periods').findBy('id', this.get('periodId'));
  }.property('periodId'),

  topicList: function() {
    return this.get('model.' + this.get('periodId'));
  }.property('periodId'),

  actions: {
    refresh: function() {
      var self = this;

      // Don't refresh if we're still loading
      if (this.get('controllers.discovery.loading')) { return; }

      this.send('loading');
      Discourse.TopList.find().then(function(top_lists) {
        self.set('model', top_lists);
        self.send('loadingComplete');
      });
    }
  }

});
