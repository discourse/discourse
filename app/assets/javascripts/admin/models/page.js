/**
  Our data model for interacting with pages.

  @class Page
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Page = Discourse.Model.extend({
  trackedProperties: ['enabled', 'name', 'page', 'route'],

  init: function() {
    this._super();
    return this.startTrackingChanges();
  },

  description: function() {
    return "" + this.name + (this.enabled ? ' (*)' : '');
  }.property('selected', 'name'),

  changed: function() {
    var _this = this;
    if (!this.originals) return false;
    return this.trackedProperties.any(function(p) {
      return _this.originals[p] !== _this.get(p);
    });
  }.property('enabled', 'name', 'page', 'route', 'originals'),

  startTrackingChanges: function() {
    var _this = this;
    this.set('originals', {});
    return this.trackedProperties.each(function(p) {
      _this.originals[p] = _this.get(p);
      return true;
    });
  },

  previewUrl: function() {
    return "/?preview-page=" + (this.get('key'));
  }.property('key'),

  disableSave: function() {
    return !this.get('changed');
  }.property('changed'),

  save: function() {
    this.startTrackingChanges();
    var data = {
      enabled: this.enabled,
      name: this.name,
      page: this.page,
      route: this.route,
    };
    return Discourse.ajax({
      url: Discourse.getURL("/admin/pages") + (this.id ? '/' + this.id : ''),
      data: {
        page: data
      },
      type: this.id ? 'PUT' : 'POST'
    });
  },

  destroy: function() {
    if (!this.id) return;
    return Discourse.ajax({
      url: Discourse.getURL("/admin/pages/") + this.id,
      type: 'DELETE'
    });
  }

});

var Pages = Ember.ArrayProxy.extend({
  selectedItemChanged: function() {
    var selected = this.get('selectedItem');
    return this.get('content').each(function(i) {
      return i.set('selected', selected === i);
    });
  }.observes('selectedItem')
});

Discourse.Page.reopenClass({
  findAll: function() {
    var pages = Pages.create({ content: [], loading: true });
    Discourse.ajax({
      url: Discourse.getURL("/admin/pages"),
      dataType: "json"
    }).then(function (data) {
      if (data) {
        data.pages.each(function(c) {
          pages.pushObject(Discourse.Page.create(c));
        });
      }
      pages.set('loading', false);
    });
    return pages;
  }
});
