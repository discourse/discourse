export default Ember.CollectionView.extend({
  classNames: ['posters'],
  tagName: 'td',
  content: Em.computed.alias('posters'),
  itemViewClass: 'topic-list-poster'
});
