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
  title: 'Insert Image',

  init: function() {
    this._super();
    return this.set('localSelected', true);
  },

  selectLocal: function() {
    return this.set('localSelected', true);
  },

  selectRemote: function() {
    return this.set('localSelected', false);
  },

  remoteSelected: (function() {
    return !this.get('localSelected');
  }).property('localSelected'),

  upload: function() {
    this.get('uploadTarget').fileupload('send', { fileInput: $('#filename-input') });
    return $('#discourse-modal').modal('hide');
  },

  add: function() {
    this.get('composer').addMarkdown("![image](" + ($('#fileurl-input').val()) + ")");
    return $('#discourse-modal').modal('hide');
  }
});


