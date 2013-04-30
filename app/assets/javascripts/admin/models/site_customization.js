/**
  Our data model for interacting with site customizations.

  @class SiteCustomization
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.SiteCustomization = Discourse.Model.extend({
  trackedProperties: ['enabled', 'name', 'stylesheet', 'header', 'override_default_style'],

  init: function() {
    this._super();
    return this.startTrackingChanges();
  },

  description: function() {
    return "" + this.name + (this.enabled ? ' (*)' : '');
  }.property('selected', 'name'),

  changed: function() {

    var _this = this;
    if(!this.originals) return false;

    var changed = this.trackedProperties.any(function(p) {
      return _this.originals[p] !== _this.get(p);
    });

    if(changed){
      this.set('savingStatus','');
    }

    return changed;

  }.property('override_default_style', 'enabled', 'name', 'stylesheet', 'header', 'originals'),

  startTrackingChanges: function() {
    var _this = this;
    var originals = {};
    this.trackedProperties.each(function(p) {
      originals[p] = _this.get(p);
      return true;
    });
    this.set('originals', originals);
  },

  previewUrl: function() {
    return "/?preview-style=" + (this.get('key'));
  }.property('key'),

  disableSave: function() {
    return !this.get('changed') || this.get('saving');
  }.property('changed'),


  save: function() {
    var _this = this;
    this.set('savingStatus', Em.String.i18n('saving'));
    this.set('saving',true);
    var data = {
      name: this.name,
      enabled: this.enabled,
      stylesheet: this.stylesheet,
      header: this.header,
      override_default_style: this.override_default_style
    };
    return Discourse.ajax({
      url: Discourse.getURL("/admin/site_customizations") + (this.id ? '/' + this.id : ''),
      data: {
        site_customization: data
      },
      type: this.id ? 'PUT' : 'POST',
      success: function(data) {
        if (!_this.id) { _this.set('id', data.id); }
        _this.set('savingStatus', Em.String.i18n('saved'));
        _this.set('saving',false);
        _this.startTrackingChanges();
      }
    });
  },

  destroy: function() {
    if(!this.id) return;
    return Discourse.ajax({
      url: Discourse.getURL("/admin/site_customizations/") + this.id,
      type: 'DELETE'
    });
  }

});

var SiteCustomizations = Ember.ArrayProxy.extend({
  selectedItemChanged: function() {
    var selected = this.get('selectedItem');
    return this.get('content').each(function(i) {
      return i.set('selected', selected === i);
    });
  }.observes('selectedItem')
});

Discourse.SiteCustomization.reopenClass({
  findAll: function() {
    var customizations = SiteCustomizations.create({ content: [], loading: true });
    Discourse.ajax({
      url: Discourse.getURL("/admin/site_customizations"),
      dataType: "json"
    }).then(function (data) {
      if (data) {
        data.site_customizations.each(function(c) {
          customizations.pushObject(Discourse.SiteCustomization.create(c.site_customizations));
        });
      }
      customizations.set('loading', false);
    });
    return customizations;
  }
});
