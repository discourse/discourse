(function() {
  var SiteCustomizations;

  /**
    Our data model for interacting with site customizations.

    @class SiteCustomization    
    @extends Discourse.Model
    @namespace Discourse
    @module Discourse
  **/ 
  window.Discourse.SiteCustomization = Discourse.Model.extend({
    trackedProperties: ['enabled', 'name', 'stylesheet', 'header', 'override_default_style'],

    init: function() {
      this._super();
      return this.startTrackingChanges();
    },
   
    description: (function() {
      return "" + this.name + (this.enabled ? ' (*)' : '');
    }).property('selected', 'name'),

    changed: (function() {
      var _this = this;
      if (!this.originals) {
        return false;
      }
      return this.trackedProperties.any(function(p) {
        return _this.originals[p] !== _this.get(p);
      });
    }).property('override_default_style', 'enabled', 'name', 'stylesheet', 'header', 'originals'),

    startTrackingChanges: function() {
      var _this = this;
      this.set('originals', {});
      return this.trackedProperties.each(function(p) {
        _this.originals[p] = _this.get(p);
        return true;
      });
    },

    previewUrl: (function() {
      return "/?preview-style=" + (this.get('key'));
    }).property('key'),

    disableSave: (function() {
      return !this.get('changed');
    }).property('changed'),

    save: function() {
      var data;
      this.startTrackingChanges();
      data = {
        name: this.name,
        enabled: this.enabled,
        stylesheet: this.stylesheet,
        header: this.header,
        override_default_style: this.override_default_style
      };
      return jQuery.ajax({
        url: "/admin/site_customizations" + (this.id ? '/' + this.id : ''),
        data: {
          site_customization: data
        },
        type: this.id ? 'PUT' : 'POST'
      });
    },

    "delete": function() {
      if (!this.id) return;
      
      return jQuery.ajax({
        url: "/admin/site_customizations/" + this.id,
        type: 'DELETE'
      });
    }

  });

  SiteCustomizations = Ember.ArrayProxy.extend({
    selectedItemChanged: (function() {
      var selected;
      selected = this.get('selectedItem');
      return this.get('content').each(function(i) {
        return i.set('selected', selected === i);
      });
    }).observes('selectedItem')
  });

  Discourse.SiteCustomization.reopenClass({
    findAll: function() {
      var content,
        _this = this;
      content = SiteCustomizations.create({
        content: [],
        loading: true
      });
      jQuery.ajax({
        url: "/admin/site_customizations",
        dataType: "json",
        success: function(data) {
          if (data) {
            data.site_customizations.each(function(c) {
              var item;
              item = Discourse.SiteCustomization.create(c);
              return content.pushObject(item);
            });
          }
          return content.set('loading', false);
        }
      });
      return content;
    }
  });

}).call(this);
