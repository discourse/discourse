/**
  This view handles the image upload interface

  @class ImageSelectorView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.ImageSelectorView = Discourse.ModalBodyView.extend({
  templateName: 'modal/image_selector',
  classNames: ['image-selector'],
  title: Em.String.i18n('image_selector.title'),

  upload: function() {
    $('#reply-control').fileupload('add', { fileInput: $('#filename-input') });
  },

  add: function() {
    this.get('controller.composerView').addMarkdown("![image](" + $('#fileurl-input').val() + ")");
    $('#discourse-modal').modal('hide');
  }

});
