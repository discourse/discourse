const ColorSchemeColor = Discourse.Model.extend({

  init: function() {
    this._super();
    this.startTrackingChanges();
  },

  startTrackingChanges: function() {
    this.set('originals', {hex: this.get('hex') || 'FFFFFF'});
    this.notifyPropertyChange('hex'); // force changed property to be recalculated
  },

  // Whether value has changed since it was last saved.
  changed: function() {
    if (!this.originals) return false;
    if (this.get('hex') !== this.originals['hex']) return true;
    return false;
  }.property('hex'),

  // Whether the current value is different than Discourse's default color scheme.
  overridden: function() {
    return this.get('hex') !== this.get('default_hex');
  }.property('hex', 'default_hex'),

  // Whether the saved value is different than Discourse's default color scheme.
  savedIsOverriden: function() {
    return this.get('originals').hex !== this.get('default_hex');
  }.property('hex', 'default_hex'),

  revert: function() {
    this.set('hex', this.get('default_hex'));
  },

  undo: function() {
    if (this.originals) this.set('hex', this.originals['hex']);
  },

  translatedName: function() {
    return I18n.t('admin.customize.colors.' + this.get('name') + '.name');
  }.property('name'),

  description: function() {
    return I18n.t('admin.customize.colors.' + this.get('name') + '.description');
  }.property('name'),

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

  valid: function() {
    return this.get('hex').match(/^([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/) !== null;
  }.property('hex')
});

export default ColorSchemeColor;
