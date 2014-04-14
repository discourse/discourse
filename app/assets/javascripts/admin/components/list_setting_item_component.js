/**
  One item in a ListSetting.

  @param parent is the ListSettingComponent.

  @class Discourse.ListSettingItemComponent
  @extends Ember.Component, Ember.TextSupport
  @namespace Discourse
  @module Discourse
 **/
Discourse.ListSettingItemComponent = Ember.Component.extend(Ember.TextSupport, {
  classNames: ['ember-text-field'],
  tagName: "input",
  attributeBindings: ['type', 'value', 'size', 'pattern'],

  _initialize: function() {
    // _parentView is the #each
    // parent is the ListSettingComponent
    this.setProperties({
      value: this.get('_parentView.content'),
      index: this.get('_parentView.contentIndex')
    });
    this.get('parent').get('children')[this.get('index')] = this;
  }.on('init'),

  markTab: function(e) {
    var keyCode = e.keyCode || e.which;

    if (keyCode === 9) {
      this.set('nextIndex', this.get('index') + (e.shiftKey ? -1 : 1));
    }
  }.on('keyDown'),

  reloadList: function() {
    var nextIndex = this.get('nextIndex');
    this.set('nextIndex', undefined); // one use only
    this.get('parent').uncacheValue(nextIndex);
  }.on('focusOut'),

  _elementValueDidChange: function() {
    this._super();
    this.get('parent').setItemValue(this.get('index'), this.get('value'));
  }
});
