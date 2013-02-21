(function() {

  /**
    Our data model for interacting with site settings.

    @class SiteSetting    
    @extends Discourse.Model
    @namespace Discourse
    @module Discourse
  **/ 
  window.Discourse.SiteSetting = Discourse.Model.extend(Discourse.Presence, {
    
    // Whether a property is short.
    short: (function() {
      if (this.blank('value')) return true;
      return this.get('value').toString().length < 80;
    }).property('value'),

    // Whether the site setting has changed
    dirty: (function() {
      return this.get('originalValue') !== this.get('value');
    }).property('originalValue', 'value'),

    overridden: (function() {
      var defaultVal, val;
      val = this.get('value');
      defaultVal = this.get('default');
      if (val && defaultVal) {
        return val.toString() !== defaultVal.toString();
      }
      return val !== defaultVal;
    }).property('value'),

    resetValue: function() {
      this.set('value', this.get('originalValue'));
    },

    save: function() {
      // Update the setting
      var _this = this;
      return jQuery.ajax("/admin/site_settings/" + (this.get('setting')), {
        data: { value: this.get('value') },
        type: 'PUT',
        success: function() {
          _this.set('originalValue', _this.get('value'));
        }
      });
    }
  });

  window.Discourse.SiteSetting.reopenClass({
    findAll: function() {
      var result;
      result = Em.A();
      jQuery.get("/admin/site_settings", function(settings) {
        return settings.each(function(s) {
          s.originalValue = s.value;
          return result.pushObject(Discourse.SiteSetting.create(s));
        });
      });
      return result;
    }
  });

}).call(this);
