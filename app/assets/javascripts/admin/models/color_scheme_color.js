/**
  Our data model for a color within a color scheme.
  (It's a funny name for a class, but Color seemed too generic for what this class is.)

  @class ColorSchemeColor
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.ColorSchemeColor = Discourse.Model.extend({

  init: function() {
    this._super();
    this.startTrackingChanges();
  },

  startTrackingChanges: function() {
    this.set('originals', {
      hex: this.get('hex') || 'FFFFFF',
      opacity: this.get('opacity') || '100'
    });
    this.notifyPropertyChange('hex'); // force changed property to be recalculated
  },

  changed: function() {
    if (!this.originals) return false;

    if (this.get('hex') !== this.originals['hex'] || this.get('opacity').toString() !== this.originals['opacity'].toString()) {
      return true;
    } else {
      return false;
    }
  }.property('hex', 'opacity'),

  undo: function() {
    if (this.originals) {
      this.set('hex',     this.originals['hex']);
      this.set('opacity', this.originals['opacity']);
    }
  },

  /**
    brightness returns a number between 0 (darkest) to 255 (brightest).
    Undefined if hex is not a valid color.

    @property brightness
  **/
  brightness: function() {
    var hex = this.get('hex');
    if (hex.length === 6 || hex.length === 3) {
      if (hex.length === 3) {
        hex = hex.substr(0,1) + hex.substr(0,1) + hex.substr(1,1) + hex.substr(1,1) + hex.substr(2,1) + hex.substr(2,1);
      }
      return Math.round(((parseInt('0x'+hex.substr(0,2)) * 299) + (parseInt('0x'+hex.substr(2,2)) * 587) + (parseInt('0x'+hex.substr(4,2)) * 114)) /1000);
    }
  }.property('hex'),

  hexValueChanged: function() {
    if (this.get('hex')) {
      this.set('hex', this.get('hex').toString().replace(/[^0-9a-fA-F]/g, ""));
    }
  }.observes('hex'),

  opacityChanged: function() {
    if (this.get('opacity')) {
      var o = this.get('opacity').toString().replace(/[^\d.]/g, "");
      if (parseInt(o,10) > 100) { o = o.substr(0,o.length-1); }
      this.set('opacity', o);
    }
  }.observes('opacity')
});
