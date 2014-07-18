/*global assetPath:true */

import PagedownPreviewView from 'discourse/views/pagedown-preview';
import DiscourseContainerView from 'discourse/views/container';

export default DiscourseContainerView.extend({
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
