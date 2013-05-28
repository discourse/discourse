/*global Markdown:true assetPath:true */

/**
  A control to support using PageDown as an Ember view.

  @class PagedownEditor
  @extends Ember.ContainerView
  @namespace Discourse
  @module Discourse
**/
Discourse.PagedownEditor = Ember.ContainerView.extend({
  elementId: 'pagedown-editor',

  init: function() {
    this._super();
    var _this = this;
    $LAB.script(assetPath('defer/html-sanitizer-bundle')).wait(function(){
      var editor = _this.get('editor');
      if(editor){
        //Call refresh preview on sanitizer script load because
        //if it wasn't loaded before editor.run() was called then the
        //preview is likely blank
        editor.refreshPreview();
      }
    });

    // Add a button bar
    this.pushObject(Em.View.create({ elementId: 'wmd-button-bar' }));
    this.pushObject(Em.TextArea.create({ valueBinding: 'parentView.value', elementId: 'wmd-input' }));

    this.pushObject(Discourse.View.createWithMixins({
      elementId: 'wmd-preview',
      classNameBindings: [':preview', 'hidden'],
      hidden: (function() {
        return this.blank('parentView.value');
      }).property('parentView.value')
    }));
  },

  didInsertElement: function() {
    $('#wmd-input').data('init', true);
    var editor = Discourse.Markdown.createEditor();
    this.set('editor', editor);
    return editor.run();
  },

  observeValue: (function() {
    var editor = this.get('editor');
    if (!editor) return;
    Ember.run.next(null, function() { editor.refreshPreview(); });
  }).observes('value')

});
