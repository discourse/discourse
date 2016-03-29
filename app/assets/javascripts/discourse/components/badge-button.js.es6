export default Ember.Component.extend({
  tagName: 'span',
  classNameBindings: [':user-badge', 'badge.badgeTypeClassName'],
  title: function(){
    return $("<div>"+this.get('badge.description')+"</div>").text();
  }.property('badge.description'),
  attributeBindings: ['data-badge-name', 'title'],
  'data-badge-name': Em.computed.alias('badge.name')
});
