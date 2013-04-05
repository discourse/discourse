/**
  This view handles the image upload interface

  @class ImageSelectorView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ImageSelectorView = Discourse.View.extend({
  templateName: 'image_selector',
  classNames: ['image-selector'],
  title: Em.String.i18n('image_selector.title'),

  init: function() {
    this._super();
    this.set('localSelected', true);
  },

  selectLocal: function() {
    this.set('localSelected', true);
  },

  selectRemote: function() {
    this.set('localSelected', false);
  },

  remoteSelected: function() {
    return !this.get('localSelected');
  }.property('localSelected'),

  upload: function() {
    this.get('uploadTarget').fileupload('add', { fileInput: $('#filename-input') });
  },

  add: function() {
    this.get('composer').addMarkdown("![image](" + $('#fileurl-input').val() + ")");
    $('#discourse-modal').modal('hide');
  }
});
