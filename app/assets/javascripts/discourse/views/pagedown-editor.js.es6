/*global assetPath:true */

/**
  A control to support using PageDown as an Ember view.

  @class PagedownEditor
  @extends Discourse.ContainerView
  @namespace Discourse
  @module Discourse
**/
import PagedownPreviewView from 'discourse/views/pagedown-preview';

export default Discourse.ContainerView.extend({
  elementId: 'pagedown-editor',

  init: function() {
    this._super();

    $LAB.script(assetPath('defer/html-sanitizer-bundle'));

    // Add a button bar
    this.pushObject(Em.View.create({ elementId: 'wmd-button-bar' }));
    this.pushObject(Em.TextArea.create({ valueBinding: 'parentView.value', elementId: 'wmd-input' }));

    this.attachViewClass(PagedownPreviewView);
  },

  didInsertElement: function() {
    $('#wmd-input').data('init', true);
    this.set('editor', Discourse.Markdown.createEditor());
    this.get('editor').run();
  },

  observeValue: function() {
    var editor = this.get('editor');
    if (!editor) return;
    Ember.run.next(null, function() { editor.refreshPreview(); });
  }.observes('value')

});
