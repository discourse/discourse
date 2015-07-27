import DiscourseController from 'discourse/controllers/controller';
import { translateResults }  from 'discourse/lib/search-for-term';

export default DiscourseController.extend({
  loading: Em.computed.not('model'),
  queryParams: ['q'],
  q: null,
  modelChanged: function(){
    if (this.get('searchTerm') !== this.get('q')) {
      this.set('searchTerm', this.get('q'));
    }
  }.observes('model'),

  qChanged: function(){
    var model = this.get('model');
    if (model && this.get('model.q') !== this.get('q')){
      this.set('searchTerm', this.get('q'));
      this.send('search');
    }
  }.observes('q'),
  actions: {
    search: function(){
      var self = this;
      this.set('q', this.get('searchTerm'));
      this.set('model', null);

      Discourse.ajax('/search2', {data: {q: this.get('searchTerm')}}).then(function(results) {
        self.set('model', translateResults(results) || {});
        self.set('model.q', self.get('q'));
      });
    }
  }
});
