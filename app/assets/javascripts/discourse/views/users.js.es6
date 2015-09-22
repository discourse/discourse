import LoadMore from 'discourse/mixins/load-more';

export default Ember.View.extend(LoadMore, {
  eyelineSelector: '.directory tbody tr'
});
