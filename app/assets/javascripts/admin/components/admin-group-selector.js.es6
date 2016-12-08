export default Ember.Component.extend({
  tagName: 'div',

  _init: function(){
    this.$("input").select2({
        multiple: true,
        width: '100%',
        query: function(opts) {
                opts.callback({
                  results: this.get("available").filter(function(o) {
                      return -1 !== o.name.toLowerCase().indexOf(opts.term.toLowerCase());
                    }).map(this._format)
                });
              }.bind(this)
      }).on("change", function(evt) {
        if (evt.added){
          this.triggerAction({
            action: "groupAdded",
            actionContext: this.get("available").findBy("id", evt.added.id)
          });
        } else if (evt.removed) {
          this.triggerAction({
            action:"groupRemoved",
            actionContext: evt.removed.id
          });
        }
      }.bind(this));

    this._refreshOnReset();
  }.on("didInsertElement"),

  _format(item) {
    return {
      "text": item.name,
      "id": item.id,
      "locked": item.automatic
    };
  },

  _refreshOnReset: function() {
    this.$("input").select2("data", this.get("selected").map(this._format));
  }.observes("selected")
});
