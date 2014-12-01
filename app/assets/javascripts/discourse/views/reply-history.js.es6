export default Em.CollectionView.extend({
  tagName: 'section',
  classNameBindings: [':embedded-posts', ':top', ':topic-body', ':offset2', 'hidden'],
  itemViewClass: 'embedded-post',
  hidden: Em.computed.equal('content.length', 0),
  previousPost: true
});
