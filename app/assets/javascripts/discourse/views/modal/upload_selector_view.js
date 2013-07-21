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

  upload: function() {
    $('#reply-control').fileupload('add', { fileInput: $('#filename-input') });
  },

  add: function() {
    this.get('controller.composerView').addMarkdown($('#fileurl-input').val());
    this.get('controller').send('closeModal');
  }

});
