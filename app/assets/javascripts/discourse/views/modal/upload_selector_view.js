/**
  This view handles the upload interface

  @class UploadSelectorView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.UploadSelectorView = Discourse.ModalBodyView.extend({
  templateName: 'modal/upload_selector',
  classNames: ['upload-selector'],

  title: function() { return Discourse.UploadSelectorController.translate("title"); }.property(),
  uploadIcon: function() { return Discourse.Utilities.allowsAttachments() ? "icon-file-alt" : "icon-picture"; }.property(),

  tip: function() {
    var source = this.get("controller.local") ? "local" : "remote";
    var opts = { authorized_extensions: Discourse.Utilities.authorizedExtensions() };
    return Discourse.UploadSelectorController.translate(source + "_tip", opts);
  }.property("controller.local"),

  didInsertElement: function() {
    this._super();
    this.selectedChanged();
  },

  selectedChanged: function() {
    var self = this;
    Em.run.next(function() {
      // *HACK* to select the proper radio button
      var value = self.get('controller.local') ? 'local' : 'remote';
      $('input:radio[name="upload"]').val([value]);
      // focus the input
      $('.inputs input:first').focus();
    });
  }.observes('controller.local'),

  upload: function() {
    if (this.get("controller.local")) {
      $('#reply-control').fileupload('add', { fileInput: $('#filename-input') });
    } else {
      this.get('controller.composerView').addMarkdown($('#fileurl-input').val());
      this.get('controller').send('closeModal');
    }
  }

});
