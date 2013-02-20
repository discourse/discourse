(function() {

  window.Discourse.ImageSelectorView = Ember.View.extend({
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
      this.get('uploadTarget').fileupload('send', {
        fileInput: jQuery('#filename-input')
      });
      return jQuery('#discourse-modal').modal('hide');
    },
    add: function() {
      this.get('composer').addMarkdown("![image](" + (jQuery('#fileurl-input').val()) + ")");
      return jQuery('#discourse-modal').modal('hide');
    }
  });

}).call(this);
