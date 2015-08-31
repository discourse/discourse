import LoadMore from "discourse/mixins/load-more";

export default Ember.View.extend(LoadMore, {
  eyelineSelector: '.badge-user',
  tickOrX: function(field){
    var icon = this.get('controller.model.' + field) ? "fa-check" : "fa-times";
    return "<i class='fa " + icon + "'></i>";
  },
  allowTitle: function() { return this.tickOrX("allow_title"); }.property(),
  multipleGrant: function() { return this.tickOrX("multiple_grant"); }.property()
});
