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

    $LAB.script(assetPath('defer/html-sanitizer-bundle'));

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
    var $wmdInput = $('#wmd-input');
    $wmdInput.data('init', true);
    this.set('editor', Discourse.Markdown.createEditor());
    return this.get('editor').run();
  },

  observeValue: (function() {
    var editor = this.get('editor');
    if (!editor) return;
    Ember.run.next(null, function() { editor.refreshPreview(); });
  }).observes('value')

});

Discourse.View.registerHelper('pagedown', Discourse.PagedownEditor);