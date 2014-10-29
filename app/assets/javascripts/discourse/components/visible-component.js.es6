export default Ember.Component.extend({
  visibleChanged: function(){
    this.rerender();
  }.observes("visible"),

  render: function(buffer){
    if(!this.get("visible")){
      return;
    }

    return this._super(buffer);
  }
});
