/**
  Our data model for interacting with site customizations.

  @class SiteCustomization
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.SiteCustomization = Discourse.Model.extend({
  trackedProperties: ['enabled', 'name', 'stylesheet', 'header', 'mobile_stylesheet', 'mobile_header', 'override_default_style'],

  init: function() {
    this._super();
    this.startTrackingChanges();
  },

  description: function() {
    return "" + this.name + (this.enabled ? ' (*)' : '');
  }.property('selected', 'name'),

  changed: function() {

    var _this = this;
    if(!this.originals) return false;

    var changed = _.some(this.trackedProperties,function(p) {
      return _this.originals[p] !== _this.get(p);
    });

    if(changed){
      this.set('savingStatus','');
    }

    return changed;

  }.property('override_default_style', 'enabled', 'name', 'stylesheet', 'header', 'mobile_stylesheet', 'mobile_header', 'originals'),

  startTrackingChanges: function() {
    var _this = this;
    var originals = {};
    _.each(this.trackedProperties,function(prop) {
      originals[prop] = _this.get(prop);
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
    this.set('savingStatus', I18n.t('saving'));
    this.set('saving',true);
    var data = {
      name: this.name,
      enabled: this.enabled,
      stylesheet: this.stylesheet,
      header: this.header,
      mobile_stylesheet: this.mobile_stylesheet,
      mobile_header: this.mobile_header,
      override_default_style: this.override_default_style
    };

    var siteCustomization = this;
    return Discourse.ajax("/admin/site_customizations" + (this.id ? '/' + this.id : ''), {
      data: { site_customization: data },
      type: this.id ? 'PUT' : 'POST'
    }).then(function (result) {
      if (!siteCustomization.id) {
        siteCustomization.set('id', result.id);
        siteCustomization.set('key', result.key);
      }
      siteCustomization.set('savingStatus', I18n.t('saved'));
      siteCustomization.set('saving',false);
      siteCustomization.startTrackingChanges();
    });

  },

  destroy: function() {
    if(!this.id) return;
    return Discourse.ajax("/admin/site_customizations/" + this.id, {
      type: 'DELETE'
    });
  }

});

var SiteCustomizations = Ember.ArrayProxy.extend({
  selectedItemChanged: function() {
    var selected = this.get('selectedItem');
    _.each(this.get('content'),function(i) {
      return i.set('selected', selected === i);
    });
  }.observes('selectedItem')
});

Discourse.SiteCustomization.reopenClass({
  findAll: function() {
    var customizations = SiteCustomizations.create({ content: [], loading: true });
    Discourse.ajax("/admin/site_customizations").then(function (data) {
      if (data) {
        _.each(data.site_customizations,function(c) {
          customizations.pushObject(Discourse.SiteCustomization.create(c.site_customizations));
        });
      }
      customizations.set('loading', false);
    });
    return customizations;
  }
});
