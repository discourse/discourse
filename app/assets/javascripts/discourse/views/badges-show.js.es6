/**
  View for showing a particular badge.

  @class BadgesShowView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
export default Discourse.View.extend(Discourse.LoadMore, {
  eyelineSelector: '.badge-user',
  tickOrX: function(field){
    var icon = this.get('controller.model.' + field) ? "fa-check" : "fa-times";
    return "<i class='fa " + icon + "'></i>";
  },
  allowTitle: function() { return this.tickOrX("allow_title"); }.property(),
  multipleGrant: function() { return this.tickOrX("multiple_grant"); }.property()
});
