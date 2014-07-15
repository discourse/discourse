export default Ember.Component.extend({
  tagName: 'div',

  didInsertElement: function(){
    this.$("input").select2({
        multiple: true,
        width: '100%',
        query: function(opts){
                opts.callback({
                  results: this.get("available").map(this._format)
                });
              }.bind(this)
      }).on("change", function(evt) {
        if (evt.added){
          this.triggerAction({action: "groupAdded",
                actionContext: this.get("available"
                                    ).findBy("id", evt.added.id)});
        } else if (evt.removed) {
          this.triggerAction({action:"groupRemoved",
                actionContext: this.get("selected"
                                    ).findBy("id", evt.removed.id)});
        }
      }.bind(this));
    this._refreshOnReset();
  },

  _format: function(item){
    return {"text": item.name, "id": item.id, "locked": item.automatic};
  },

  _refreshOnReset: function() {
    this.$("input").select2("data", this.get("selected").map(this._format));
  }.observes("selected")
});