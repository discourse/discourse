export default Ember.Component.extend({
  visibleChanged: function(){
    this.rerender();
  }.observes("visible"),

  render: function(buffer){
    if (this._state !== 'inDOM' && this._state !== 'preRender' && this._state !== 'inBuffer') { return; }
    if (!this.get("visible")) { return; }

    return this._super(buffer);
  }
});
