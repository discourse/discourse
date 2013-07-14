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
  title: I18n.t('upload_selector.title'),

  upload: function() {
    $('#reply-control').fileupload('add', { fileInput: $('#filename-input') });
  },

  add: function() {
    this.get('controller.composerView').addMarkdown($('#fileurl-input').val());
    this.get('controller').send('closeModal');
  }

});
