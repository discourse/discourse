/**
  The modal for upload a file to a post

  @class UploadSelectorController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
export default Discourse.Controller.extend(Discourse.ModalFunctionality, {
  remote: Em.computed.not("local"),
  local: false,
  showMore: false,

  init: function() {
    this._super();
    this.setProperties({
      local: this.get("allowLocal"),
      showMore: false
    });
  },

  allowLocal: function() {
    return Discourse.SiteSettings.max_attachment_size_kb > 0;
  }.property(),

  actions: {
    useLocal: function() { this.setProperties({ local: true, showMore: false}); },
    useRemote: function() { this.set("local", false); },
    toggleShowMore: function() { this.toggleProperty("showMore"); }
  }

});
