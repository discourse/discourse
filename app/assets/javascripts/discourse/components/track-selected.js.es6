export default Ember.Component.extend({
  tagName: "span",
  selectionChanged: function(){
    const selected = this.get('selected');
    const list = this.get('selectedList');
    const id = this.get('selectedId');

    if (selected) {
      list.addObject(id);
    } else {
      list.removeObject(id);
    }
  }.observes('selected')
});
