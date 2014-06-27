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

  _initialize: function() {
    this.setProperties({
      local: this.get("allowLocal"),
      showMore: false
    });
  }.on('init'),

  maxSize: Discourse.computed.setting('max_attachment_size_kb'),
  allowLocal: Em.computed.gt('maxSize', 0),

  actions: {
    useLocal: function() { this.setProperties({ local: true, showMore: false}); },
    useRemote: function() { this.set("local", false); },
    toggleShowMore: function() { this.toggleProperty("showMore"); }
  }

});
